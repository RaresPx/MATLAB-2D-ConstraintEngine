classdef Core < handle
    properties
        FigureHandle
        AxesHandle
        Scene
        Running = true
        dt = 1/60               % fixed timestep (~120Hz)
        Gravity = [0; -9.8]

        DrawInterval = 1/30      % draw at ~30fps
        Paused = false

        % Time
        LastDrawTime
        SimTime double = 0        % accumulated simulation time
        RealTime double = 0       % accumulated real time
        LastStepTime double = 0   % duration of last loop
        StartTime uint64          % tic reference

        % FPS
        FrameCount = 0
        FPS = 0
        LastFPSTime uint64

        %Toolbar update callback
        onTick
    end

    methods
        function obj = Core()
            obj.FigureHandle = figure('Name','2D Constraint Physics Engine','NumberTitle','off',"ToolBar","none","Position",[100 100 1080 720]);
            obj.AxesHandle = axes('Parent',obj.FigureHandle,'Units','normalized','Position',[0.1 0.1 0.65 0.65],'Title','Scene');
            axis(obj.AxesHandle, [-10 10 -10 10]);
            obj.AxesHandle.Visible = 'off';
            hold(obj.AxesHandle,'on');
            disableDefaultInteractivity(obj.AxesHandle);

            obj.Scene = Scene();
            obj.LastDrawTime = tic;
            obj.StartTime = tic;
            obj.LastFPSTime = tic;

        end

        function initDefaultScene(obj)
            obj.Scene.setupDefaultScene();
        end

        function run(obj)
            while obj.Running && isvalid(obj.FigureHandle)
                loopTic = tic;

                % ---- Simulation step ----
                if ~obj.Paused
                    obj.Scene.step(obj.dt, obj.Gravity);
                    obj.SimTime = obj.SimTime + obj.dt;
                end

                % ---- Rendering ----
                if toc(obj.LastDrawTime) >= obj.DrawInterval
                    obj.Scene.updateGraphics(obj.AxesHandle);
                    obj.onTick();
                    drawnow limitrate;

                    % FPS tracking
                    obj.FrameCount = obj.FrameCount + 1;
                    t = toc(obj.LastFPSTime);
                    if t >= 0.5
                        obj.FPS = obj.FrameCount / t;
                        obj.FrameCount = 0;
                        obj.LastFPSTime = tic;
                    end

                    obj.LastDrawTime = tic;
                end

                % ---- Timing bookkeeping ----
                obj.LastStepTime = toc(loopTic);
                obj.RealTime = toc(obj.StartTime);

                % ---- Sleep to match dt ----
                pause(max(0, obj.dt - obj.LastStepTime));
            end
        end

    end
end
