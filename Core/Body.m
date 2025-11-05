classdef Body < handle
    properties
        Pos                % 2x1 vector
        Vel                % 2x1 vector
        Mass
        Shape              % 'circle' or 'rect'
        Radius             % if circle
        Width              % if rect
        Height             % if rect
        Force = [0;0]
        GraphicHandle      % handle to patch
    end

    methods
        function obj = Body(pos, vel, mass, shape, size)
            obj.Pos = pos;
            obj.Vel = vel;
            obj.Mass = mass;
            obj.Shape = shape;
            if strcmp(shape, 'circle')
                obj.Radius = size;
            else
                obj.Width = size(1);
                obj.Height = size(2);
            end
        end

        function updateGraphic(obj, ax)
            if isempty(obj.GraphicHandle) || ~isvalid(obj.GraphicHandle)
                obj.initGraphic(ax);
                return;
            end

            if strcmp(obj.Shape, 'circle')
                theta = linspace(0, 2*pi, 20);
                obj.GraphicHandle.XData = obj.Pos(1) + obj.Radius * cos(theta);
                obj.GraphicHandle.YData = obj.Pos(2) + obj.Radius * sin(theta);
            else
                w = obj.Width/2; h = obj.Height/2;
                x = obj.Pos(1) + [-w w w -w];
                y = obj.Pos(2) + [-h -h h h];
                obj.GraphicHandle.XData = x;
                obj.GraphicHandle.YData = y;
            end
        end

        function initGraphic(obj, ax)
            if strcmp(obj.Shape, 'circle')
                theta = linspace(0, 2*pi, 20);
                x = obj.Pos(1) + obj.Radius * cos(theta);
                y = obj.Pos(2) + obj.Radius * sin(theta);
                obj.GraphicHandle = fill(ax, x, y, 'r', 'EdgeColor', 'none');
            else
                w = obj.Width/2; h = obj.Height/2;
                x = obj.Pos(1) + [-w w w -w];
                y = obj.Pos(2) + [-h -h h h];
                obj.GraphicHandle = fill(ax, x, y, 'b', 'EdgeColor', 'none');
            end
        end
    end
end
