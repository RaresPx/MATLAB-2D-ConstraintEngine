classdef Body < handle
    properties
        Pos
        Vel = [0;0]
        Angle = 0
        Omega = 0
        Mass
        Inertia
        Shape
        Radius
        Width
        Height
        Force = [0;0]
        Torque = 0
        GraphicHandle
        Fixed = false
        Active = true;
        Dragged = false;
    end

    methods
        function obj = Body(pos, vel, mass, shape, size, fixed)
            if nargin < 6, fixed = false; end
            obj.Pos = pos;
            obj.Vel = vel;
            obj.Mass = mass;
            obj.Shape = shape;
            obj.Fixed = fixed;

            if strcmp(shape,'circle')
                obj.Radius = size;
                obj.Inertia = 0.5 * mass * size^2;
            else
                obj.Width = size(1);
                obj.Height = size(2);
                obj.Inertia = mass * (size(1)^2 + size(2)^2) / 12;
            end

            if obj.Fixed
                obj.Mass = 0;
                obj.Inertia = 0;
                obj.Vel = [0;0];
                obj.Omega = 0;
                obj.Force = [0;0];
                obj.Torque = 0;
            end
        end

        function verts = getVertices(obj)
            if strcmp(obj.Shape, 'circle')
                theta = linspace(0, 2*pi - 2*pi/20, 20);   % 20 unique points
                verts = obj.Pos + obj.Radius * [cos(theta); sin(theta)];
            else
                w = obj.Width / 2;
                h = obj.Height / 2;
                % Proper vertex ordering (no duplicate last vertex)
                corners = [-w,  w,  w, -w;
                           -h, -h,  h,  h];
                R = [cos(obj.Angle), -sin(obj.Angle);
                     sin(obj.Angle),  cos(obj.Angle)];
                verts = R * corners + obj.Pos;
            end
        end

        function updateGraphic(obj, ax)
            if isempty(obj.GraphicHandle) || ~isvalid(obj.GraphicHandle)
                obj.initGraphic(ax);
                return;
            end
            verts = obj.getVertices();
            obj.GraphicHandle.XData = verts(1,:);
            obj.GraphicHandle.YData = verts(2,:);
        end

        function initGraphic(obj, ax)
            verts = obj.getVertices();
            color = 'r';
            if strcmp(obj.Shape,'rect'), color = 'b'; end
            obj.GraphicHandle = fill(ax, verts(1,:), verts(2,:), color, 'EdgeColor','none');
        end

        function tf = isFixed(obj)
            tf = obj.Fixed;
        end
    end
end
