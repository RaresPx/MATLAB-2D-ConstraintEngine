classdef Constraint < handle
    %CONSTRAINT - Represents a distance constraint between two bodies.
    %   C = CONSTRAINT(A,B,LEN,STIFFNESS) creates a constraint that tries to
    %   keep bodies A and B separated by LEN. STIFFNESS in [0,1] controls
    %   how strongly the constraint is enforced (1 = rigid).
    properties
        BodyA
        BodyB
        RestLength
        Stiffness = 0.6   % 0..1, 1 = rigid, <1 = elastic
        GraphicHandle
    end
    methods
        function obj = Constraint(a, b, len, stiffness)
            if nargin < 4
                stiffness = 1.0;
            end
            obj.BodyA = a;
            obj.BodyB = b;
            obj.RestLength = len;
            obj.Stiffness = stiffness;
        end
        function solve(obj)
            % Adjust positions of bodies to satisfy the rest length constraint.
            delta = obj.BodyB.Pos - obj.BodyA.Pos;
            d = norm(delta);
            if d == 0
                return;
            end
            correction = (d - obj.RestLength) / d * delta * obj.Stiffness;
            invA = ~obj.BodyA.Fixed && ~obj.BodyA.Dragged;
            invB = ~obj.BodyB.Fixed && ~obj.BodyB.Dragged;
            totalInv = invA + invB;
            if totalInv == 0
                return;
            end
            if invA
                obj.BodyA.Pos = obj.BodyA.Pos + correction * (invA / totalInv);
            end
            if invB
                obj.BodyB.Pos = obj.BodyB.Pos - correction * (invB / totalInv);
            end
        end
        function updateGraphic(obj, ax)
            % Create or update a line showing the constraint between bodies.
            if isempty(obj.GraphicHandle) || ~isvalid(obj.GraphicHandle)
                obj.GraphicHandle = line(ax, ...
                    [obj.BodyA.Pos(1), obj.BodyB.Pos(1)], ...
                    [obj.BodyA.Pos(2), obj.BodyB.Pos(2)], ...
                    'Color', 'k', 'LineWidth', 2);
            else
                obj.GraphicHandle.XData = [obj.BodyA.Pos(1), obj.BodyB.Pos(1)];
                obj.GraphicHandle.YData = [obj.BodyA.Pos(2), obj.BodyB.Pos(2)];
            end
        end
    end
end
