classdef bytag
% Tag selector, for modBuilder's curly-brace indexing and for rm and remove.
%
% Creates a selector object that picks equations by their tag values: passed to
% modBuilder's curly-brace indexing it extracts a submodel, passed to rm or remove it
% removes the equations it selects.
%
% EXAMPLES:
% m{bytag('sector', 'manufacturing')}
% m{bytag('sector', 'manuf.*')}
% m{bytag('sector', 'manufacturing', 'type', 'production')}
% m.rm(bytag('sector', 'manufacturing'))

    properties (SetAccess = immutable)
        criteria = struct()   % struct with tagname -> tagvalue (regex) pairs
    end

    methods

        function o = bytag(varargin)
        % Create a tag selector.
        %
        % INPUTS:
        % - varargin   name-value pairs: tagname1, tagvalue1, tagname2, tagvalue2, ...
        %
        % OUTPUTS:
        % - o          [bytag]
        %
        % EXAMPLES:
        % bytag('sector', 'manufacturing')
        % bytag('sector', 'manuf.*', 'type', 'production')
            arguments (Repeating)
                varargin (1,:) char {mustBeNonempty}
            end
            if mod(nargin, 2) ~= 0
                error('bytag:badPair', 'Arguments must be name-value pairs.')
            end
            if nargin > 0
                names = varargin(1:2:end);
                % struct() would silently keep the LAST value of a duplicated tag
                % name and raise a raw MATLAB error on an invalid field name;
                % validate both here so the diagnostics carry bytag identifiers.
                if numel(unique(names)) ~= numel(names)
                    error('bytag:duplicateTag', 'Duplicated tag name in the selector.')
                end
                if ~all(cellfun(@isvarname, names))
                    error('bytag:badTagName', 'Tag names must be valid identifiers.')
                end
                o.criteria = struct(varargin{:});
            end
        end

        function args = toargs(o)
        % Convert criteria to a cell array of name-value pairs.
        %
        % OUTPUTS:
        % - args   [cell]   1×2n cell array: {tagname1, tagvalue1, tagname2, tagvalue2, ...}
            fn = fieldnames(o.criteria);
            fv = struct2cell(o.criteria);
            args = [fn'; fv'];
            args = args(:)';
        end

    end

end
