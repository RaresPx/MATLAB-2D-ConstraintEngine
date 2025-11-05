classdef Editor < handle
    properties
        Core            % Core class reference
        Scene           % Scene reference
        AxesHandle      % Axes to draw in
        SelectedBody = []
        SelectedConstraint = []
        Mode = 'select'
        UI = struct()
        PanelWidth = 200
    end

    methods
        function obj = Editor(core, scene, ax)
            obj.Core = core;
            obj.Scene = scene;
            obj.AxesHandle = ax;

            obj.createUI();

            % Set up mouse events for interactions
            fig = ax.Parent;
            fig.WindowButtonDownFcn   = @(~,~) obj.onMouseDown();
            fig.WindowButtonUpFcn     = @(~,~) obj.onMouseUp();
            fig.WindowButtonMotionFcn = @(~,~) obj.onMouseMove();
        end

        %% ---------------- UI ----------------
        function createUI(obj)
            % Place the panel to the right of the axes
            fig = obj.AxesHandle.Parent;
            fig.Units = 'pixels';
            figPos = fig.Position;

            panelX = figPos(3) - obj.PanelWidth - 10;
            panelY = 10; panelW = obj.PanelWidth; panelH = figPos(4) - 20;
            obj.UI.MainPanel = uipanel(fig, 'Title','Editor','Position',[panelX/figPos(3) panelY/figPos(4) panelW/figPos(3) panelH/figPos(4)]);

            % Buttons for different modes
            y = panelH - 40; dy = 35; xpad = 10;
            modes = {'select', 'addCircle', 'addRect', 'drag', 'addConstraint', 'delete'};
            for i = 1:numel(modes)
                uicontrol(obj.UI.MainPanel,'Style','pushbutton','String',modes{i},...
                    'Position',[xpad y-((i-1)*dy) 160 25], 'Callback', @(s,e)obj.setMode(modes{i}));
            end

            % Global Constants section
            yConst = y - dy*numel(modes) - 20;
            uicontrol(obj.UI.MainPanel, 'Style', 'text', 'String', 'Global Constants', ...
                'Position', [xpad yConst 160 20], 'FontWeight', 'bold');
            yConst = yConst - 30;

            % Gravity Y
            uicontrol(obj.UI.MainPanel, 'Style', 'text', 'String', 'Gravity Y', ...
                'Position', [xpad yConst 70 20]);
            obj.UI.GravityEdit = uicontrol(obj.UI.MainPanel, 'Style', 'edit', ...
                'String', num2str(obj.Core.Gravity(2)), 'Position', [xpad+80 yConst 60 20], ...
                'Callback', @(s,e)obj.setGravity());
            yConst = yConst - 30;

            % dt
            uicontrol(obj.UI.MainPanel, 'Style', 'text', 'String', 'dt', ...
                'Position', [xpad yConst 70 20]);
            obj.UI.dtEdit = uicontrol(obj.UI.MainPanel, 'Style', 'edit', ...
                'String', num2str(obj.Core.dt), 'Position', [xpad+80 yConst 60 20], ...
                'Callback', @(s,e)obj.setDt());
            yConst = yConst - 30;

            % Draw Interval
            uicontrol(obj.UI.MainPanel, 'Style', 'text', 'String', 'Draw Interval', ...
                'Position', [xpad yConst 80 20]);
            obj.UI.DrawTimeEdit = uicontrol(obj.UI.MainPanel, 'Style', 'edit', ...
                'String', num2str(obj.Core.DrawInterval), 'Position', [xpad+90 yConst 50 20], ...
                'Callback', @(s,e)obj.setDrawTime());
            yConst = yConst - 40;

            % Exit Button
            uicontrol(obj.UI.MainPanel, 'Style', 'pushbutton', 'String', 'Exit', ...
                'Position', [xpad 10 160 25], 'Callback', @(s,e)obj.exitEditor());

            % Properties Panel
            obj.UI.PropPanelTitle = uicontrol(obj.UI.MainPanel, 'Style', 'text', ...
                'String', 'Selected Properties', 'Position', [xpad yConst 160 20], 'FontWeight', 'bold');
            yConst = yConst - 25;
            obj.UI.PropPanel = uipanel(obj.UI.MainPanel, 'Position', [0 0 1 yConst/panelH]);
        end

        %% ---------------- Mode handling ----------------
        function setMode(obj, mode)
            obj.Mode = mode;
            obj.SelectedBody = [];
            obj.SelectedConstraint = [];
            obj.updatePropertyPanel();
        end

        %% ---------------- Mouse Events ----------------
        function onMouseDown(obj)
            pos = obj.AxesHandle.CurrentPoint(1,1:2)';
            switch obj.Mode
                case 'addCircle'
                    obj.Scene.addBody(Body(pos, [0;0], 1, 'circle', 0.5));
                case 'addRect'
                    obj.Scene.addBody(Body(pos, [0;0], 1, 'rect', [1 1]));
                case 'drag'
                    obj.SelectedBody = obj.pickBody(pos);
                case 'select'
                    obj.SelectedBody = obj.pickBody(pos);
                    obj.SelectedConstraint = obj.pickConstraint(pos);
                case 'addConstraint'
                    obj.SelectedBody = obj.pickBody(pos);
                case 'delete'
                    obj.deleteAtPosition(pos);
            end
            obj.updatePropertyPanel();
        end

        function onMouseUp(obj)
            pos = obj.AxesHandle.CurrentPoint(1,1:2)';
            if strcmp(obj.Mode, 'addConstraint') && ~isempty(obj.SelectedBody)
                b2 = obj.pickBody(pos);
                if ~isempty(b2) && b2 ~= obj.SelectedBody
                    obj.Scene.addConstraint(Constraint(obj.SelectedBody, b2, ...
                        norm(obj.SelectedBody.Pos - b2.Pos), 0.8));
                end
                obj.SelectedBody = [];
            elseif strcmp(obj.Mode, 'drag')
                obj.SelectedBody = [];
            end
            obj.updatePropertyPanel();
        end

        function onMouseMove(obj)
            if strcmp(obj.Mode, 'drag') && ~isempty(obj.SelectedBody)
                pos = obj.AxesHandle.CurrentPoint(1,1:2)';
                obj.SelectedBody.Pos = pos;
            end
        end

        %% ---------------- Deleting Bodies and Constraints ----------------
        function deleteAtPosition(obj, pos)
            % Delete the body at the given position
            bodyToDelete = obj.pickBody(pos);
            if ~isempty(bodyToDelete)
                % Remove the graphical elements of the body (XData and YData)
                if ishandle(bodyToDelete.GraphicHandle)
                    bodyToDelete.GraphicHandle.XData = [];
                    bodyToDelete.GraphicHandle.YData = [];
                end

                % Remove any constraints attached to this body
                idxConstraintsToDelete = find(cellfun(@(c) c.BodyA == bodyToDelete || c.BodyB == bodyToDelete, obj.Scene.Constraints));
                obj.Scene.Constraints(idxConstraintsToDelete) = [];  % Remove the constraints

                % Remove the body from the scene
                obj.Scene.Bodies = obj.Scene.Bodies(~cellfun(@(x) x == bodyToDelete, obj.Scene.Bodies));

                % If the selected body was the one deleted, clear the selection
                if obj.SelectedBody == bodyToDelete
                    obj.SelectedBody = [];
                end
            end

            % Delete the constraint at the given position
            constraintToDelete = obj.pickConstraint(pos);
            if ~isempty(constraintToDelete)
                 %Delete the constraint graphics
                if ishandle(constraintToDelete.GraphicHandle)
                    constraintToDelete.GraphicHandle.XData = [];
                    constraintToDelete.GraphicHandle.YData = [];
                end
                
                % Remove the constraint from the scene
                obj.Scene.Constraints = obj.Scene.Constraints(~cellfun(@(x) x == constraintToDelete, obj.Scene.Constraints));

               
                % If the selected constraint was the one deleted, clear the selection
                if obj.SelectedConstraint == constraintToDelete
                    obj.SelectedConstraint = [];
                end
            end

            % Redraw the scene without the deleted bodies or constraints
            obj.Scene.updateGraphics(obj.AxesHandle);  % Redraw the scene
        end


        %% ---------------- Picking ----------------
        function b = pickBody(obj, pos)
            b = [];
            for i = 1:numel(obj.Scene.Bodies)
                body = obj.Scene.Bodies{i};
                if strcmp(body.Shape, 'circle')
                    if norm(body.Pos - pos) <= body.Radius
                        b = body; return;
                    end
                else
                    if pos(1) >= body.Pos(1)-body.Width/2 && pos(1) <= body.Pos(1)+body.Width/2 && ...
                            pos(2) >= body.Pos(2)-body.Height/2 && pos(2) <= body.Pos(2)+body.Height/2
                        b = body; return;
                    end
                end
            end
        end

        function c = pickConstraint(obj, pos)
            c = [];
            for i = 1:numel(obj.Scene.Constraints)
                con = obj.Scene.Constraints{i};
                mid = (con.BodyA.Pos + con.BodyB.Pos) / 2;
                if norm(mid - pos) < 0.2
                    c = con; return;
                end
            end
        end

        %% ---------------- Property Editing ----------------
        function updatePropertyPanel(obj)
            % Clear panel
            delete(allchild(obj.UI.PropPanel));
            y = 120; dy = 30; xpad = 10;

            if ~isempty(obj.SelectedBody)
                uicontrol(obj.UI.PropPanel, 'Style', 'text', 'String', 'Body Properties', ...
                    'Position', [xpad y 160 20], 'FontWeight', 'bold');
                y = y - dy;
                uicontrol(obj.UI.PropPanel, 'Style', 'text', 'String', 'Mass', 'Position', [xpad y 60 20]);
                obj.UI.MassEdit = uicontrol(obj.UI.PropPanel, 'Style', 'edit', 'String', ...
                    num2str(obj.SelectedBody.Mass), 'Position', [xpad+70 y 50 20], ...
                    'Callback', @(s,e)obj.setBodyProperty('Mass'));
                y = y - dy;

                obj.UI.FixedCheckbox = uicontrol(obj.UI.PropPanel, 'Style', 'checkbox', ...
                    'String', 'Fixed', 'Value', obj.SelectedBody.Fixed, ...
                    'Position', [xpad y 100 20], 'Callback', @(s,e)obj.setBodyProperty('Fixed'));
            elseif ~isempty(obj.SelectedConstraint)
                uicontrol(obj.UI.PropPanel, 'Style', 'text', 'String', 'Constraint Properties', ...
                    'Position', [xpad y 160 20], 'FontWeight', 'bold');
                y = y - dy;
                uicontrol(obj.UI.PropPanel, 'Style', 'text', 'String', 'RestLength', ...
                    'Position', [xpad y 60 20]);
                obj.UI.RestLengthEdit = uicontrol(obj.UI.PropPanel, 'Style', 'edit', ...
                    'String', num2str(obj.SelectedConstraint.RestLength), ...
                    'Position', [xpad+70 y 50 20], 'Callback', @(s,e)obj.setConstraintProperty('RestLength'));
                y = y - dy;

                uicontrol(obj.UI.PropPanel, 'Style', 'text', 'String', 'Elasticity', ...
                    'Position', [xpad y 60 20]);
                obj.UI.ElasticityEdit = uicontrol(obj.UI.PropPanel, 'Style', 'edit', ...
                    'String', num2str(obj.SelectedConstraint.Elasticity), ...
                    'Position', [xpad+70 y 50 20], 'Callback', @(s,e)obj.setConstraintProperty('Elasticity'));
            end
        end

        function setBodyProperty(obj, prop)
            if isempty(obj.SelectedBody), return; end
            switch prop
                case 'Mass'
                    obj.SelectedBody.Mass = str2double(obj.UI.MassEdit.String);
                case 'Fixed'
                    obj.SelectedBody.Fixed = obj.UI.FixedCheckbox.Value;
            end
        end

        function setConstraintProperty(obj, prop)
            if isempty(obj.SelectedConstraint), return; end
            switch prop
                case 'RestLength'
                    obj.SelectedConstraint.RestLength = str2double(obj.UI.RestLengthEdit.String);
                case 'Elasticity'
                    obj.SelectedConstraint.Elasticity = str2double(obj.UI.ElasticityEdit.String);
            end
        end

        %% ---------------- Core Constants ----------------
        function setGravity(obj)
            obj.Core.Gravity(2) = str2double(obj.UI.GravityEdit.String);
        end

        function setDt(obj)
            obj.Core.dt = str2double(obj.UI.dtEdit.String);
        end

        function setDrawTime(obj)
            obj.Core.DrawInterval = str2double(obj.UI.DrawTimeEdit.String);
        end

        function exitEditor(obj)
            obj.Core.Running = false;
            if isvalid(obj.Core.FigureHandle)
                close(obj.Core.FigureHandle);
            end
        end
    end
end
