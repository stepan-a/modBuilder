classdef macroarray < macrolist

% An array of the Dynare macro language, as a MATLAB value.

% Copyright © 2026 Dynare Team
%
% This code is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% modBuilder is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <https://www.gnu.org/licenses/>.

% Carrying the kind in the MATLAB type is what lets a script generated from a .mod file
% answer isarray and isreal the way the macro language does. A plain cell could not: an
% array of one real is the same double as the real, and a tuple is the same cell as an
% array holding the same elements.
%
% The operators follow Dynare's preprocessor/src/macro/Expressions.cc: + concatenates,
% - is the set difference, * is the Cartesian product, | is the union and & the
% intersection.

    methods

        function o = macroarray(varargin)
        % Build an array from its elements.
        %
        % INPUTS:
        % - varargin              the elements, one argument each
        %
        % OUTPUTS:
        % - o       [macroarray]
        %
        % EXAMPLES:
        % Countries = macroarray('US', 'EA');
        % length(Countries)             % 2
        % Countries{1}                  % 'US'
        % ismember('EA', Countries)     % true
        %
        % REMARKS:
        % - To build one from a cell array, expand it: macroarray(items{:}).
            o@macrolist(varargin);
        end % function

        function c = plus(a, b)
        % Concatenation, which is what + means on two arrays.
            macroarray.both(a, b, '+');
            items = [cell(a), cell(b)];
            c = macroarray(items{:});
        end % function

        function c = minus(a, b)
        % Set difference, keeping the order of the left operand.
            macroarray.both(a, b, '-');
            items = cell(a);
            items = items(cellfun(@(x) ~ismember(x, b), items));
            c = macroarray(items{:});
        end % function

        function c = or(a, b)
        % Union, keeping the order of first appearance.
            macroarray.both(a, b, '|');
            items = cell(a);
            other = cell(b);
            for i = 1:numel(other)
                if ~ismember(other{i}, macroarray(items{:}))
                    items{end+1} = other{i}; %#ok<AGROW>
                end
            end
            c = macroarray(items{:});
        end % function

        function c = and(a, b)
        % Intersection, keeping the order of the left operand.
            macroarray.both(a, b, '&');
            items = cell(a);
            items = items(cellfun(@(x) ismember(x, b), items));
            c = macroarray(items{:});
        end % function

        function c = mtimes(a, b)
        % Cartesian product, whose elements are tuples.
            macroarray.both(a, b, '*');
            items = {};
            left = cell(a);
            right = cell(b);
            for i = 1:numel(left)
                for j = 1:numel(right)
                    components = [macroarray.parts(left{i}), macroarray.parts(right{j})];
                    items{end+1} = macrotuple(components{:}); %#ok<AGROW>
                end
            end
            c = macroarray(items{:});
        end % function

        function c = times(a, b)
        % Elementwise * is the same product; the macro language has one multiplication.
            c = mtimes(a, b);
        end % function

    end % methods

    methods (Static, Access = private)

        function both(a, b, op)
        % Reject an operand that is not an array.
            if ~isa(a, 'macroarray') || ~isa(b, 'macroarray')
                error('macroarray:badType', 'Operator "%s" applies to two macro arrays.', op)
            end
        end % function

        function items = parts(x)
        % The components a Cartesian product concatenates: a tuple contributes its own.
            if isa(x, 'macrotuple')
                items = cell(x);
            else
                items = {x};
            end
        end % function

    end % methods

end % classdef
