function in(varargin)

% Command line interface for modBuilder objects

% Copyright © 2025 Dynare Team
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


    vars = evalin('caller', 'who');
    if ismember(varargin{1}, vars)
        model = evalin('caller', varargin{1});
    else
        error('Cannot find %s', varargin{1})
    end

    if ~isa(model, 'modBuilder')
        error('%s has to be a modBuilder object.', varargin{1})
    end

    %
    % Interface for add
    %

    FirstArgument = regexp(varargin{2}, 'add\((\w+)\)', 'tokens');

    if ~isempty(FirstArgument)
        endogenous = FirstArgument{1}{1};
        if nargin>3
            expression = [varargin{3:end}];
        else
            error('Equation for %s is missing.', endogenous)
        end
        model.add(endogenous, expression);
        return
    end

    %
    % Interface for parameter, exogenous and endogenous
    %

    FirstArgument = varargin{2};

    if isequal(FirstArgument, 'set')

        SecondArgument = regexp(varargin{3}, 'parameter\((\w+)\)', 'tokens');

        if ~isempty(SecondArgument)
            parameter = SecondArgument{1}{1};
            if nargin==4
                value = str2double(varargin{4});
                if isnan(value)
                    error('Parameter %s has to be calibrated with a number.', parameter)
                else
                    model.parameter(parameter, value);
                end
            end
            return
        end

        SecondArgument = regexp(varargin{3}, 'exogenous\((\w+)\)', 'tokens');

        if ~isempty(SecondArgument)
            exogenous = SecondArgument{1}{1};
            if nargin==4
                value = str2double(varargin{4});
                if isnan(value)
                    error('Exogenous variable %s has to be calibrated with a number.', parameter)
                else
                    model.exogenous(exogenous, value);
                end
            end
            return
        end

        SecondArgument = regexp(varargin{3}, 'endogenous\((\w+)\)', 'tokens');

        if ~isempty(SecondArgument)
            endogenous = SecondArgument{1}{1};
            if nargin==4
                value = str2double(varargin{4});
                if isnan(value)
                    error('Endogenous variable %s has to be calibrated with a number.', parameter)
                else
                    model.endogenous(exogenous, value);
                end
            end
            return
        end

    end

end
