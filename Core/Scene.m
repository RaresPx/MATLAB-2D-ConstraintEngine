classdef Scene < handle
    properties
        Bodies = {}        % Cell array of Body
        Constraints = {}   % Cell array of Constraint
        Width = 10         % Scene width
        Height = 8         % Scene height
        WallThickness = 0.5 % Thickness of boundary walls
    end

    methods
        function addBody(obj, b)
            obj.Bodies{end+1} = b;
        end

        function addConstraint(obj, c)
            obj.Constraints{end+1} = c;
        end

        %% ---------------- Simulation Steps ----------------
        function step(obj, dt, gravity)
            obj.applyForces(gravity);
            obj.integrateBodies(dt);
            obj.solveConstraints(10);
            obj.resolveCollisions();
        end

        function applyForces(obj, gravity)
            for i = 1:numel(obj.Bodies)
                b = obj.Bodies{i};
                if ~b.Fixed
                    b.Force = gravity * b.Mass;
                else
                    b.Force = [0;0];
                end
            end
        end

        function integrateBodies(obj, dt)
            for i = 1:numel(obj.Bodies)
                b = obj.Bodies{i};
                if b.Fixed
                    b.Force = [0;0];
                    b.Torque = 0;
                    continue
                end
                % Linear integration
                acc = b.Force / b.Mass;
                b.Vel = b.Vel + acc*dt;
                b.Pos = b.Pos + b.Vel*dt;
                % Angular integration
                b.Omega = b.Omega + b.Torque / b.Inertia * dt;
                b.Angle = b.Angle + b.Omega*dt;
                % Reset forces/torque
                b.Force = [0;0];
                b.Torque = 0;
            end
        end

        function solveConstraints(obj, iterations)
            for k = 1:iterations
                for j = 1:numel(obj.Constraints)
                    obj.Constraints{j}.solve();
                end
            end
        end

        %% ---------------- Collision ----------------
        function resolveCollisions(obj)
            n = numel(obj.Bodies);
            maxIterations = 10;
            for iter = 1:maxIterations
                for i = 1:n-1
                    for j = i+1:n
                        bodyA = obj.Bodies{i};
                        bodyB = obj.Bodies{j};
                        [colliding, normal, depth, refPoly, incPoly, refIndex, isCircle] = ...
                            SATCollision(bodyA, bodyB);
                        if colliding
                            contacts = ComputeManifold(refPoly, incPoly, normal, refIndex, depth, isCircle);
                            if isempty(contacts)
                                contacts = (mean(refPoly,2) + mean(incPoly,2))/2;
                            end
                            for k = 1:size(contacts,2)
                                obj.applyImpulse(bodyA, bodyB, normal, depth, contacts(:,k));
                            end
                        end
                    end
                end
            end
        end

        function applyImpulse(~, bodyA, bodyB, normal, depth, contact)
            restitution = 0.3;

            ra = contact - bodyA.Pos;
            rb = contact - bodyB.Pos;

            % velocities at contact points
            velA = bodyA.Vel;
            velB = bodyB.Vel;
            if ~bodyA.Fixed
                velA = velA + [-bodyA.Omega*ra(2); bodyA.Omega*ra(1)];
            end
            if ~bodyB.Fixed
                velB = velB + [-bodyB.Omega*rb(2); bodyB.Omega*rb(1)];
            end

            relVel = velB - velA;
            velAlongNormal = dot(relVel, normal);
            if velAlongNormal > 0
                return
            end

            % --- Inverse mass & inertia, safely ---
            invMassA = 0; invInertiaA = 0;
            if ~bodyA.Fixed && bodyA.Mass > 0
                invMassA = 1 / bodyA.Mass;
                invInertiaA = 1 / bodyA.Inertia;
            end

            invMassB = 0; invInertiaB = 0;
            if ~bodyB.Fixed && bodyB.Mass > 0
                invMassB = 1 / bodyB.Mass;
                invInertiaB = 1 / bodyB.Inertia;
            end

            raCrossN = ra(1)*normal(2) - ra(2)*normal(1);
            rbCrossN = rb(1)*normal(2) - rb(2)*normal(1);

            invMassSum = invMassA + invMassB + raCrossN^2*invInertiaA + rbCrossN^2*invInertiaB;
            if invMassSum == 0
                return  % both bodies fixed, skip impulse
            end

            % --- impulse ---
            j = -(1 + restitution) * velAlongNormal / invMassSum;
            impulse = j * normal;

            if ~bodyA.Fixed
                bodyA.Vel = bodyA.Vel - impulse*invMassA;
                bodyA.Omega = bodyA.Omega - raCrossN*j*invInertiaA;
            end
            if ~bodyB.Fixed
                bodyB.Vel = bodyB.Vel + impulse*invMassB;
                bodyB.Omega = bodyB.Omega + rbCrossN*j*invInertiaB;
            end

            % --- positional correction ---
            percent = 0.8;
            slop = 0.01;
            correction = max(depth - slop,0) * percent * normal;
            totalInvMass = invMassA + invMassB;
            if totalInvMass > 0
                if ~bodyA.Fixed
                    bodyA.Pos = bodyA.Pos - correction * invMassA / totalInvMass;
                end
                if ~bodyB.Fixed
                    bodyB.Pos = bodyB.Pos + correction * invMassB / totalInvMass;
                end
            end
        end

        %% ---------------- Graphics ----------------
        function updateGraphics(obj, ax)
            for i = 1:numel(obj.Bodies)
                obj.Bodies{i}.updateGraphic(ax);
            end
            for j = 1:numel(obj.Constraints)
                obj.Constraints{j}.updateGraphic(ax);
            end
        end

        %% ---------------- Default Scene ----------------
        function setupDefaultScene(obj)
            obj.Bodies = {};
            obj.Constraints = {};
            % ---------------- Parameters ----------------
            rows = 2;           % vertical nodes
            cols = 2;          % horizontal nodes
            spacing = 1;      % distance between nodes
            nodeRadius = 0.4;  % small circle
            mass = 0.4;         % mass per node
            stiffness = 1;   % spring elasticity factor for constraints

            % ---------------- Create Nodes ----------------
            nodes = cell(rows, cols);
            for j = 1:rows
                for i = 1:cols
                    pos = [ (i-1)*spacing; -(j-1)*spacing ]; % 2x1 vector, top-left origin
                    fixed = (j == 1 && i == 1); % top corner fixed
                    b = Body(pos, [0;0], mass, 'circle', nodeRadius);
                    b.Fixed = fixed;
                    obj.addBody(b);
                    nodes{j,i} = b;
                end
            end

            % ---------------- Create Structural Constraints ----------------
            for j = 1:rows
                for i = 1:cols
                    b = nodes{j,i};
                    % Horizontal neighbor
                    if i < cols
                        bRight = nodes{j,i+1};
                        len = norm(bRight.Pos - b.Pos);
                        c = Constraint(b, bRight, len);
                        c.Stiffness = stiffness;
                        obj.addConstraint(c);
                    end
                    % Vertical neighbor
                    if j < rows
                        bBelow = nodes{j+1,i};
                        len = norm(bBelow.Pos - b.Pos);
                        c = Constraint(b, bBelow, len);
                        c.Stiffness = stiffness;
                        obj.addConstraint(c);
                    end
                end
            end


        end
    end
end
