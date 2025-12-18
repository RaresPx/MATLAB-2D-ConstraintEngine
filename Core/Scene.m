classdef Scene < handle
    properties
        Bodies = {}        % Cell array of Body
        Constraints = {}   % Cell array of Constraint
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
            % STEP - Advance physics: prune, apply forces, integrate, solve, collide
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
            % Iteratively project constraints to satisfy positional relations
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
                        slop = 0.01;      % small allowed penetration
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
        function applyImpulse(~, A, B, contacts, normal)
            if A.Fixed && B.Fixed
                return
            end
            % Material properties
            e  = min(A.Restitution, B.Restitution);
            mu = max(A.Mu, B.Mu);
            % Inverse masses / inertias
            invMassA = 0; invIA = 0;
            invMassB = 0; invIB = 0;
            if ~A.Fixed
                invMassA = 1 / A.Mass;
                invIA    = 1 / A.Inertia;
            end
            if ~B.Fixed
                invMassB = 1 / B.Mass;
                invIB    = 1 / B.Inertia;
            end
            REST_VEL = 0.1;   % resting contact threshold
            for k = 1:size(contacts,1)
                % Contact points
                pA = contacts(k,1:2)';
                pB = contacts(k,3:4)';
                rA = pA - A.Pos;
                rB = pB - B.Pos;
                % Velocities at contact
                vA = A.Vel + [-A.Omega * rA(2);  A.Omega * rA(1)];
                vB = B.Vel + [-B.Omega * rB(2);  B.Omega * rB(1)];
                relV = vB - vA;
                vn   = dot(relV, normal);
                % Skip separating
                if vn >= 0
                    continue
                end
                % Suppress restitution for resting contacts
                if abs(vn) < REST_VEL
                    e = 0;
                end
                %% -------- Normal impulse --------
                raCn = cross2(rA, normal);
                rbCn = cross2(rB, normal);
                denomN = invMassA + invMassB + ...
                    raCn^2 * invIA + rbCn^2 * invIB;
                jn = -(1 + e) * vn / denomN;
                impulseN = jn * normal;
                if ~A.Fixed
                    A.Vel   = A.Vel   - impulseN * invMassA;
                    A.Omega = A.Omega - raCn * jn * invIA;
                end
                if ~B.Fixed
                    B.Vel   = B.Vel   + impulseN * invMassB;
                    B.Omega = B.Omega + rbCn * jn * invIB;
                end
                %% -------- Friction impulse --------
                vt = relV - vn * normal;
                vtMag = norm(vt);
                % Resting contact → NO dynamic friction
                if vtMag < REST_VEL
                    continue
                end
                tangent = vt / vtMag;
                raCt = cross2(rA, tangent);
                rbCt = cross2(rB, tangent);
                denomT = invMassA + invMassB + ...
                    raCt^2 * invIA + rbCt^2 * invIB;
                jt = -dot(relV, tangent) / denomT;
                % Coulomb clamp
                jtMax = mu * abs(jn);
                jt = max(-jtMax, min(jtMax, jt));
                impulseT = jt * tangent;
                if ~A.Fixed
                    A.Vel   = A.Vel   - impulseT * invMassA;
                    A.Omega = A.Omega - raCt * jt * invIA;
                end
                if ~B.Fixed
                    B.Vel   = B.Vel   + impulseT * invMassB;
                    B.Omega = B.Omega + rbCt * jt * invIB;
                end
            end
            % --- helper ---
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
            %create a small interlocked grid
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
                    b = Body(pos, [0;0], mass, 'circle', nodeRadius,[1 1 1]);
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
            %delete what falls off screen
            lostIdx = cellfun(@(b) (abs(b.Pos(1)) > 20 || abs(b.Pos(2)) > 30), obj.Bodies);
            cellfun(@(b) set(b.GraphicHandle,'XData',[],'YData',[]), ...
                obj.Bodies(lostIdx), 'UniformOutput', false);
            obj.Bodies(lostIdx) = [];
        end
        %% ------------- Serialisation and Saving ------------------
        function S = toStruct(obj)
            S.Bodies = cellfun(@(b)b.toStruct(), obj.Bodies, 'UniformOutput', false);
            S.Constraints = cellfun(@(c)c.toStruct(), obj.Constraints, 'UniformOutput', false);
        end
        function fromStruct(obj, S)
            obj.Bodies = {};
            obj.Constraints = {};
            % Bodies
            for i = 1:numel(S.Bodies)
                b = Body.fromStruct(S.Bodies{i});
                obj.addBody(b);
            end
            % Constraints (must rebind body references)
            for i = 1:numel(S.Constraints)
                c = Constraint.fromStruct(S.Constraints{i}, obj.Bodies);
                obj.addConstraint(c);
            end
        end
        function resetEmpty(obj)
            % Delete graphics for all bodies
            if ~isempty(obj.Bodies)
                for k = 1:numel(obj.Bodies)
                    b = obj.Bodies{k};
                    if isprop(b,'GraphicHandle') && ~isempty(b.GraphicHandle) && isvalid(b.GraphicHandle)
                        delete(b.GraphicHandle);
                    end
                    if isprop(b,'GraphicHandle')
                        b.GraphicHandle = [];
                    end
                end
            end
            if ~isempty(obj.Constraints)
                for k = 1:numel(obj.Constraints)
                    c = obj.Constraints{k};
                    if isprop(c,'GraphicHandle') && ~isempty(c.GraphicHandle) && isvalid(c.GraphicHandle)
                        delete(c.GraphicHandle);
                    end
                    if isprop(c,'GraphicHandle')
                        c.GraphicHandle = [];
                    end
                end
            end
            % Clear bodies and constraints
            obj.Bodies = {};
            obj.Constraints = {};
        end
        function resetDefault(obj)
            obj.resetEmpty();
            obj.setupDefaultScene();
        end
    end
end
