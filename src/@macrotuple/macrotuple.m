classdef macrotuple < macrolist

% A tuple of the Dynare macro language, as a MATLAB value.

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

% A tuple holds an ordered, fixed group of values. It is the element type a Cartesian
% product of arrays produces, and what a @#for over several indices destructures.
%
% It is a class of its own rather than an array so that istuple and isarray can tell
% them apart in a generated script; the two would be the same cell otherwise. None of the
% array operators apply to it.

    methods

        function o = macrotuple(varargin)
        % Build a tuple from its elements.
        %
        % INPUTS:
        % - varargin              the elements, one argument each
        %
        % OUTPUTS:
        % - o       [macrotuple]
        %
        % EXAMPLES:
        % Pair = macrotuple(1, 'a');
        % Pair{1}          % 1
        % length(Pair)     % 2
        %
        % REMARKS:
        % - To build one from a cell array, expand it: macrotuple(items{:}).
            o@macrolist(varargin);
        end % function

    end % methods

end % classdef
