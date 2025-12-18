classdef Body < handle
    %BODY - Rigid body representation for simple 2D physics/graphics
    %   OBJ = BODY(POS,VEL,MASS,SHAPE,SIZE,COLOR,FIXED) constructs a body with
    %   position, velocity, mass and geometric properties. Supports circle and
    %   rectangle shapes, simple inertia, and basic graphics helpers.
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
        Color = [0 0 0];
        Restitution = 0.5
        Mu = 0.3           %Friction coefficient
    end
    methods
        function obj = Body(pos, vel, mass, shape, size,color, fixed)
            if nargin < 7,fixed = false; end
            obj.Pos = pos;
            obj.Vel = vel;
            obj.Mass = mass;
            obj.Shape = shape;
            obj.Color = color;
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
            obj.GraphicHandle.FaceColor = obj.Color;
        end
        function initGraphic(obj, ax)
            verts = obj.getVertices();
            obj.GraphicHandle = fill(ax, verts(1,:), verts(2,:), obj.Color, 'EdgeColor','black');
        end
        function tf = isFixed(obj)
            tf = obj.Fixed;
        end
        function S = toStruct(obj)
            S.Pos = obj.Pos;
            S.Vel = obj.Vel;
            S.Angle = obj.Angle;
            S.Omega = obj.Omega;
            S.Mass = obj.Mass;
            S.Shape = obj.Shape;
            S.Fixed = obj.Fixed;
            S.Color = obj.Color;
            if strcmp(obj.Shape,'circle')
                S.Size = obj.Radius;
            else
                S.Size = [obj.Width, obj.Height];
            end
            S.Restitution = obj.Restitution;
            S.Mu = obj.Mu;
        end
    end
    methods (Static)
        function b = fromStruct(S)
            b = Body( ...
                S.Pos, ...
                S.Vel, ...
                S.Mass, ...
                S.Shape, ...
                S.Size, ...
                S.Color, ...
                S.Fixed ...
                );
            % Restore kinematics
            b.Angle = S.Angle;
            b.Omega = S.Omega;
            % Restore material
            if isfield(S,'Restitution')
                b.Restitution = S.Restitution;
            end
            if isfield(S,'Mu')
                b.Mu = S.Mu;
            end
        end
    end
end
