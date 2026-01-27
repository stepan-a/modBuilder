classdef bytag
% Tag selector for use with modBuilder{} indexing.
%
% Creates a selector object that can be passed to modBuilder's
% curly brace indexing to extract a submodel based on tag values.
%
% EXAMPLES:
% m{bytag('sector', 'manufacturing')}
% m{bytag('sector', 'manuf.*')}
% m{bytag('sector', 'manufacturing', 'type', 'production')}

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
            if mod(nargin, 2) ~= 0
                error('Arguments must be name-value pairs.')
            end
            for i = 1:2:nargin
                validateattributes(varargin{i}, {'char'}, {'nonempty', 'row'}, 'bytag', sprintf('tagname (argument %d)', i));
                validateattributes(varargin{i+1}, {'char'}, {'nonempty', 'row'}, 'bytag', sprintf('tagvalue (argument %d)', i+1));
            end
            if nargin > 0
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
