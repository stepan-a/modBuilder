function [m, scriptpath] = load(filename, options)
% Build a modBuilder object from a .mod file, without Dynare.
%
% INPUTS:
% - filename     [char]         1×n array, path to a .mod file
%
% OPTIONAL NAME-VALUE ARGUMENTS:
% - Tag          [char]         equation tag carrying the equation/variable association
%                               (default 'name')
% - Script       [char]         path of the MATLAB script to write. Empty, the default,
%                               writes it to a temporary file that is deleted afterwards.
% - Strict       [logical]      scalar, turn the warnings about skipped statements into
%                               errors (default false)
% - Macro        [logical]      scalar, run the macro directives (default true)
% - Defines      [struct]       macro variables to seed, the equivalent of Dynare's -D
% - IncludePaths [cell]         directories searched by @#include
%
% OUTPUTS:
% - m            [modBuilder]   the model
% - scriptpath   [char]         path of the script that built it, empty when it was
%                               written to a temporary file and removed
%
% EXAMPLES:
% m = modfile.load('rbc.mod');
% m = modfile.load('rbc.mod', Script='rbc.m');
%
% REMARKS:
% - The three steps are separately usable: modfile.read parses the file, modfile.translate
%   turns the result into a script, and modfile.build runs it. Going through a script
%   rather than filling the tables directly is deliberate: the script is a readable,
%   editable starting point for the interactive workflow modBuilder is built around.
% - When Script is not given the file is still written to disk, because run() needs a
%   file; it is removed once the model is built.
    arguments
        filename              (1,:) char {mustBeFile}
        options.Tag           (1,:) char = 'name'
        options.Script        (1,:) char = ''
        options.Strict        (1,1) logical = false
        options.Macro         (1,1) logical = true
        options.Defines       struct = struct()
        options.IncludePaths  (1,:) cell = {}
    end

    mod = modfile.read(filename, Strict=options.Strict, Macro=options.Macro, Defines=options.Defines, IncludePaths=options.IncludePaths);
    lines = modfile.translate(mod, Tag=options.Tag);

    if isempty(options.Script)
        scriptpath = [tempname '.m'];
        cleanup = onCleanup(@() local_remove(scriptpath)); %#ok<NASGU>
    else
        scriptpath = options.Script;
        [~, ~, ext] = fileparts(scriptpath);
        if ~strcmp(ext, '.m')
            scriptpath = [scriptpath '.m'];
        end
    end

    fid = fopen(scriptpath, 'w');
    if fid < 0
        error('modfile:load:cannotWrite', 'Cannot open "%s" for writing.', scriptpath)
    end
    closefile = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', lines{:});
    clear closefile

    m = modfile.build(scriptpath);

    if isempty(options.Script)
        scriptpath = '';
    end
end

function local_remove(path)
% Delete the temporary script, staying silent if it was never created.
    if isfile(path)
        delete(path);
    end
end
