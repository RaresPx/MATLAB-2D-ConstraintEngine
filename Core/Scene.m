classdef Scene < handle
    properties
        Bodies = {}        % Cell array of Body
        Constraints = {}   % Cell array of Constraint
        Width = 10         % Scene width
        Height = 8         % Scene height
        Restitution = 0.5  
        Mu = 0.5           %Friction coefficient
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
            inactiveIdx = cellfun(@(b) ~b.Active, obj.Bodies);

            % Remove inactive bodies from the array
            obj.Bodies(inactiveIdx) = [];
            obj.removeLostBodies();

            obj.applyForces(gravity);
            obj.integrateBodies(dt);
            obj.solveConstraints(10);
            obj.resolveCollisions();
        end

        function applyForces(obj, gravity)
            for i = 1:numel(obj.Bodies)
                b = obj.Bodies{i};
                if ~b.Fixed && ~b.Dragged
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
                % Linear
                v_old = b.Vel;
                b.Vel = b.Vel + b.Force / b.Mass * dt;
                b.Pos = b.Pos + 0.5 * (v_old + b.Vel) * dt;

                % Angular
                omega_old = b.Omega;
                b.Omega = b.Omega + b.Torque / b.Inertia * dt;
                b.Angle = b.Angle + 0.5 * (omega_old + b.Omega) * dt;

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
            maxIterations = 20;  % Positional correction iterations
            impulseIterations = 10; % Sequential impulse iterations

            for iter = 1:maxIterations
                for i = 1:n-1
                    for j = i+1:n
                        bodyA = obj.Bodies{i};
                        bodyB = obj.Bodies{j};

                        [isColliding, normal, ~, MTV] = SATCollision(bodyA, bodyB);

                        if ~isColliding
                            continue;
                        end

                        %% --- 1. Positional correction / depenetration ---
                        slop = 0.001;      % small allowed penetration
                        percent = 0.8;     % fraction of penetration to correct

                        MTV_mag = norm(MTV);
                        if MTV_mag > slop
                            correction = (MTV_mag - slop) * (MTV / MTV_mag) * percent;
                            if bodyA.Fixed && ~bodyB.Fixed
                                bodyB.Pos = bodyB.Pos + correction;
                            elseif bodyB.Fixed && ~bodyA.Fixed
                                bodyA.Pos = bodyA.Pos - correction;
                            elseif ~bodyA.Fixed && ~bodyB.Fixed
                                totalMass = bodyA.Mass + bodyB.Mass;
                                bodyA.Pos = bodyA.Pos - (bodyB.Mass / totalMass) * correction;
                                bodyB.Pos = bodyB.Pos + (bodyA.Mass / totalMass) * correction;
                            end
                        end

                        %% --- 2. Contact point calculation ---
                        contacts = ComputeContactPoints(bodyA, bodyB, normal);
                        if isempty(contacts)
                            continue
                        end

                        %% --- 3. Impulse resolution ---
                        for k = 1:impulseIterations
                            obj.applyImpulse(bodyA, bodyB, contacts, normal);
                        end
                    end
                end
            end
        end

        function applyImpulse(~,A, B, contacts, normal)
            if A.Fixed && B.Fixed
                return
            end

            restitution = 0.8;
            mu = 0.6;

            % Loop over all contact points
            for k = 1:size(contacts,1)
                pA = contacts(k, 1:2)';   % point on A
                pB = contacts(k, 3:4)';   % point on B

                rA = pA - A.Pos;
                rB = pB - B.Pos;

                % Velocities at contact
                vA = A.Vel + [-A.Omega * rA(2);  A.Omega * rA(1)];
                vB = B.Vel + [-B.Omega * rB(2);  B.Omega * rB(1)];

                relV = vB - vA;
                vn = dot(relV, normal);

                % Skip separating contacts
                if vn >= 0
                    continue
                end

                % Inverse masses
                invMassA = 0; invIA = 0;
                invMassB = 0; invIB = 0;

                if ~A.Fixed
                    invMassA = 1 / A.Mass;
                    invIA = 1 / A.Inertia;
                end
                if ~B.Fixed
                    invMassB = 1 / B.Mass;
                    invIB = 1 / B.Inertia;
                end

                %% -------- Normal impulse --------
                raCrossN = cross2(rA, normal);
                rbCrossN = cross2(rB, normal);

                denom = invMassA + invMassB + raCrossN^2 * invIA + rbCrossN^2 * invIB;

                j = -(1 + restitution) * vn / denom;
                impulse = j * normal;

                if ~A.Fixed
                    A.Vel   = A.Vel   - impulse * invMassA;
                    A.Omega = A.Omega - raCrossN * j * invIA;
                end
                if ~B.Fixed
                    B.Vel   = B.Vel   + impulse * invMassB;
                    B.Omega = B.Omega + rbCrossN * j * invIB;
                end

                %% -------- Friction impulse --------
                vt = relV - vn * normal;
                tMag = norm(vt);

                if tMag > 1e-8
                    tangent = vt / tMag;

                    raCrossT = cross2(rA, tangent);
                    rbCrossT = cross2(rB, tangent);

                    denomT = invMassA + invMassB + raCrossT^2 * invIA + rbCrossT^2 * invIB;

                    jt = -dot(relV, tangent) / denomT;

                    % Coulomb friction
                    jtMax = mu * j;
                    jt = max(-jtMax, min(jtMax, jt));

                    frictionImpulse = jt * tangent;

                    if ~A.Fixed
                        A.Vel   = A.Vel   - frictionImpulse * invMassA;
                        A.Omega = A.Omega - raCrossT * jt * invIA;
                    end
                    if ~B.Fixed
                        B.Vel   = B.Vel   + frictionImpulse * invMassB;
                        B.Omega = B.Omega + rbCrossT * jt * invIB;
                    end
                end
            end

            % --- helper function ---
            function c = cross2(a, b)
                c = a(1)*b(2) - a(2)*b(1);
            end
        end


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

        function removeLostBodies(obj)
            lostIdx = cellfun(@(b) (abs(b.Pos(1)) > 20 || abs(b.Pos(2)) > 30), obj.Bodies);
            cellfun(@(b) set(b.GraphicHandle,'XData',[],'YData',[]), ...
                obj.Bodies(lostIdx), 'UniformOutput', false);
            obj.Bodies(lostIdx) = [];
        end
    end
end
