classdef Editor < handle
    properties
        Scene
        AxesHandle
        Mode = 'addCircle'
        SelectedBody = []
    end

    methods
        function obj = Editor(scene, ax)
            obj.Scene = scene;
            obj.AxesHandle = ax;

            uicontrol('Style','pushbutton', 'String','Circle',...
                'Position',[10 10 70 25], 'Callback', @(s,e)obj.setMode('addCircle'));
            uicontrol('Style','pushbutton', 'String','Rect',...
                'Position',[90 10 70 25], 'Callback', @(s,e)obj.setMode('addRect'));
            uicontrol('Style','pushbutton', 'String','Drag',...
                'Position',[170 10 70 25], 'Callback', @(s,e)obj.setMode('drag'));
            uicontrol('Style','pushbutton', 'String','Connect',...
                'Position',[250 10 70 25], 'Callback', @(s,e)obj.setMode('addConstraint'));

            fig = ax.Parent;
            fig.WindowButtonDownFcn = @(~,~) obj.onMouseDown();
            fig.WindowButtonUpFcn   = @(~,~) obj.onMouseUp();
            fig.WindowButtonMotionFcn = @(~,~) obj.onMouseMove();
        end

        function setMode(obj, m)
            obj.Mode = m;
            obj.SelectedBody = [];
        end

        function onMouseDown(obj)
            pos = obj.AxesHandle.CurrentPoint(1,1:2)';
            switch obj.Mode
                case 'addCircle'
                    obj.Scene.addBody(Body(pos, [0;0], 1, 'circle', 0.5));
                case 'addRect'
                    obj.Scene.addBody(Body(pos, [0;0], 1, 'rect', [1 1]));
                case 'drag'
                    obj.SelectedBody = obj.pickBody(pos);
                case 'addConstraint'
                    obj.SelectedBody = obj.pickBody(pos);
            end
        end

        function onMouseUp(obj)
            pos = obj.AxesHandle.CurrentPoint(1,1:2)';
            if strcmp(obj.Mode, 'addConstraint') && ~isempty(obj.SelectedBody)
                b2 = obj.pickBody(pos);
                if ~isempty(b2) && b2 ~= obj.SelectedBody
                    obj.Scene.addConstraint(Constraint(obj.SelectedBody, b2, norm(obj.SelectedBody.Pos - b2.Pos)));
                end
                obj.SelectedBody = [];
            elseif strcmp(obj.Mode, 'drag')
                obj.SelectedBody = [];
            end
        end

        function onMouseMove(obj)
            if strcmp(obj.Mode, 'drag') && ~isempty(obj.SelectedBody)
                pos = obj.AxesHandle.CurrentPoint(1,1:2)';
                obj.SelectedBody.Pos = pos;
            end
        end

        function b = pickBody(obj, pos)
            b = [];
            for i = 1:numel(obj.Scene.Bodies)
                body = obj.Scene.Bodies{i};
                if strcmp(body.Shape,'circle')
                    if norm(body.Pos - pos) <= body.Radius
                        b = body; return;
                    end
                else % rect
                    if pos(1)>=body.Pos(1)-body.Width/2 && pos(1)<=body.Pos(1)+body.Width/2 && ...
                       pos(2)>=body.Pos(2)-body.Height/2 && pos(2)<=body.Pos(2)+body.Height/2
                        b = body; return;
                    end
                end
            end
        end
    end
end
