classdef Editor < handle
    properties
        Core            % Core class reference
        Scene           % Scene reference
        AxesHandle      % Axes to draw in
        SelectedBody = []
        SelectedConstraint = []
        Mode = 'select'
        UI = struct()
        Menu = struct()
        PanelWidth = 200
        GroundObj
        isCurrentlySelecting = false;
    end

    methods
        function obj = Editor(core, scene, ax)
            obj.Core = core;
            obj.Scene = scene;
            obj.AxesHandle = ax;

            obj.Core.onTick = @()obj.updateToolbar();

            obj.createMenu();
        end

        %% ----------------Menu----------------
        function createMenu(obj)

            % Hide axes
            obj.AxesHandle.Visible = 'off';

            % Parent figure
            fig = obj.AxesHandle.Parent;
            fig.Units = 'normalized';

            % Size of menu panel (normalized)
            menuW = 0.4;
            menuH = 0.4;

            % Center the panel in the figure
            menuX = (1 - menuW) / 2;
            menuY = (1 - menuH) / 2;

            % Create the menu panel
            obj.Menu.MenuPanel = uipanel(...
                'Parent', fig, ...
                'Title', '', ...        % no titlebar
                'Units', 'normalized', ...
                'Position', [menuX menuY menuW menuH], ...
                'BorderType', 'none');

            % Button geometry
            buttonW = 0.6;      % 60% panel width
            buttonH = 0.18;     % 18% panel height
            buttonX = (1 - buttonW) / 2;  % center horizontally

            % Vertical positions (nicely spaced)
            y1 = 0.65;
            y2 = 0.40;
            y3 = 0.15;

            % Create "Create New Scene"
            obj.Menu.CreateNewScene = uicontrol(obj.Menu.MenuPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Create New Scene', ...
                'Units', 'normalized', ...
                'Position', [buttonX y1 buttonW buttonH], ...
                'Callback', @(~,~) obj.CreateNewScene());

            % Create "Documentation"
            obj.Menu.Documentation = uicontrol(obj.Menu.MenuPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Documentation', ...
                'Units', 'normalized', ...
                'Position', [buttonX y2 buttonW buttonH], ...
                'Callback', @(~,~) obj.SeeDocumentation());

            % Create "Exit"
            uicontrol(obj.Menu.MenuPanel, ...
                'Style', 'pushbutton', ...
                'String', 'Exit', ...
                'Units', 'normalized', ...
                'Position', [buttonX y3 buttonW buttonH], ...
                'Callback', @(~,~) close(fig));

        end

        %% ---------------Menu Functions-----------------
        function CreateNewScene(obj)
            fields = fieldnames(obj.Menu);
            for i = 1:numel(fields)
                if isvalid(obj.Menu.(fields{i}))
                    obj.Menu.(fields{i}).Visible = 'off';
                end
            end

            obj.AxesHandle.Visible = 'on';
            obj.createUI();
            obj.createToolbar();

            % Set up mouse events for interactions
            fig = obj.AxesHandle.Parent;
            fig.WindowButtonDownFcn   = @(~,~) obj.onMouseDown();
            fig.WindowButtonUpFcn     = @(~,~) obj.onMouseUp();
            fig.WindowButtonMotionFcn = @(~,~) obj.onMouseMove();
            fig.WindowKeyPressFcn = @(src, evt) obj.keyHandler(evt);

            obj.Core.run();
        end

        function SeeDocumentation(~)
            % Get project root (parent of /app)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));

            outDir = fullfile(projectRoot, 'docs');
            if ~exist(outDir, 'dir')
                mkdir(outDir);
            end

            % List of subfolders to include
            subFolders = {'App', 'Utils', 'Core'};

            files = [];

            for i = 1:length(subFolders)
                folderPath = fullfile(projectRoot, subFolders{i});
                if exist(folderPath, 'dir')
                    folderFiles = dir(fullfile(folderPath, '*.m'));
                    files = [files; folderFiles];  % append
                end
            end


            for k = 1:numel(files)
                filePath = fullfile(files(k).folder, files(k).name);
                [~, name] = fileparts(filePath);

                % ==========================
                % 1) Generate HTML
                % ==========================
                htmlOpts = struct( ...
                    'format', 'html', ...
                    'outputDir', outDir, ...
                    'showCode', true, ...
                    'evalCode', false ...
                    );
                try
                    publish(filePath, htmlOpts);
                catch ME
                    warning("HTML generation failed for %s: %s", name, ME.message);
                end

                % ==========================
                % 2) Generate PDF
                % ==========================
                pdfOpts = struct( ...
                    'format', 'pdf', ...
                    'outputDir', outDir, ...
                    'showCode', true, ...
                    'evalCode', false ...
                    );
                try
                    publish(filePath, pdfOpts);
                catch ME
                    warning("PDF generation failed for %s: %s", name, ME.message);
                end
            end

            fprintf("Documentation generated in: %s\n", outDir);
        end


        %% ---------------- UI ----------------
        function createUI(obj)
            fig = obj.AxesHandle.Parent;
            fig.Units = 'normalized';

            % ---------------- Panel ----------------
            obj.UI.MainPanel = uipanel(fig, 'Title','Editor', ...
                'Units','normalized','Position',[0.82 0.05 0.16 0.9]);

            % ---------------- Mode Buttons ----------------
            modes = {'select', 'addCircle', 'addRect', 'drag', 'addConstraint', 'delete'};
            yStart = 0.88; dy = 0.06; hBtn = 0.05;
            for i = 1:numel(modes)
                uicontrol(obj.UI.MainPanel,'Style','pushbutton','String',modes{i}, ...
                    'Units','normalized','Position',[0.05 yStart-(i-1)*dy 0.9 hBtn], ...
                    'Callback', @(s,e)obj.setMode(modes{i}));
            end

            % ---------------- Global Constants ----------------
            yConst = yStart - dy*numel(modes) - 0.02;
            uicontrol(obj.UI.MainPanel,'Style','text','String','Global Constants', ...
                'Units','normalized','FontWeight','bold','Position',[0.05 yConst 0.9 0.04]);
            yConst = yConst - 0.05;

            % Gravity Y
            uicontrol(obj.UI.MainPanel,'Style','text','String','Gravity Y', ...
                'Units','normalized','Position',[0.05 yConst 0.35 0.04]);
            obj.UI.GravityEdit = uicontrol(obj.UI.MainPanel,'Style','edit', ...
                'Units','normalized','String',num2str(obj.Core.Gravity(2)), ...
                'Position',[0.45 yConst 0.5 0.04],'Callback',@(s,e)obj.setGravity());
            yConst = yConst - 0.05;

            % dt
            uicontrol(obj.UI.MainPanel,'Style','text','String','dt', ...
                'Units','normalized','Position',[0.05 yConst 0.35 0.04]);
            obj.UI.dtEdit = uicontrol(obj.UI.MainPanel,'Style','edit', ...
                'Units','normalized','String',num2str(obj.Core.dt), ...
                'Position',[0.45 yConst 0.5 0.04],'Callback',@(s,e)obj.setDt());
            yConst = yConst - 0.05;

            % Draw Interval
            uicontrol(obj.UI.MainPanel,'Style','text','String','Draw Interval', ...
                'Units','normalized','Position',[0.05 yConst 0.45 0.04]);
            obj.UI.DrawTimeEdit = uicontrol(obj.UI.MainPanel,'Style','edit', ...
                'Units','normalized','String',num2str(obj.Core.DrawInterval), ...
                'Position',[0.55 yConst 0.4 0.04],'Callback',@(s,e)obj.setDrawTime());
            yConst = yConst - 0.05;

            % Toggle Ground
            uicontrol(obj.UI.MainPanel,'Style','text','String','Toggle Ground', ...
                'Units','normalized','Position',[0.05 yConst 0.45 0.04]);
            obj.UI.GroundEnable = uicontrol(obj.UI.MainPanel,'Style','checkbox', ...
                'Units','normalized','Position',[0.55 yConst 0.4 0.04], ...
                'Callback', @(s,e)obj.setGround());
            yConst = yConst - 0.05;

            % Gravity enable toggle
            uicontrol(obj.UI.MainPanel,'Style','text','String','Enable Gravity', ...
                'Units','normalized','Position',[0.05 yConst 0.45 0.04]);
            obj.UI.GravityEnable = uicontrol(obj.UI.MainPanel,'Style','checkbox', ...
                'Value',true,'Units','normalized','Position',[0.55 yConst 0.4 0.04], ...
                'Callback', @(s,e)obj.toggleGravity());
            yConst = yConst - 0.05;

            % Pause simulation
            obj.UI.PauseCheckbox = uicontrol(obj.UI.MainPanel,'Style','checkbox','String','Pause', ...
                'Value',obj.Core.Paused,'Units','normalized','Position',[0.05 yConst 0.9 0.04], ...
                'Callback', @(s,e)obj.togglePause());

            % Exit button at bottom
            uicontrol(obj.UI.MainPanel,'Style','pushbutton','String','Exit', ...
                'Units','normalized','Position',[0.05 0.02 0.9 0.05], ...
                'Callback', @(s,e)obj.exitEditor());
        end

        function createToolbar(obj)
            fig = obj.AxesHandle.Parent;

            % ---- Toolbar ----
            tb = uitoolbar(fig);
            obj.UI.ToolBar = struct();
            obj.UI.ToolBar.Handle = tb;

            % ---- Status Panel ----
            obj.UI.StatusPanel = uipanel(fig, ...
                'Units','normalized', ...
                'BorderType','none', ...
                'Position',[0.01 0.94 0.7 0.05]);  % top-left strip

            % FPS
            obj.UI.Status.FPS = uicontrol(obj.UI.StatusPanel, ...
                'Style','text', ...
                'Units','normalized', ...
                'HorizontalAlignment','left', ...
                'Position',[0.00 0.1 0.25 0.8], ...
                'String','FPS: --');

            % Bodies
            obj.UI.Status.Bodies = uicontrol(obj.UI.StatusPanel, ...
                'Style','text', ...
                'Units','normalized', ...
                'HorizontalAlignment','left', ...
                'Position',[0.26 0.1 0.25 0.8], ...
                'String','Bodies: 0');

            % Constraints
            obj.UI.Status.Constraints = uicontrol(obj.UI.StatusPanel, ...
                'Style','text', ...
                'Units','normalized', ...
                'HorizontalAlignment','left', ...
                'Position',[0.35 0.1 0.30 0.8], ...
                'String','Constraints: 0');

            % Paused state
            obj.UI.Status.Paused = uicontrol(obj.UI.StatusPanel, ...
                'Style','text', ...
                'Units','normalized', ...
                'HorizontalAlignment','left', ...
                'Position',[0.55 0.1 0.17 0.8], ...
                'String','RUNNING', ...
                'ForegroundColor',[0 0.6 0]);

            % --- Background color picker ---
            obj.UI.ToolBar.BgColorBtn = uicontrol(obj.UI.StatusPanel, ...
                'Style', 'pushbutton', ...
                'TooltipString', 'Pick Background Color', ...
                'String', 'Pick Background Color', ...
                'Units','normalized', ...
                'Position',[0.65 0.1 0.2 0.8],...
                'Callback', @(s,e)obj.pickBackgroundColor());

            % --- Current mode hint ---
            obj.UI.ToolBar.ModeHint = uicontrol(obj.UI.StatusPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'left', ...
                'Position', [0.9 0.1 0.18 0.8], ...  
                'String', 'Mode: select');


        end

        function updateToolbar(obj)
            if ~isfield(obj.UI, 'Status') || isempty(obj.UI.Status)
                return;
            end

            status = obj.UI.Status;
            core = obj.Core;

            % ---- FPS ----
            if isfield(status, 'FPS') && isvalid(status.FPS)
                status.FPS.String = sprintf('FPS: %.1f', core.FPS);
            end

            % ---- Body count ----
            if isfield(status, 'Bodies') && isvalid(status.Bodies)
                status.Bodies.String = sprintf('Bodies: %d', numel(core.Scene.Bodies));
            end

            % ---- Constraint count ----
            if isfield(status, 'Constraints') && isvalid(status.Constraints)
                status.Constraints.String = sprintf('Constraints: %d', numel(core.Scene.Constraints));
            end

            % ---- Paused state ----
            if isfield(status, 'Paused') && isvalid(status.Paused)
                if core.Paused
                    status.Paused.String = 'PAUSED';
                    status.Paused.ForegroundColor = [0.8 0 0];
                else
                    status.Paused.String = 'RUNNING';
                    status.Paused.ForegroundColor = [0 0.6 0];
                end
            end
        end

        %% ---------------- Mode handling ----------------
        function setMode(obj, mode)

            % Update toolbar hint if it exists
            if isfield(obj.UI.ToolBar,'ModeHint') && isvalid(obj.UI.ToolBar.ModeHint)
                obj.UI.ToolBar.ModeHint.String = ['Mode: ', mode];
            end

            obj.Mode = mode;
            obj.SelectedBody = [];
            obj.SelectedConstraint = [];
        end

        %% ---------------- Mouse Events ----------------
        function onMouseDown(obj)
            pos = obj.AxesHandle.CurrentPoint(1,1:2)';
            fig = obj.AxesHandle.Parent;

            selecting = false;

            clickType = fig.SelectionType;
            if strcmp(clickType,'normal')
                switch obj.Mode
                    case 'addCircle'
                        obj.Scene.addBody(Body(pos, [0;0], 1, 'circle', 0.5, [rand(1) rand(1) rand(1)]));
                    case 'addRect'
                        obj.Scene.addBody(Body(pos, [0;0], 1, 'rect', [3 1],[rand(1) rand(1) rand(1)]));
                    case 'drag'
                        obj.SelectedBody = obj.pickBody(pos);
                    case 'select'
                        selecting = true;
                        obj.SelectedBody = obj.pickBody(pos);
                        obj.SelectedConstraint = obj.pickConstraint(pos);
                    case 'addConstraint'
                        obj.SelectedBody = obj.pickBody(pos);
                    case 'delete'
                        obj.deleteAtPosition(pos);
                end
            elseif strcmp(clickType,'alt')
                selecting = true;
                obj.SelectedBody = obj.pickBody(pos);
                obj.SelectedConstraint = obj.pickConstraint(pos);
            end

            if selecting
                mousePos = get(0,'PointerLocation');
                obj.openConstraintPropertyPanel(mousePos(1),mousePos(2));
                obj.openBodyPropertyPanel(mousePos(1),mousePos(2));
            end
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
                obj.SelectedBody.Dragged = false;
                obj.SelectedBody = [];
            end
        end

        function onMouseMove(obj)
            if strcmp(obj.Mode, 'drag') && ~isempty(obj.SelectedBody)
                pos = obj.AxesHandle.CurrentPoint(1,1:2)';
                obj.SelectedBody.Pos = pos;
                obj.SelectedBody.Dragged = true;
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
                        b = body;
                    end
                else
                    if pos(1) >= body.Pos(1)-body.Width/2 && pos(1) <= body.Pos(1)+body.Width/2 && ...
                            pos(2) >= body.Pos(2)-body.Height/2 && pos(2) <= body.Pos(2)+body.Height/2
                        b = body;
                    end
                end
            end
            if(isfield(obj.UI, 'tempBody') && ~isempty(obj.SelectedBody) && isvalid(obj.UI.tempBody))
                delete(obj.UI.tempBody);
                obj.isCurrentlySelecting = false;
            end
        end

        function c = pickConstraint(obj, pos)
            c = [];
            for i = 1:numel(obj.Scene.Constraints)
                con = obj.Scene.Constraints{i};
                mid = (con.BodyA.Pos + con.BodyB.Pos) / 2;
                if norm(mid - pos) < 0.3
                    c = con;
                end
            end
            if(isfield(obj.UI, 'tempConstr') && ~isempty(obj.SelectedConstraint) &&  isvalid(obj.UI.tempConstr))
                delete(obj.UI.tempConstr);
                obj.isCurrentlySelecting = false;
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

                uicontrol(obj.UI.PropPanel, 'Style', 'text', 'String', 'Stiffness', ...
                    'Position', [xpad y 60 20]);
                obj.UI.ElasticityEdit = uicontrol(obj.UI.PropPanel, 'Style', 'edit', ...
                    'String', num2str(obj.SelectedConstraint.Stiffness), ...
                    'Position', [xpad+70 y 50 20], 'Callback', @(s,e)obj.setConstraintProperty('Stiffness'));
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
                case 'Stiffness'
                    obj.SelectedConstraint.Stiffness = str2double(obj.UI.ElasticityEdit.String);
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

        function setGround(obj)

            % Create ground if checkbox is checked
            if obj.UI.GroundEnable.Value
                obj.GroundObj = Body([0 -10]', [0 0], 0, 'rect', [100 0.5],[1 rand(1) 1], true);
                obj.Core.Scene.addBody(obj.GroundObj);
            else
                obj.GroundObj.Active = false;
                obj.GroundObj.GraphicHandle.XData =[];
                obj.GroundObj.GraphicHandle.YData =[];
                obj.GroundObj.GraphicHandle.Visible = 'off';
            end
        end

        function toggleGravity(obj)
            if obj.UI.GravityEnable.Value
                obj.Core.Gravity(2) = -9.81;
            else
                obj.Core.Gravity(2) = 0;
            end
        end

        function pickBackgroundColor(obj)
            fig = obj.AxesHandle.Parent;
            fig.Units = 'pixels';%normalized units break modal box(wtf matlab)
            c = uisetcolor();
            if length(c) == 3  % user did not cancel
                obj.AxesHandle.Color = c;
            end
            fig.Units = 'normalized';
        end

        function togglePause(obj)
            obj.Core.Paused = ~obj.Core.Paused;
            obj.UI.PauseCheckbox.Value = obj.Core.Paused; % sync checkbox
        end

        function keyHandler(obj, evt)
            switch evt.Key
                case 'escape'
                    obj.Core.Running = false;
                    if isvalid(obj.Core.FigureHandle)
                        close(obj.Core.FigureHandle);
                    end

                case 'space'
                    obj.togglePause();  % toggle pause on space

                    % ---------- Mode shortcuts ----------
                case 'c'  % add circle
                    obj.setMode('addCircle');

                case 'r'  % add rectangle
                    obj.setMode('addRect');

                case 'k'  % add constraint
                    obj.setMode('addConstraint');

                case 'g'  % toggle ground
                    obj.UI.GroundEnable.Value = ~obj.UI.GroundEnable.Value;
                    obj.setGround();  % same as clicking the checkbox

                case 'q'  % reset scene
                    obj.Scene.reset();  % you need a reset function in Scene
                    obj.Scene.updateGraphics(obj.AxesHandle);  % redraw
            end
        end

        function openBodyPropertyPanel(obj,mouseX,mouseY)
            if isempty(obj.SelectedBody) || obj.isCurrentlySelecting == true
                return;
            end

            obj.isCurrentlySelecting = true;
            body = obj.SelectedBody;

            % Create figure for properties
            f = figure('Name','Body Properties','NumberTitle','off', ...
                'MenuBar','none','ToolBar','none','Resize','off', ...
                'Position',[mouseX-300 mouseY-400 300 400],...
                'CloseRequestFcn',@(src,~)closer(src));
            function closer(src)
                obj.isCurrentlySelecting = false;
                obj.SelectedBody = [];
                delete(src);
            end
            obj.UI.tempBody = f;
            y = 350; dy = 30; xpad = 10;

            % Position X
            uicontrol(f,'Style','text','String','Position X','Position',[xpad y 80 20]);
            posXEdit = uicontrol(f,'Style','edit','String',num2str(body.Pos(1)),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setPosX());

            y = y - dy;
            % Position Y
            uicontrol(f,'Style','text','String','Position Y','Position',[xpad y 80 20]);
            posYEdit = uicontrol(f,'Style','edit','String',num2str(body.Pos(2)),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setPosY());

            y = y - dy;
            % Velocity X
            uicontrol(f,'Style','text','String','Velocity X','Position',[xpad y 80 20]);
            velXEdit = uicontrol(f,'Style','edit','String',num2str(body.Vel(1)),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setVelX());

            y = y - dy;
            % Velocity Y
            uicontrol(f,'Style','text','String','Velocity Y','Position',[xpad y 80 20]);
            velYEdit = uicontrol(f,'Style','edit','String',num2str(body.Vel(2)),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setVelY());

            y = y - dy;
            % Angle
            uicontrol(f,'Style','text','String','Angle','Position',[xpad y 80 20]);
            angleEdit = uicontrol(f,'Style','edit','String',num2str(body.Angle),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setAngle());

            y = y - dy;
            % Angular velocity
            uicontrol(f,'Style','text','String','Omega','Position',[xpad y 80 20]);
            omegaEdit = uicontrol(f,'Style','edit','String',num2str(body.Omega),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setOmega());

            y = y - dy;
            % Mass
            uicontrol(f,'Style','text','String','Mass','Position',[xpad y 80 20]);
            massEdit = uicontrol(f,'Style','edit','String',num2str(body.Mass),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setMass());

            y = y - dy;
            % Fixed
            fixedCheck = uicontrol(f,'Style','checkbox','String','Fixed','Value',body.Fixed,'Position',[xpad y 100 20], ...
                'Callback', @(s,e)setFixed());

            y = y - dy;
            % Shape
            uicontrol(f,'Style','text','String','Shape','Position',[xpad y 80 20]);
            uicontrol(f,'Style','text','String',body.Shape,'Position',[100 y 100 20]);

            y = y - dy;
            if strcmp(body.Shape,'circle')
                % Radius
                uicontrol(f,'Style','text','String','Radius','Position',[xpad y 80 20]);
                radiusEdit = uicontrol(f,'Style','edit','String',num2str(body.Radius),'Position',[100 y 100 20], ...
                    'Callback', @(s,e)setRadius());
            else
                % Width
                uicontrol(f,'Style','text','String','Width','Position',[xpad y 80 20]);
                widthEdit = uicontrol(f,'Style','edit','String',num2str(body.Width),'Position',[100 y 100 20], ...
                    'Callback', @(s,e)setWidth());

                y = y - dy;
                % Height
                uicontrol(f,'Style','text','String','Height','Position',[xpad y 80 20]);
                heightEdit = uicontrol(f,'Style','edit','String',num2str(body.Height),'Position',[100 y 100 20], ...
                    'Callback', @(s,e)setHeight());
            end

            % --- Body color ---
            y = y - dy;
            uicontrol(f,'Style','text','String','Color','Position',[xpad y 80 20]);

            bodyColorBtn = uicontrol(f,'Style','pushbutton', ...
                'BackgroundColor', body.Color, ...
                'Position',[100 y 100 20], ...
                'Callback', @(s,e)pickBodyColor());




            % --- Callback functions ---
            function setPosX(), body.Pos(1) = str2double(posXEdit.String); body.updateGraphic(obj.AxesHandle); end
            function setPosY(), body.Pos(2) = str2double(posYEdit.String); body.updateGraphic(obj.AxesHandle); end
            function setVelX(), body.Vel(1) = str2double(velXEdit.String); end
            function setVelY(), body.Vel(2) = str2double(velYEdit.String); end
            function setAngle(), body.Angle = str2double(angleEdit.String); body.updateGraphic(obj.AxesHandle); end
            function setOmega(), body.Omega = str2double(omegaEdit.String); end
            function pickBodyColor()
                c = uisetcolor(body.Color);
                if length(c) == 3
                    body.Color = c;
                    body.updateGraphic(obj.AxesHandle);
                    bodyColorBtn.BackgroundColor = c;
                end
            end
            function setMass()
                body.Mass = str2double(massEdit.String);
                if strcmp(body.Shape,'circle'), body.Inertia = 0.5 * body.Mass * body.Radius^2;
                else, body.Inertia = body.Mass * (body.Width^2 + body.Height^2)/12; end
            end
            function setFixed(), body.Fixed = fixedCheck.Value; end
            function setRadius()
                body.Radius = str2double(radiusEdit.String);
                body.Inertia = 0.5 * body.Mass * body.Radius^2;
                body.updateGraphic(obj.AxesHandle);
            end
            function setWidth()
                body.Width = str2double(widthEdit.String);
                body.Inertia = body.Mass * (body.Width^2 + body.Height^2)/12;
                body.updateGraphic(obj.AxesHandle);
            end
            function setHeight()
                body.Height = str2double(heightEdit.String);
                body.Inertia = body.Mass * (body.Width^2 + body.Height^2)/12;
                body.updateGraphic(obj.AxesHandle);
            end
        end

        function openConstraintPropertyPanel(obj,mouseX,mouseY)
            if isempty(obj.SelectedConstraint) || obj.isCurrentlySelecting
                return;
            end

            obj.isCurrentlySelecting = true;
            con = obj.SelectedConstraint;

            % Create figure for properties
            f = figure('Name','Constraint Properties','NumberTitle','off', ...
                'MenuBar','none','ToolBar','none','Resize','off', ...
                'Position',[mouseX-300 mouseY-300 300 300],...
                'CloseRequestFcn',@(src,~)closer(src));
            function closer(src)
                obj.isCurrentlySelecting = false;
                obj.SelectedConstraint = [];
                delete(src);
            end
            obj.UI.tempConstr = f;

            y = 250; dy = 50; xpad = 10;

            % Body A
            uicontrol(f,'Style','text','String','Body A Pos','Position',[xpad y 80 30]);
            uicontrol(f,'Style','text','String',num2str(con.BodyA.Pos),'Position',[100 y 100 40]);
            y = y - dy;

            % Body B
            uicontrol(f,'Style','text','String','Body B Pos','Position',[xpad y 80 30]);
            uicontrol(f,'Style','text','String',num2str(con.BodyB.Pos),'Position',[100 y 100 40]);
            y = y - dy;

            % Rest length
            uicontrol(f,'Style','text','String','Rest Length','Position',[xpad y 80 20]);
            restEdit = uicontrol(f,'Style','edit','String',num2str(con.RestLength),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setRest());
            y = y - dy;

            % Stiffness
            uicontrol(f,'Style','text','String','Stiffness','Position',[xpad y 80 20]);
            stiffEdit = uicontrol(f,'Style','edit','String',num2str(con.Stiffness),'Position',[100 y 100 20], ...
                'Callback', @(s,e)setStiff());

            % --- Callback functions ---
            function setRest()
                val = str2double(restEdit.String);
                if ~isnan(val) && val > 0
                    con.RestLength = val;
                    con.updateGraphic(obj.AxesHandle);
                else
                    restEdit.String = num2str(con.RestLength);
                end
            end

            function setStiff()
                val = str2double(stiffEdit.String);
                if ~isnan(val) && val >= 0 && val <= 1
                    con.Stiffness = val;
                    con.updateGraphic(obj.AxesHandle);
                else
                    stiffEdit.String = num2str(con.Stiffness);
                end
            end
        end

    end
end
