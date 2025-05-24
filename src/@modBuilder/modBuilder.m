classdef modBuilder<handle

% Class for creating interactively a mod file.

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

    properties
        params = dictionary();             % List of parameters
        varexo = dictionary();             % List of exogenous variables.
        var = dictionary();                % List of endogenous variables.
        symbols = {};                      % List of untyped symbols
        equations = dictionary();          % List of equations.
        T = struct('params', struct(), 'varexo', struct(), 'var', struct(), 'equations', struct());
    end

    properties (SetAccess = immutable)
        date                               % Creation date.
    end

    properties (SetAccess = immutable, Hidden)
        usepipes = false;                  % Not sure we will keep that...
    end

    methods (Access = private)

        function tokens = getsymbols(o, expr)
        % Extract symbols from an expression
        %
        % INPUTS:
        % - o       [modBuilder]
        % - expr    [char]          1×n array, expression
        %
        % OUTPUTS:
        % - tokens  [cell]          1×m array of row char arrays, list of symbols
            tokens = strsplit(expr, {'=', '+','-','*','/','^', '(', ')', ',', '\n', '\t', ' '});
            % Filter out the numbers, punctuation.
            tokens(cellfun(@(x) all(isstrprop(x, 'digit')+isstrprop(x, 'punct')), tokens)) = [];
            % Filter out functions
            tokens(cellfun(@(x) ismember(x, {'log', 'log10', 'ln', 'exp', 'sqrt', 'abs', 'sign', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'min', 'max', 'normcdf', 'normpdf', 'erf', 'diff', 'adl'}), tokens)) = [];
            % Filter out empty elements.
            tokens(cellfun(@(x) all(isempty(x)), tokens)) = [];
            % Remove duplicates
            tokens = unique(tokens);
        end

        function o = updatesymboltable(o, type)
        % Update fields under o.T. These fields map symbols (parameter, endogenous and exogenous variables) with equations.
        %
        % INPUTS:
        % - o       [modBuilder]
        % - type    [char]          1×n array, type of symbol. Possible values are 'parameters', 'exogenous' and 'endogenous'
        %
        % OUTPUTS:
        % - o       [modBuilder]    updated object.
        %
        % REMARKS:
        % - o.T.params.<NAME> is a cell array of row char arrays, each element targets an equation (designated by an endogenous variable) where parameter NAME appears,
        % - o.T.varexo.<NAME> same as o.T.params.<NAME> for exogenous variables,
        % - o.T.var.<NAME> same as o.T.params.<NAME> for endogenous variables.
            switch type
              case 'parameters'
                names = keys(o.params);
                for i=1:length(names)
                    k = keys(o.equations);
                    for j=1:numEntries(o.equations)
                        if any(matches(o.T.equations.(k(j)), names(i)))
                            if isfield(o.T.params, names(i))
                                o.T.params.(names(i)) = horzcat(o.T.params.(names(i)), {k(j)});
                            else
                                o.T.params.(names(i)) = {k(j)};
                            end
                        end
                    end
                end
              case 'exogenous'
                names = keys(o.varexo);
                for i=1:length(names)
                    k = keys(o.equations);
                    for j=1:numEntries(o.equations)
                        if any(matches(o.T.equations.(k(j)), names(i)))
                            if isfield(o.T.params, names(i))
                                o.T.varexo.(names(i)) = horzcat(o.T.varexo.(names(i)), {k(j)});
                            else
                                o.T.varexo.(names(i)) = {k(j)};
                            end
                        end
                    end
                end
              case 'endogenous'
                names = keys(o.var);
                eqidx = keys(o.equations);
                for i=1:length(names)
                    o.T.var.(names(i)) = {names(i)};
                end
                for i=1:length(names)
                    for j=1:length(eqidx)
                        if any(matches(o.T.equations.(eqidx(j)), names(i)))
                            o.T.var.(names(i)) = horzcat(o.T.var.(names(i)), {eqidx(j)});
                        end
                    end
                end
              otherwise
                error('Unknown type (%)', type)
            end
        end

    end


    methods(Static, Access = private)

        function str = printlist(names)
            str = sprintf(' %s', names{:});
            str = sprintf('%s;', str);
        end

    end


    methods

        function o = modBuilder(ontheflydeclarationoftypes)
        % Return an empty modBuilder object
            o.date = datetime;
            if nargin && not(isempty(ontheflydeclarationoftypes)) ...
                    && islogical(ontheflydeclarationoftypes) ...
                    && isscalar(ontheflydeclarationoftypes) ...
                    && ontheflydeclarationoftypes
                o.usepipes = true;
                error('On the fly type declaration is not yet implemented.')
            end
        end

        function o = add(o, varname, equation)
        % Add an equation to the model and associate an endogenous variable
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         1×n array, name of an endogenous variable
        % - equation    [char]         1×m array, expression
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object (with new equation)
            o.equations(varname) = equation;
            o.var(varname) = NaN;
            o.T.equations.(varname) = getsymbols(o, equation);
            o.symbols = horzcat(o.symbols, o.T.equations.(varname));
            o.T.equations.(varname) = setdiff(o.T.equations.(varname), varname);
            o.symbols = setdiff(o.symbols, keys(o.var));
        end

        function o = parameters(o, pname, pvalue)
        % Declare or calibrate a parameter
        %
        % INPUTS:
        % - o         [modBuilder]
        % - pname     [char]         1×n array, name of a parameter
        % - pvalue    [double]       scalar, value of the parameter (default is NaN)
        %
        % OUTPUTS:
        % - o         [modBuilder]   updated object
            if nargin<3
                % Set default value
                pvalue = NaN;
            end
            o.params(pname) = pvalue;
            % Remove pname from the list of untyped symbols
            o.symbols = setdiff(o.symbols, pname);
        end

        function o = exogenous(o, xname, xvalue)
        % Declare or set default value for an exogenous variables
        %
        % INPUTS:
        % - o         [modBuilder]
        % - xname     [char]         1×n array, name of an exogenous variable
        % - xvalue    [double]       scalar, value of the exogenous variable (default is NaN)
        %
        % OUTPUTS:
        % - o         [modBuilder]   updated object
            if nargin<3
                % Set default value
                xvalue = NaN;
            end
            o.varexo(xname) = xvalue;
            % Remove xname from the list of untyped symbols
            o.symbols = setdiff(o.symbols, xname);
        end

        function o = endogenous(o, ename, evalue)
        % Declare or set default value for endogenous variables
        %
        % INPUTS:
        % - o         [modBuilder]
        % - ename     [char]         1×n array, name of an endogenous variable
        % - evalue    [double]       scalar, value of the endogenous variable (default is NaN)
        %
        % OUTPUTS:
        % - o         [modBuilder]   updated object
            if nargin<3
                % Set default value
                evalue = NaN;
            end
            o.varexo(ename) = evalue;
            % Remove ename from the list of untyped symbols
            o.symbols = setdiff(o.symbols, ename);
        end

        function o = remove(o, eqname)
        % Remove an equation from the model, remove one endogenous variable, remove unecessary parameters and exogenous variables
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqname     [char]            1×n array, name of an equation (or endogenous variable associated to an equation)
        %
        % OUTPUTS:
        % - o          [char]            updated object
            equation = o.equations(eqname);
            o.equations(eqname) = [];
            % TODO Update lists of objects
        end

        function write(o, basename)
        % Write model in a mod file.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - basename  [char]         1×n    name of the file, without extension, where the model will be written.
        %
        % OUTPUTS:
        % None
            fid = fopen(sprintf('%s.mod', basename), 'w');
            %
            % Print list of endogenous variables
            %
            names = keys(o.var, 'cell');
            fprintf(fid, 'var%s\n\n', modBuilder.printlist(names));
            %
            % Print list of exogenous variables
            %
            names = keys(o.varexo, 'cell');
            fprintf(fid, 'varexo%s\n\n', modBuilder.printlist(names));
            %
            % Print list of parameters
            %
            names = keys(o.params, 'cell');
            fprintf(fid, 'parameters%s\n\n', modBuilder.printlist(names));
            %
            % Print calibration if any
            %
            for i=1:numEntries(o.params)
                if not(isnan(o.params(names(i))))
                    fprintf(fid, '%s = %f;\n', names{i}, o.params(names(i)));
                end
            end
            fprintf(fid, '\n');
            %
            % Print model block
            %
            names = keys(o.equations, 'cell');
            fprintf(fid, 'model;\n\n');
            for i=1:length(names)
                fprintf(fid, '// Eq. #%u -> %s\n', i, names{i});
                fprintf(fid, '%s;\n\n', o.equations(names{i}));
            end
            fprintf(fid, 'end;\n');
            fclose(fid);
        end

        function o = updatesymboltables(o)
        % Update fields under o.T. These fields map symbols (parameter, endogenous and exogenous variables) with equations.
        % See private method updatesymboltable
            o.updatesymboltable('parameters');
            o.updatesymboltable('exogenous');
            o.updatesymboltable('endogenous');
        end

        function b = isparameter(o, name)
        % Return true iff name is a parameter
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            b = isKey(o.params, name);
        end

        function b = isexogenous(o, name)
        % Return true iff name is an exogenous variable
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            b = isKey(o.varexo, name);
        end

        function b = isendogenous(o, name)
        % Return true iff name is an endogenous variable
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            b = isKey(o.var, name);
        end

        function b = appear_in_more_than_one_equation(o, name)
        % Return true iff a symbol appears in more than one equation.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            if o.isparameter(name)
                b = length(o.T.params.(name))>1;
            elseif o.isexogenous(name)
                b = length(o.T.varexo.(name))>1;
            elseif o.isendogenous(name)
                b = length(o.T.var.(name))>1;
            else
                error('Unknown symbol type.')
            end
        end

        function o = flip_type_endogenous_exogenous(o, varname, varexoname)
        % Flip types of varname (initially an endogenous variable)
        % and varexoname (initially an exogenous variable). After the
        % change, the number of endogenous variables is the same, we
        % do not change the equations.
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]          1×n array, name of the variable to be exogenized
        % - varexo      [char]          1×m array, name of the variable to be endogenized
        %
        % OUTPUTS:
        % - o           [modBuilder]    updated object
            o.var(varexoname) = o.varexo(varexoname);
            o.varexo(varname) = o.var(varname);
            o.var(varname) = [];
            o.varexo(varexoname) = [];
            o.T.var.(varexoname) = o.T.varexo.(varexoname);
            o.T.varexo.(varname) = o.T.var.(varname);
            o.T.varexo = rmfield(o.T.varexo, varexoname);
            o.T.var = rmfield(o.T.var, varname);
            o.equations(varexoname) = o.equations(varname);
            o.equations(varname) = [];
        end

    end


end
