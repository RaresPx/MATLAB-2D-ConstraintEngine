classdef Constraint < handle
    properties
        BodyA
        BodyB
        RestLength
        GraphicHandle
    end

    methods
        function obj = Constraint(a, b, len)
            obj.BodyA = a;
            obj.BodyB = b;
            obj.RestLength = len;
        end

        function solve(obj)
            delta = obj.BodyB.Pos - obj.BodyA.Pos;
            d = norm(delta);
            if d == 0
                return;
            end
            correction = 0.5 * (d - obj.RestLength) / d * delta;
            obj.BodyA.Pos = obj.BodyA.Pos + correction;
            obj.BodyB.Pos = obj.BodyB.Pos - correction;
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
