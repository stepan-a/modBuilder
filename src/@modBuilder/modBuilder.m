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
        params = cell(0,2);             % List of parameters
        varexo = cell(0,2);             % List of exogenous variables.
        var = cell(0,2);                % List of endogenous variables.
        symbols = {};                   % List of untyped symbols
        equations = cell(0,2);          % List of equations.
        T = struct('params', struct(), 'varexo', struct(), 'var', struct(), 'equations', struct());
    end

    properties (SetAccess = immutable)
        date                               % Creation date.
    end


    methods (Access = private)

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
                for i=1:o.size(type)
                    for j=1:o.size('endogenous') % The number of endogenous variables is equal to the number of equations by construction.
                        if any(matches(o.T.equations.(o.equations{j,1}), o.params{i,1}))
                            if isfield(o.T.params, o.params{i,1})
                                o.T.params.(o.params{i,1}) = horzcat(o.T.params.(o.params{i,1}), o.equations(j,1));
                            else
                                o.T.params.(o.params{i,1}) = o.equations(j,1);
                            end
                        end
                    end
                end
              case 'exogenous'
                for i=1:o.size(type)
                    for j=1:o.size('endogenous')
                        if any(matches(o.T.equations.(o.equations{j,1}), o.varexo{i,1}))
                            if isfield(o.T.varexo, o.varexo{i,1})
                                o.T.varexo.(o.varexo{i,1}) = horzcat(o.T.varexo.(o.varexo{i,1}), o.equations(j,1));
                            else
                                o.T.varexo.(o.varexo{i,1}) = o.equations(j,1);
                            end
                        end
                    end
                end
              case 'endogenous'
                for i=1:o.size(type)
                    o.T.var.(o.var{i,1}) = o.var(i,1);
                end
                for i=1:o.size(type)
                    for j=1:o.size(type)
                        if any(matches (o.T.equations.(o.var{j,1}), o.var{i,1}))
                            o.T.var.(o.var{i,1}) = horzcat(o.T.var.(o.var{i,1}), o.var(j,1));
                        end
                    end
                end
              otherwise
                error('Unknown type (%)', type)
            end % switch
        end % function

    end % methods


    methods(Static, Access = private)

        function str = printlist(names)
            str = sprintf(' %s', names{:});
            str = sprintf('%s;', str);
        end

        function tokens = getsymbols(expr)
        % Extract symbols from an expression
        %
        % INPUTS:
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
        end % function

    end % methods

    methods(Static)

        function o = loadobj(s)
        % Deserialize a modBuilder object reprsented by structure s.
        %
        % INPUTS:
        % s    [struct]
        %
        % OUTPUTS:
        % - o  [modBuilder]
            if isstruct(s)
                if isfield(s, 'params') && isfield(s, 'varexo') && isfield(s, 'var') ...
                        && isfield(s, 'symbols') && isfield(s, 'equations') && isfield(s, 'T') ...
                        && isfield(s, 'date')
                    o = modBuilder(s.date);
                    o.T = s.T;
                    o.var = s.var;
                    o.params = s.params;
                    o.varexo = s.varexo;
                    o.symbols = s.symbols;
                    o.equations = o.equations;
                else
                    error('Cannot instantiate a modBuilder object (missing fields).')
                end
            else
                o = s;
            end
        end

    end % methods


    methods

        function o = modBuilder(date)
        % Return an empty modBuilder object
            if nargin && isdatetime(date)
                o.date = date;
            else
                o.date = datetime;
            end
        end

        function  n = size(o, type)
        % Return the number of parameters, endogenous or exogenous variables.
        %
        % INPUTS:
        %  - o      [modBuilder]
        % - type    [char]           1×n array, type of symbol ('parameters', 'exogenous' or 'endogenous')
        %
        % OUTPUTS:
        % - n    [integer]    scalar, number of symbols.
                switch type
                  case 'parameters'
                    n = size(o.params, 1);
                  case 'exogenous'
                    n = size(o.varexo, 1);
                  case 'endogenous'
                    n = size(o.var, 1);
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
            id = size(o.equations, 1)+1;
            o.equations{id,1} = varname;
            o.equations{id,2} = equation;
            o.var{id,1} = varname;
            o.var{id,2} = NaN;
            o.T.equations.(varname) = modBuilder.getsymbols(equation);
            o.symbols = horzcat(o.symbols, o.T.equations.(varname));
            o.T.equations.(varname) = setdiff(o.T.equations.(varname), varname);
            o.symbols = setdiff(o.symbols, o.var(:,1));
        end % function

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
            idp = ismember(o.params(:,1), pname);
            if any(idp) % The parameter is already defined
                o.params{idp, 2} = pvalue;
            else
                o.params{length(idp)+1, 1} = pname;
                o.params{length(idp)+1, 2} = pvalue;
            end
            % Remove pname from the list of untyped symbols
            o.symbols = setdiff(o.symbols, pname);
        end % function

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
            idx = ismember(o.varexo(:,1), xname);
            if any(idx) % The parameter is already defined
                o.varexo{idx, 2} = xvalue;
            else
                o.varexo{length(idx)+1, 1} = xname;
                o.varexo{length(idx)+1, 2} = xvalue;
            end
            % Remove xname from the list of untyped symbols
            o.symbols = setdiff(o.symbols, xname);
        end % function

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
            ide = ismember(o.var(:,1), ename);
            if any(ide) % The parameter is already defined
                o.var{ide, 2} = evalue;
            else
                o.var{length(ide)+1, 1} = ename;
                o.var{length(ide)+1, 2} = evalue;
            end
            % Remove ename from the list of untyped symbols
            o.symbols = setdiff(o.symbols, ename);
        end % function

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
        end % function

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
            fprintf(fid, 'var%s\n\n', modBuilder.printlist(o.var(:,1)));
            %
            % Print list of exogenous variables
            %
            fprintf(fid, 'varexo%s\n\n', modBuilder.printlist(o.varexo(:,1)));
            %
            % Print list of fprintf
            %
            fprintf(fid, 'parameters%s\n\n', modBuilder.printlist(o.params(:,1)));
            %
            % Print calibration if any
            %
            for i=1:o.size('parameters')
                if not(isnan(o.params{i,2}))
                    fprintf(fid, '%s = %f;\n', o.params{i,1}, o.params{i,2});
                end
            end
            fprintf(fid, '\n');
            %
            % Print model block
            %
            fprintf(fid, 'model;\n\n');
            for i=1:o.size('endogenous')
                fprintf(fid, '// Eq. #%u -> %s\n', i, o.equations{i,1});
                fprintf(fid, '%s;\n\n', o.equations{i,2});
            end
            fprintf(fid, 'end;\n');
            fclose(fid);
        end % function

        function s = saveobj(o)
        % Serialize a modBuilder object, used when saving object to mat file.
        %
        % INPUTS:
        % - o      [modBuilder]
        %
        % OUTPUTS:
        % - s      [struct]        One field for each member of the modBuilder class.
            s.params = o.params;
            s.varexo = o.varexo;
            s.var = o.var;
            s.symbols = o.symbols;
            s.equations = o.equations;
            s.T = o.T;
            s.date = o.date;
        end

        function o = updatesymboltables(o)
        % Update fields under o.T. These fields map symbols (parameter, endogenous and exogenous variables) with equations.
        % See private method updatesymboltable
            o.updatesymboltable('parameters');
            o.updatesymboltable('exogenous');
            o.updatesymboltable('endogenous');
        end % function

        function b = isparameter(o, name)
        % Return true iff name is a parameter
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            b = any(ismember(o.params(:,1), name));
        end % function

        function b = isexogenous(o, name)
        % Return true iff name is an exogenous variable
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            b = any(ismember(o.varexo(:,1), name));
        end % function

        function b = isendogenous(o, name)
        % Return true iff name is an endogenous variable
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            b = any(ismember(o.var(:,1), name));
        end % function

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
        end % function

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
            ie = ismember(o.var(:,1), varname);
            if not(any(ie))
                error('%s is not a known endogenous variable.', varname)
            end
            ix = ismember(o.varexo(:,1), varexoname);
            if not(any(ix))
                error('%s is not a known exogenous variable.', varexoname)
            end
            % Copy variables
            o.var = [o.var; {varexoname o.varexo{ix,2}}];
            o.varexo = [o.varexo; {varname o.var{ie,2}}];
            % Remove variables
            o.var(ie,:) = [];
            o.varexo(ix,:) = [];
            % Update stmbol tables
            o.T.var.(varexoname) = o.T.varexo.(varexoname);
            o.T.varexo.(varname) = o.T.var.(varname);
            o.T.varexo = rmfield(o.T.varexo, varexoname);
            o.T.var = rmfield(o.T.var, varname);
            % Associate new endogenous variable to an equation (the one previously associated with varname)
            o.equations{ie,1} = varexoname;
        end % function

    end % methods


end % classdef
