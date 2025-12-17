classdef Constraint < handle
    properties
        BodyA
        BodyB
        RestLength
        Stiffness = 1.0   % 0..1, 1 = rigid, <1 = elastic
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
