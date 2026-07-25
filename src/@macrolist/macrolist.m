classdef macrolist

% Base class for the ordered values of the Dynare macro language.

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

% The macro language distinguishes an array from a tuple, and both from a scalar. MATLAB
% natives cannot: a one-element array of reals is the same double as the real itself, and
% a tuple is the same cell as an array of the same elements. A script generated from a
% .mod file has to keep those apart, or istuple and isreal would answer wrongly on values
% the macro language treats as different.
%
% macroarray and macrotuple therefore carry the kind in the MATLAB type, so that isarray
% and istuple become plain isa tests. This class holds what the two share; only the
% operations that are defined on arrays live in macroarray.
%
% The elements are MATLAB natives: doubles, logicals, char arrays, or nested lists.

    properties (SetAccess = immutable)
        % Elements, as a 1×n cell array.
        items
    end

    methods

        function o = macrolist(items)
        % Build a list from a cell array of elements.
        %
        % INPUTS:
        % - items   [cell]        1×n array of elements (default empty)
        %
        % OUTPUTS:
        % - o       [macrolist]
        %
        % REMARKS:
        % - The base takes a cell, since it is only ever called from a subclass
        %   constructor. The subclasses take the elements one argument each, which is how
        %   a generated script writes them.
            arguments
                items (1,:) cell = {}
            end
            o.items = items;
        end % function

        function n = length(o)
        % Number of elements, which is what the macro length() returns.
            n = numel(o.items);
        end % function

        function tf = isempty(o)
        % True when the list holds nothing.
            tf = isempty(o.items);
        end % function

        function c = cell(o)
        % The elements as a plain cell array.
            c = o.items;
        end % function

        function varargout = subsref(o, s)
        % Index the list: o{i} gives an element, o(i) a list of the selected ones.
        %
        % A range gives back a list rather than its contents, matching what the macro
        % language does with A[1:2].
            switch s(1).type
              case '{}'
                idx = s(1).subs{1};
                if isscalar(idx)
                    out = o.items{idx};
                else
                    out = feval(class(o), o.items{idx});
                end
              case '()'
                out = feval(class(o), o.items{s(1).subs{1}});
              otherwise
                [varargout{1:nargout}] = builtin('subsref', o, s);
                return
            end

            if isscalar(s)
                varargout{1} = out;
            else
                [varargout{1:nargout}] = subsref(out, s(2:end));
            end
        end % function

        function n = end(o, ~, ~)
        % Support o{end}.
            n = numel(o.items);
        end % function

        function tf = eq(a, b)
        % Structural equality: same class, same length, same elements in the same order.
            tf = false;
            if ~isa(a, 'macrolist') || ~isa(b, 'macrolist') || ~strcmp(class(a), class(b))
                return
            end
            if length(a) ~= length(b)
                return
            end
            for i = 1:length(a)
                if ~macrolist.same(a.items{i}, b.items{i})
                    return
                end
            end
            tf = true;
        end % function

        function tf = ne(a, b)
        % Negation of eq.
            tf = ~eq(a, b);
        end % function

        function tf = ismember(x, o)
        % Membership of an element, which is what the macro "in" operator asks.
            tf = false;
            if ~isa(o, 'macrolist')
                return
            end
            for i = 1:numel(o.items)
                if macrolist.same(o.items{i}, x)
                    tf = true;
                    return
                end
            end
        end % function

        function s = sum(o)
        % Sum of the elements, which must all be numbers.
            s = 0;
            for i = 1:numel(o.items)
                if ~isnumeric(o.items{i})
                    error('macrolist:sum:badType', 'sum() applies to numbers only.')
                end
                s = s + o.items{i};
            end
        end % function

        function disp(o)
        % Print the list the way the macro language writes it.
            fprintf('%s\n', string(o));
        end % function

        function str = string(o)
        % Render the list as text, in the macro language's own notation.
            parts = cellfun(@macrolist.render, o.items, 'UniformOutput', false);
            if isa(o, 'macrotuple')
                str = sprintf('(%s)', strjoin(parts, ', '));
            else
                str = sprintf('[%s]', strjoin(parts, ', '));
            end
        end % function

    end % methods

    methods (Static)

        function tf = same(a, b)
        % Equality of two elements, whatever they are.
            if isa(a, 'macrolist') || isa(b, 'macrolist')
                tf = isa(a, 'macrolist') && isa(b, 'macrolist') && eq(a, b);
            elseif ischar(a) || ischar(b)
                tf = ischar(a) && ischar(b) && strcmp(a, b);
            elseif islogical(a) || islogical(b)
                tf = islogical(a) && islogical(b) && a == b;
            else
                tf = isequal(a, b);
            end
        end % function

        function str = render(x)
        % Render one element as text.
            if isa(x, 'macrolist')
                str = string(x);
            elseif ischar(x)
                str = x;
            elseif islogical(x)
                if x
                    str = 'true';
                else
                    str = 'false';
                end
            elseif x == fix(x) && abs(x) < 1e15
                str = sprintf('%d', x);
            else
                str = sprintf('%.15g', x);
            end
        end % function

    end % methods

end % classdef
