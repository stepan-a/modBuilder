function path = resolve_include(target, includer, includepaths)
% Locate the file named by an @#include directive.
%
% INPUTS:
% - target         [char]   1×n array, the name as written in the directive
% - includer       [char]   1×m array, path of the file containing the directive
% - includepaths   [cell]   1×p array, directories accumulated by @#includepath, in
%                           declaration order
%
% OUTPUTS:
% - path           [char]   1×q array, the resolved path
%
% REMARKS:
% - Search order, first hit wins: the directory of the including file, then each
%   @#includepath directory in the order they were declared, then the current directory.
% - Not finding the file lists the directories that were searched, because the usual
%   cause is a missing @#includepath rather than a mistyped name.
    arguments
        target       (1,:) char
        includer     (1,:) char
        includepaths (1,:) cell = {}
    end

    if isfile(target) && (target(1) == filesep || contains(target, filesep))
        path = target;
        return
    end

    searched = [{fileparts(includer)}, includepaths, {pwd}];
    for i = 1:numel(searched)
        candidate = fullfile(searched{i}, target);
        if isfile(candidate)
            path = candidate;
            return
        end
    end

    described = searched;
    described{1} = local_describe(described{1});
    error('modfile:resolve_include:includeNotFound', 'Cannot find the included file "%s". Searched in: %s.', target, strjoin(described, ', '))
end

function s = local_describe(directory)
% Name an empty directory component, which is what fileparts returns for a bare filename.
    if isempty(directory)
        s = '.';
    else
        s = directory;
    end
end
