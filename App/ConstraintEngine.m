classdef ConstraintEngine < handle
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