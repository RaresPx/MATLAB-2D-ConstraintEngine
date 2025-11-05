classdef Core < handle
    properties
        FigureHandle
        AxesHandle
        Scene
        Running = true
        dt = 1/60               % fixed timestep (~120Hz)
        Gravity = [0; -9.8]
        LastDrawTime
        DrawInterval = 1/30      % draw at ~30fps
    end

    methods
        function obj = Core()
            obj.FigureHandle = figure('Name','2D Physics Engine','NumberTitle','off', ...
                'WindowKeyPressFcn', @(src,evt)obj.keyHandler(evt));
            obj.AxesHandle = axes('Parent',obj.FigureHandle);
            axis(obj.AxesHandle, [-10 10 -10 10]);
            hold(obj.AxesHandle,'on');
            obj.AxesHandle.XLimMode = 'manual';
            obj.AxesHandle.YLimMode = 'manual';

            obj.Scene = Scene();
            Editor(obj,obj.Scene, obj.AxesHandle);

            drawnow;
            obj.LastDrawTime = tic;
        end

        function initDefaultScene(obj)
            obj.Scene.setupDefaultScene();
        end

        function run(obj)
            while obj.Running && isvalid(obj.FigureHandle)
                t0 = tic;

                % --- Scene Step ---
                obj.Scene.step(obj.dt,obj.Gravity);

                % --- Rendering check ---
                if toc(obj.LastDrawTime) >= obj.DrawInterval
                    obj.Scene.updateGraphics(obj.AxesHandle);
                    drawnow limitrate;            % use limitrate, no nocallbacks => callbacks are allowed
                    obj.LastDrawTime = tic;
                end

                % --- regulate loop speed ---
                pause(max(0, obj.dt - toc(t0)));
            end
        end

        function keyHandler(obj, evt)
            if strcmp(evt.Key, 'escape')
                obj.Running = false;
                if isvalid(obj.FigureHandle)
                    close(obj.FigureHandle);
                end
            end
        end
    end
end
