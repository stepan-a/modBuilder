function m = build(scriptpath)
% Run a generated modBuilder script and return the model it builds.
%
% INPUTS:
% - scriptpath   [char]         1×n array, path to a script emitted by modfile.translate
%
% OUTPUTS:
% - m            [modBuilder]   the model the script builds
%
% REMARKS:
% - run() evaluates the script in this function's workspace, so the object the script
%   assigns to 'm' becomes a local here and is returned. Keeping that in its own
%   function isolates the script's variables, in particular the calibration locals it
%   defines, from every caller.
% - The script is expected to assign a variable named 'm'; modfile.translate emits that
%   name by default. A script that does not is reported rather than left to fail on an
%   undefined-variable error further up.
    arguments
        scriptpath (1,:) char {mustBeFile}
    end

    run(scriptpath);

    if ~exist('m', 'var') || ~isa(m, 'modBuilder')
        error('modfile:build:noModel', '%s did not assign a modBuilder object to the variable "m".', scriptpath)
    end
end
