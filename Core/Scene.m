classdef Scene < handle
    properties
        Bodies = {}        % cell array of Body
        Constraints = {}   % cell array of Constraint
    end

    methods
        function addBody(obj, b)
            obj.Bodies{end+1} = b;
        end
        function addConstraint(obj, c)
            obj.Constraints{end+1} = c;
        end

        function applyForces(obj, gravity)
            n = numel(obj.Bodies);
            for i = 1:n
                b = obj.Bodies{i};
                b.Force = gravity * b.Mass;
            end
        end

        function integrateBodies(obj, dt)
            n = numel(obj.Bodies);
            for i = 1:n
                b = obj.Bodies{i};
                acc = b.Force / b.Mass;
                b.Vel = b.Vel + acc * dt;
                b.Pos = b.Pos + b.Vel * dt;
            end
        end

        function solveConstraints(obj, iterations)
            for k = 1:iterations
                m = numel(obj.Constraints);
                for j = 1:m
                    obj.Constraints{j}.solve();
                end
            end
        end

        function updateGraphics(obj, ax)
            % Update bodies
            for i = 1:numel(obj.Bodies)
                obj.Bodies{i}.updateGraphic(ax);
            end
            % Update constraints
            for j = 1:numel(obj.Constraints)
                obj.Constraints{j}.updateGraphic(ax);
            end
        end
    end
end
