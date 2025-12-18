classdef ConstraintEngine < handle
    %CONSTRAINTENGINE - Lightweight wrapper managing core and editor
    %   OBJ = CONSTRAINTENGINE() constructs the engine, creating the Core
    %   and later instantiating an Editor to run the application.
    properties
        Core
        editor
    end
    methods
        function obj = ConstraintEngine()
            %inititate the engine
            obj.Core = Core();
            %obj.Core.initDefaultScene();
        end
        function run(obj)
            %Create the app
            obj.editor = Editor(obj.Core, obj.Core.Scene, obj.Core.AxesHandle);
        end
    end
end