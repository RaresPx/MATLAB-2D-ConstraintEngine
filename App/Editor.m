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
        currentSceneData = {};
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


            obj.AxesHandle.Visible = 'off';
            fig = obj.AxesHandle.Parent;
            fig.Units = 'normalized';

            menuW = 0.45;
            menuH = 0.5;
            menuX = (1-menuW)/2;
            menuY = (1-menuH)/2;

            obj.Menu.MenuPanel = uipanel(fig, ...
                'Units','normalized', ...
                'Position',[menuX menuY menuW menuH], ...
                'BorderType','none');

            % --- Scene dropdown ---
            obj.Menu.SceneList = uicontrol(obj.Menu.MenuPanel, ...
                'Style','popupmenu', ...
                'Units','normalized', ...
                'Position',[0.2 0.75 0.6 0.12], ...
                'String', obj.getSceneNames());

            obj.Menu.SceneList.Value = 1;

            set(obj.Menu.SceneList, ...
                'TooltipString','Select a scene to load');


            % --- Load scene ---
            uicontrol(obj.Menu.MenuPanel, ...
                'Style','pushbutton', ...
                'String','Load Scene', ...
                'Units','normalized', ...
                'Position',[0.2 0.58 0.6 0.12], ...
                'Callback', @(~,~)obj.loadSceneFromMenu());

            % --- Create new scene ---
            uicontrol(obj.Menu.MenuPanel, ...
                'Style','pushbutton', ...
                'String','Create New Scene', ...
                'Units','normalized', ...
                'Position',[0.2 0.41 0.6 0.12], ...
                'Callback', @(~,~)obj.createNewSceneFromMenu());

            % --- Docs ---
            uicontrol(obj.Menu.MenuPanel, ...
                'Style','pushbutton', ...
                'String','Documentation', ...
                'Units','normalized', ...
                'Position',[0.2 0.24 0.6 0.12], ...
                'Callback', @(~,~)obj.SeeDocumentation());

            % --- Exit ---
            uicontrol(obj.Menu.MenuPanel, ...
                'Style','pushbutton', ...
                'String','Exit', ...
                'Units','normalized', ...
                'Position',[0.2 0.07 0.6 0.12], ...
                'Callback', @(~,~)close(fig));
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

        function SeeDocumentation(obj)
            % Get project root (parent of /app)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            docsDir = fullfile(projectRoot, 'docs');

            % Create docs folder if missing
            if ~exist(docsDir, 'dir')
                mkdir(docsDir);
            end

            % List of subfolders to include
            subFolders = {'App', 'Utils', 'Core'};

            % Gather all .m files
            files = [];
            for i = 1:length(subFolders)
                folderPath = fullfile(projectRoot, subFolders{i});
                if exist(folderPath,'dir')
                    folderFiles = dir(fullfile(folderPath,'*.m'));
                    files = [files; folderFiles]; %#ok<AGROW>
                end
            end

            % Generate files that don't exist yet
            for k = 1:numel(files)
                filePath = fullfile(files(k).folder, files(k).name);
                [~, name] = fileparts(filePath);

                % HTML
                htmlFile = fullfile(docsDir, [name,'.html']);
                if ~exist(htmlFile,'file')
                    try
                        publish(filePath, struct('format','html','outputDir',docsDir,'showCode',true,'evalCode',false));
                    catch ME
                        warning("HTML generation failed for %s: %s", name, ME.message);
                    end
                end

                % PDF
                pdfFile = fullfile(docsDir, [name,'.pdf']);
                if ~exist(pdfFile,'file')
                    try
                        publish(filePath, struct('format','pdf','outputDir',docsDir,'showCode',true,'evalCode',false));
                    catch ME
                        warning("PDF generation failed for %s: %s", name, ME.message);
                    end
                end
            end

            % Open picker after generation
            obj.showDocsPicker(docsDir);
        end

        function showDocsPicker(~, docsDir)
            files = [dir(fullfile(docsDir,'*.html')); dir(fullfile(docsDir,'*.pdf'))];
            if isempty(files)
                errordlg('No documentation files found.','Docs');
                return;
            end
            names = {files.name};

            fig = figure('Name','Documentation', ...
                'NumberTitle','off', 'MenuBar','none', 'ToolBar','none', ...
                'Units','normalized', 'Position',[0.35 0.35 0.3 0.2], 'WindowStyle','modal');

            popup = uicontrol(fig,'Style','popupmenu','Units','normalized',...
                'Position',[0.1 0.6 0.8 0.2],'String', names);

            uicontrol(fig,'Style','pushbutton','String','Open','Units','normalized',...
                'Position',[0.1 0.25 0.35 0.2],'Callback', @(~,~)openSelected());

            uicontrol(fig,'Style','pushbutton','String','Close','Units','normalized',...
                'Position',[0.55 0.25 0.35 0.2],'Callback', @(~,~)close(fig));

            function openSelected()
                idx = popup.Value;
                filePath = fullfile(docsDir, names{idx});
                web(filePath,'-browser');
            end
        end


        function names = getSceneNames(obj)
            dirPath = obj.getSceneDir();
            files = dir(fullfile(dirPath,'*.mat'));

            fileNames = erase({files.name}, '.mat');

            % Default scene always first
            names = [{'Default Scene'}, fileNames];
        end


        function loadSceneFromMenu(obj)
            names = obj.Menu.SceneList.String;
            idx   = obj.Menu.SceneList.Value;
            choice = names{idx};


            if strcmp(choice, 'Default Scene')
                obj.Core.Scene.resetDefault();
            else
                file = fullfile(obj.getSceneDir(), [choice '.mat']);
                if exist(file, 'file')
                    loaded = load(file, 'data');          % load only 'data'
                    if isfield(loaded, 'data')
                        obj.Core.Scene.fromStruct(loaded.data);  % pass the scene struct
                        obj.currentSceneData = loaded.data;
                    else
                        errordlg('Invalid scene file: missing "data"','Load Scene Error');
                    end
                else
                    errordlg(['Scene file not found: ' file], 'Load Scene Error');
                end
            end

            obj.startEditor(); % refresh editor
        end

        function createNewSceneFromMenu(obj)
            obj.Core.Scene.resetEmpty();
            obj.startEditor();
        end

        function resetToDefaultScene(obj)
            obj.Core.Scene.resetDefault();
            obj.startEditor();
        end

        %% ---------------- UI ----------------
        function startEditor(obj)

            % Hide menu
            fields = fieldnames(obj.Menu);
            for i = 1:numel(fields)
                if isvalid(obj.Menu.(fields{i}))
                    obj.Menu.(fields{i}).Visible = 'off';
                end
            end

            obj.AxesHandle.Visible = 'on';
            obj.createUI();
            obj.createToolbar();

            fig = obj.AxesHandle.Parent;
            fig.WindowButtonDownFcn   = @(~,~) obj.onMouseDown();
            fig.WindowButtonUpFcn     = @(~,~) obj.onMouseUp();
            fig.WindowButtonMotionFcn = @(~,~) obj.onMouseMove();
            fig.WindowKeyPressFcn     = @(src,evt)obj.keyHandler(evt);

            obj.Core.run();
        end

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
            uicontrol(obj.UI.MainPanel,'Style','pushbutton','String','Menu', ...
                'Units','normalized','Position',[0.05 0.1 0.9 0.05], ...
                'Callback', @(s,e)obj.goBackToMenu());

            % Exit button at bottom
            uicontrol(obj.UI.MainPanel,'Style','pushbutton','String','Exit', ...
                'Units','normalized','Position',[0.05 0.02 0.9 0.05], ...
                'Callback', @(s,e)obj.exitEditor());
        end

        function createToolbar(obj)
            fig = obj.AxesHandle.Parent;

            % ---- Fake toolbar panel ----
            toolbarHeight = 0.085; % slightly taller for comfort
            obj.UI.ToolBar.Panel = uipanel(fig, ...
                'Units','normalized', ...
                'Position',[0.03 0.92 0.75 toolbarHeight], ...
                'BorderType','line', ...
                'BackgroundColor',[0.2 0.2 0.2]); % dark gray

            % ---- Status boxes (top row) ----
            statusH = 0.45; spacing = 0.01;
            statusW = 0.17; % slightly narrower
            startX = 0.01; startY = 0.52;
            fields = {'FPS','Bodies','Constraints','Paused'};
            defaultTexts = {'FPS: --','Bodies: 0','Constraints: 0','RUNNING'};
            for i = 1:numel(fields)
                obj.UI.Status.(fields{i}) = uicontrol(obj.UI.ToolBar.Panel, ...
                    'Style','text', ...
                    'Units','normalized', ...
                    'Position',[startX + (statusW+spacing)*(i-1), startY, statusW, statusH], ...
                    'String', defaultTexts{i}, ...
                    'BackgroundColor',[0.3 0.3 0.3], ...
                    'ForegroundColor',[1 1 1], ...
                    'FontWeight','bold', ...
                    'HorizontalAlignment','center');
            end

            % ---- Control buttons (bottom row) ----
            btnH = 0.45; startY = 0.02; btnSpacing = 0.015; btnW = 0.17; startX = 0.01;
            btnBg = [0.4 0.4 0.4]; % uniform gray for buttons
            btnFg = [1 1 1];       % white text

            % Save
            obj.UI.ToolBar.SaveBtn = uicontrol(obj.UI.ToolBar.Panel, ...
                'Style','pushbutton', ...
                'Units','normalized', ...
                'Position',[startX, startY, btnW, btnH], ...
                'String','💾 Save', ...
                'FontSize',12, ...
                'BackgroundColor', btnBg, ...
                'ForegroundColor', btnFg, ...
                'Callback', @(~,~)obj.saveSceneToFile());

            % Load
            obj.UI.ToolBar.LoadBtn = uicontrol(obj.UI.ToolBar.Panel, ...
                'Style','pushbutton', ...
                'Units','normalized', ...
                'Position',[startX + (btnW+btnSpacing)*1, startY, btnW, btnH], ...
                'String','📂 Load', ...
                'FontSize',12, ...
                'BackgroundColor', btnBg, ...
                'ForegroundColor', btnFg, ...
                'Callback', @(~,~)obj.loadSceneFromFile(obj.getSceneDir()));

            % Background color
            obj.UI.ToolBar.BgColorBtn = uicontrol(obj.UI.ToolBar.Panel, ...
                'Style','pushbutton', ...
                'Units','normalized', ...
                'Position',[startX + (btnW+btnSpacing)*2, startY, btnW, btnH], ...
                'String','🎨 BG', ...
                'FontSize',12, ...
                'BackgroundColor', btnBg, ...
                'ForegroundColor', btnFg, ...
                'Callback', @(~,~)obj.pickBackgroundColor());

            % Help
            obj.UI.ToolBar.HelpBtn = uicontrol(obj.UI.ToolBar.Panel, ...
                'Style','pushbutton', ...
                'Units','normalized', ...
                'Position',[startX + (btnW+btnSpacing)*3, startY, btnW, btnH], ...
                'String','❓ Help', ...
                'FontSize',12, ...
                'BackgroundColor', btnBg, ...
                'ForegroundColor', btnFg, ...
                'Callback', @(~,~)obj.openHelp());

            % Mode hint (right-aligned)
            obj.UI.ToolBar.ModeHint = uicontrol(obj.UI.ToolBar.Panel, ...
                'Style','text', ...
                'Units','normalized', ...
                'Position',[0.75, startY, 0.12, btnH], ...
                'String','Mode: select', ...
                'BackgroundColor',[0.2 0.2 0.2], ...
                'ForegroundColor',[1 1 1], ...
                'FontWeight','bold', ...
                'HorizontalAlignment','center');
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

        function saveSceneToFile(obj, defaultDir)
            [file,path] = uiputfile('*.mat','Save Scene As', defaultDir);
            if isequal(file,0); return; end
            fullPath = fullfile(path,file);

            try
                data = obj.Core.Scene.toStruct();
                save(fullPath,'data');
                msgbox(['Scene saved to: ' fullPath],'Save Scene','help');
            catch ME
                errordlg(['Failed to save scene: ' ME.message],'Error');
            end
        end

        function loadSceneFromFile(obj, defaultDir)
            [file,path] = uigetfile('*.mat','Load Scene', defaultDir);
            if isequal(file,0); return; end
            fullPath = fullfile(path,file);

            try
                loaded = load(fullPath,'data');
                obj.currentSceneData = loaded.data;
                if isfield(loaded,'data')
                    obj.Core.Scene.resetEmpty();
                    obj.Core.Scene.fromStruct(loaded.data);
                    msgbox(['Scene loaded: ' fullPath],'Load Scene','help');
                else
                    errordlg('Invalid scene file','Error');
                end
            catch ME
                errordlg(['Failed to load scene: ' ME.message],'Error');
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
            elseif strcmp(clickType,'extend')
                obj.SelectedBody = obj.pickBody(pos);
                obj.Mode = 'drag';
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

        function openHelp(~)
            web('docs/helper.html', '-browser');
        end

        function dirPath = getSceneDir(~)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            dirPath = fullfile(projectRoot, 'scenes');
            if ~exist(dirPath,'dir')
                mkdir(dirPath);
            end
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

                case 'd'  % select drag
                    obj.setMode('drag');  % enter drag mode

                case 'q'  % reset scene to default
                    obj.Core.Scene.fromStruct(obj.currentSceneData);
                    obj.Scene.updateGraphics(obj.AxesHandle);  % redraw scene

                case 'm'  % go back to menu (assuming a button or action is added for this)
                    obj.goBackToMenu();  % trigger menu transition, you will implement this method
            end
        end

        function goBackToMenu(obj)
            % ---------------- Hide/Disable all editor UI elements ----------------

            % Hide all elements in the main editor UI (if they exist)
            if isfield(obj.UI, 'MainPanel') && ishandle(obj.UI.MainPanel)
                obj.UI.MainPanel.Visible = 'off';
            end

            % Hide the ToolBar (if it exists)
            if isfield(obj.UI, 'ToolBar') && ~isempty(obj.UI.ToolBar)
                fieldsToolBar = fieldnames(obj.UI.ToolBar);
                for i = 1:numel(fieldsToolBar)
                    if ishandle(obj.UI.ToolBar.(fieldsToolBar{i}))
                        try
                            obj.UI.ToolBar.(fieldsToolBar{i}).Visible = 'off';  % Hide ToolBar components
                        catch
                            % In case a component doesn't support 'Visible'
                            obj.UI.ToolBar.(fieldsToolBar{i}).Enable = 'off';  % Disable instead
                        end
                    end
                end
            end

            % Reset the editor's core environment, such as clearing selection, mode, etc.
            obj.Mode = 'select';  % Set mode back to default selection
            obj.SelectedBody = [];
            obj.SelectedConstraint = [];

            % Disable all mouse event handlers
            fig = obj.AxesHandle.Parent;
            fig.WindowButtonDownFcn = '';   % Disable mouse down events
            fig.WindowButtonUpFcn = '';     % Disable mouse up events
            fig.WindowButtonMotionFcn = ''; % Disable mouse motion events
            fig.WindowKeyPressFcn = @(src,evt)exit(src,evt);     % Disable keyboard events

            function exit(~, evt)
                % Check if the pressed key is the Escape key
                if strcmp(evt.Key, 'escape')
                    close all;  % Close the figure/app entirely
                end
            end


            % ---------------- Reset UI structures to initial empty state ----------------
            obj.UI = struct();  % Clear out the entire UI structure
            obj.UI.ToolBar = struct();  % Clear out the ToolBar structure

            obj.AxesHandle.Visible = 'off';
            % ---------------- Show the Main Menu ----------------
            % Make the menu panel visible
            if isfield(obj.Menu, 'MenuPanel') && ishandle(obj.Menu.MenuPanel)
                obj.Menu.MenuPanel.Visible = 'on';
            end

            % Optionally, reset the scene or data to the initial empty state if desired
            obj.Core.Scene.resetEmpty(); % Or reset to default if that fits better

            % Optionally, reset any other settings (e.g., gravity, dt, etc.) to default if desired
            obj.Core.Gravity = [0; -9.81];  % Default gravity (just an example)
            obj.Core.dt = 0.016;  % Default time step (example)
            obj.Core.Paused = false;  % Default paused state (if applicable)
        end


        function openBodyPropertyPanel(obj,mouseX,mouseY)
            if isempty(obj.SelectedBody) || obj.isCurrentlySelecting
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

            % --- layout parameters ---
            yStart = 370; dy = 28; xpad = 10; editX = 100; editW = 100; labelW = 80;
            y = yStart;

            % --- Position ---
            uicontrol(f,'Style','text','String','Position X','Position',[xpad y labelW 20]);
            posXEdit = uicontrol(f,'Style','edit','String',num2str(body.Pos(1)),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setPosX());
            y = y - dy;

            uicontrol(f,'Style','text','String','Position Y','Position',[xpad y labelW 20]);
            posYEdit = uicontrol(f,'Style','edit','String',num2str(body.Pos(2)),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setPosY());
            y = y - dy;

            % --- Velocity ---
            uicontrol(f,'Style','text','String','Velocity X','Position',[xpad y labelW 20]);
            velXEdit = uicontrol(f,'Style','edit','String',num2str(body.Vel(1)),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setVelX());
            y = y - dy;

            uicontrol(f,'Style','text','String','Velocity Y','Position',[xpad y labelW 20]);
            velYEdit = uicontrol(f,'Style','edit','String',num2str(body.Vel(2)),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setVelY());
            y = y - dy;

            % --- Rotation ---
            uicontrol(f,'Style','text','String','Angle','Position',[xpad y labelW 20]);
            angleEdit = uicontrol(f,'Style','edit','String',num2str(body.Angle),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setAngle());
            y = y - dy;

            uicontrol(f,'Style','text','String','Omega','Position',[xpad y labelW 20]);
            omegaEdit = uicontrol(f,'Style','edit','String',num2str(body.Omega),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setOmega());
            y = y - dy;

            % --- Physical properties ---
            uicontrol(f,'Style','text','String','Mass','Position',[xpad y labelW 20]);
            massEdit = uicontrol(f,'Style','edit','String',num2str(body.Mass),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setMass());
            y = y - dy;

            uicontrol(f,'Style','text','String','Fixed','Position',[xpad y labelW 20]);
            fixedCheck = uicontrol(f,'Style','checkbox','Value',body.Fixed,'Position',[editX y 100 20], ...
                'Callback', @(s,e)setFixed());
            y = y - dy;

            uicontrol(f,'Style','text','String','Restitution','Position',[xpad y labelW 20]);
            restitutionEdit = uicontrol(f,'Style','edit','String',num2str(body.Restitution),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setRestitution());
            y = y - dy;

            uicontrol(f,'Style','text','String','Friction (Mu)','Position',[xpad y labelW 20]);
            muEdit = uicontrol(f,'Style','edit','String',num2str(body.Mu),'Position',[editX y editW 20], ...
                'Callback', @(s,e)setMu());
            y = y - dy;

            % --- Shape ---
            uicontrol(f,'Style','text','String','Shape','Position',[xpad y labelW 20]);
            uicontrol(f,'Style','text','String',body.Shape,'Position',[editX y editW 20]);
            y = y - dy;

            if strcmp(body.Shape,'circle')
                uicontrol(f,'Style','text','String','Radius','Position',[xpad y labelW 20]);
                radiusEdit = uicontrol(f,'Style','edit','String',num2str(body.Radius),'Position',[editX y editW 20], ...
                    'Callback', @(s,e)setRadius());
                y = y - dy;
            else
                uicontrol(f,'Style','text','String','Width','Position',[xpad y labelW 20]);
                widthEdit = uicontrol(f,'Style','edit','String',num2str(body.Width),'Position',[editX y editW 20], ...
                    'Callback', @(s,e)setWidth());
                y = y - dy;

                uicontrol(f,'Style','text','String','Height','Position',[xpad y labelW 20]);
                heightEdit = uicontrol(f,'Style','edit','String',num2str(body.Height),'Position',[editX y editW 20], ...
                    'Callback', @(s,e)setHeight());
                y = y - dy;
            end

            % --- Color ---
            uicontrol(f,'Style','text','String','Color','Position',[xpad y labelW 20]);
            bodyColorBtn = uicontrol(f,'Style','pushbutton','BackgroundColor', body.Color, ...
                'Position',[editX y 100 20],'Callback', @(s,e)pickBodyColor());
            y = y - dy;

            % --- Callback functions ---
            function setPosX(), body.Pos(1) = str2double(posXEdit.String); body.updateGraphic(obj.AxesHandle); end
            function setPosY(), body.Pos(2) = str2double(posYEdit.String); body.updateGraphic(obj.AxesHandle); end
            function setVelX(), body.Vel(1) = str2double(velXEdit.String); end
            function setVelY(), body.Vel(2) = str2double(velYEdit.String); end
            function setAngle(), body.Angle = str2double(angleEdit.String); body.updateGraphic(obj.AxesHandle); end
            function setOmega(), body.Omega = str2double(omegaEdit.String); end
            function setMass()
                body.Mass = str2double(massEdit.String);
                if strcmp(body.Shape,'circle')
                    body.Inertia = 0.5 * body.Mass * body.Radius^2;
                else
                    body.Inertia = body.Mass * (body.Width^2 + body.Height^2)/12;
                end
            end
            function setFixed(), body.Fixed = fixedCheck.Value; end
            function setRadius(), body.Radius = str2double(radiusEdit.String); body.Inertia = 0.5 * body.Mass * body.Radius^2; body.updateGraphic(obj.AxesHandle); end
            function setWidth(), body.Width = str2double(widthEdit.String); body.Inertia = body.Mass * (body.Width^2 + body.Height^2)/12; body.updateGraphic(obj.AxesHandle); end
            function setHeight(), body.Height = str2double(heightEdit.String); body.Inertia = body.Mass * (body.Width^2 + body.Height^2)/12; body.updateGraphic(obj.AxesHandle); end
            function setRestitution(), body.Restitution = str2double(restitutionEdit.String); end
            function setMu(), body.Mu = str2double(muEdit.String); end
            function pickBodyColor()
                c = uisetcolor(body.Color);
                if length(c) == 3
                    body.Color = c;
                    body.updateGraphic(obj.AxesHandle);
                    bodyColorBtn.BackgroundColor = c;
                end
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
