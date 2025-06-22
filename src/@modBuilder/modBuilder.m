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

        function S = shiftS(S,n)
        % Removes the first n elements of a one dimensional cell array.
            if length(S) >= n+1
                S = S(n+1:end);
            else
                S = {};
            end
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
                    o.equations = s.equations;
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
        % - type    [char]           1×n array, type of symbol ('equations', 'parameters', 'exogenous' or 'endogenous')
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
                  case 'equations'
                    n = size(o.equations, 1);
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
            if any(ismember(o.equations(:,1), varname))
                error('Variable %s already has an equation. Use the change method if you really want to redefine the equation for %s. ', varname, varname)
            end
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

        function o = parameter(o, pname, pvalue)
        % Declare or calibrate a parameter
        %
        % INPUTS:
        % - o         [modBuilder]
        % - pname     [char]         1×n array, name of a parameter
        % - pvalue    [double]       scalar, value of the parameter (default is NaN)
        %
        % OUTPUTS:
        % - o         [modBuilder]   updated object
        %
        % REMARKS:
        % If symbol pname is known as an exogenous variable, it is converted to a parameter. If pvalue is not NaN, pname is set
        % equal to pvalue, otherwise the parameter is calibrated with the value of the exogeous variable.
            if nargin<3
                % Set default value
                pvalue = NaN;
            end
            idp = ismember(o.params(:,1), pname);
            if any(idp) % The parameter is already defined
                o.params{idp, 2} = pvalue;
            else
                idx = ismember(o.varexo(:,1), pname);
                if any(idx)
                    % pname is an exogenous variable, we change its type to parameter.
                    o.params(length(idp)+1,:) = o.varexo(idx,:);
                    o.varexo(idx,:) = [];
                    if not(isnan(pvalue))
                        o.params{length(idp)+1,2} = pvalue;
                    end
                else
                    % Symbol pname has no predefined type.
                    o.params{length(idp)+1, 1} = pname;
                    o.params{length(idp)+1, 2} = pvalue;
                end
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
        %
        % REMARKS:
        % If symbol xname is known as a parameter, it is converted to an exogenous variable. If xvalue is not NaN, xname is set
        % equal to xvalue, otherwise the exogenous variable is calibrated with the value of the parameter.
            if nargin<3
                % Set default value
                xvalue = NaN;
            end
            idx = ismember(o.varexo(:,1), xname);
            if any(idx) % The parameter is already defined
                o.varexo{idx, 2} = xvalue;
            else
                idp = ismember(o.params(:,1), xname);
                if any(idp)
                    % pname is a parameter, we change its type to exogenous variable.
                    o.varexo(length(idx)+1,:) = o.params(idp,:);
                    o.params(idp,:) = [];
                    if not(isnan(xvalue))
                        o.varexo{length(idx)+1,2} = xvalue;
                    end
                else
                    o.varexo{length(idx)+1, 1} = xname;
                    o.varexo{length(idx)+1, 2} = xvalue;
                end
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

        function o = check(o)
        % Performs various checks on the model and update the symbol table.
        %
        % INPUTS:
        % - o      [modBuilder]
        %
        % OUTPUTS:
        % - o      [modBuilder]
            warning('off','backtrace')
            o.updatesymboltables;
            if not(isempty(o.symbols))
                warning('Some symbols are still untyped:%s', modBuilder.printlist(o.symbols))
            end
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
            ide = ismember(o.equations(:,1), eqname);
            if not(any(ide))
                error('Unknown equation (%s).', eqname)
            end
            o.equations(ide,:) = [];
            for i=1:length(o.T.equations.(eqname))
                [type, id] = o.typeof(o.T.equations.(eqname){i});
                if not(o.appear_in_more_than_one_equation(o.T.equations.(eqname){i}))
                    % The symbol does not appear in other equations, we can safely remove it
                    switch type
                      case 'parameter'
                        o.params(id,:) = [];
                      case 'exogenous'
                        o.varexo(id,:) = [];
                      case 'endogenous'
                        o.var(id,:) = [];
                      otherwise
                        % We should not attain this part of the code.
                    end % switch
                end % if
            end
            o.T.equations = rmfield(o.T.equations, eqname);
            o.T.var.(eqname) = setdiff(o.T.var.(eqname), eqname); % Remove reference to the equation defining eqname.
            if not(isempty(o.T.var.(eqname)))
                % If the variable eqname is referenced in another equation, it must be converted to an exogenous variable.
                o.varexo = [o.varexo; o.var(ismember(o.var(:,1), eqname),:)];
                o.T.varexo.(eqname) = o.T.var.(eqname);
                o.T.var = rmfield(o.T.var, eqname);
            end
            o.var(ismember(o.var(:,1), eqname),:) = [];
            o.updatesymboltables();
        end % function

        function o = rm(o, varargin)
        % Remove equations from the model.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqname1    [char]            1×n array, name of an equation (or endogenous variable associated to an equation)
        % - eqname2    [char]            1×m array, name of an equation (or endogenous variable associated to an equation)
        % - …
        %
        % OUTPUTS:
        % - o          [char]            updated object
            if not(all(cellfun(@(x) ischar(x) && isrow(x), varargin)))
                error('All input arguments must be row char arrays (equation names).')
            end
            eqnames = unique(varargin);
            for i=1:length(eqnames)
                o.remove(eqnames{i});
            end
        end

        function o = write(o, basename)
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
            o.T.params = struct();
            o.T.varexo = struct();
            o.T.var = struct();
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

        function [type, id] = typeof(o, name)
        % Return the type of a symbol.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - name     [char]            1×n array, name of a symbol
        %
        % OUTPUTS:
        % - type     [char]            1×m array, type of the symbol
        % - id       [logical]         p×1 array with only one true element, targeting the symbol in o.{params,varexo,var}
            id = ismember(o.params(:,1), name);
            if any(id)
                type = 'parameter';
                return
            end
            id = ismember(o.varexo(:,1), name);
            if any(id)
                type = 'exogenous';
                return
            end
            id = ismember(o.var(:,1), name);
            if any(id)
                type = 'endogenous';
                return
            end
            error('Unknown type for symbol %s.', name);
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
        end % function

        function o = flip(o, varname, varexoname)
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
            % Update symbol tables
            o.T.var.(varexoname) = o.T.varexo.(varexoname);
            o.T.varexo.(varname) = o.T.var.(varname);
            o.T.varexo = rmfield(o.T.varexo, varexoname);
            o.T.var = rmfield(o.T.var, varname);
            % Associate new endogenous variable to an equation (the one previously associated with varname)
            o.equations{ie,1} = varexoname;
        end % function

        function p = copy(o)
        % Deep copy of an object
        %
        % INPUTS:
        % - o   [modBuilder]
        %
        % OUTPUTS:
        % - p   [modBuilder]
            p = modBuilder(o.date);
            p.params = o.params;
            p.varexo = o.varexo;
            p.var = o.var;
            p.symbols = o.symbols;
            p.equations = o.equations;
            p.T = o.T;
        end

        function b = eq(o, p)
        % Overload eq method.
        %
        % INPUTS:
        % - o   [modBuilder]
        % - p   [modBuilder]
        %
        % OUTPUTS:
        % - b   [logical]      scalar, true iff objects o and p are identical.
            if ~isa(o, 'modBuilder') || ~isa(p, 'modBuilder')
                error('Cannot compare modBuilder object with an object from another class.')
            end
            b = true;
            if not(isequal(o.params, p.params))
                b = false;
                return
            end
            if not(isequal(o.varexo, p.varexo))
                b = false;
                return
            end
            if not(isequal(o.var, p.var))
                b = false;
                return
            end
            if not(isequal(o.symbols, p.symbols))
                b = false;
                return
            end
            if not(isequal(o.equations, p.equations))
                b = false;
                return
            end
            if not(isequal(o.T, p.T))
                b = false;
                return
            end
        end

        function o = change(o, varname, equation)
        % Change an equation in the model
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         1×n array, name of an endogenous variable
        % - equation    [char]         1×m array, expression (new equation)
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object (with new equation)
            warning('off','backtrace')
            ide = ismember(o.equations(:,1), varname);
            if not(any(ide))
                error('There is no equation for %s.', varname)
            end
            o.equations{ide,2} = equation;
            otokens = o.T.equations.(varname);
            ntokens = setdiff(modBuilder.getsymbols(equation), varname);
            o.symbols = [o.symbols, ntokens];
            % Remove symbols that are already known. If o.symbols is empty, it indicates that the updated equation introduces no
            % new symbols. Otherwise, a warning is issued, and the user is expected to provide types for the new symbols.
            o.symbols = setdiff(o.symbols, [o.params(:,1); o.varexo(:,1); o.var(:,1)]);
            if not(isempty(o.symbols))
                % TODO: should remaining symbols be declared as exogenous variables by default?
                warning('Untyped symbol(s):%s.', sprintf(' %s', o.symbols{:}))
            end
            % Do we need to remove some symbols (parameters or exogenous variables)?
            list_of_symbols_potentially_to_be_removed = setdiff(otokens, ntokens);
            for i=1:length(list_of_symbols_potentially_to_be_removed)
                if not(o.appear_in_more_than_one_equation(list_of_symbols_potentially_to_be_removed{i}))
                    % Remove parameter/variable if it does not appear in another equation.
                    [type, id] = o.typeof(list_of_symbols_potentially_to_be_removed{i});
                    switch type
                      case 'parameter'
                        o.params(id,:) = [];
                        o.T.params = rmfield(o.T.params, list_of_symbols_potentially_to_be_removed{i});
                      case 'exogenous'
                        o.varexo(id,:) = [];
                        o.T.varexo = rmfield(o.T.varexo, list_of_symbols_potentially_to_be_removed{i});
                      otherwise
                        % Nothing to be done here.
                    end
                end
            end
            o.T.equations.(varname) = ntokens;
        end

        function p = extract(o, varargin)
        % Extract equations from a model a return a new modBuilder object.
        %
        % INPUTS:
        % - o      [modBuilder]
        % - ...    [char]          row arrays, equation names to be extracted from o
        %
        % OUTPUTS:
        % - p      [modBuilder]
        %
        % REMARKS:
        % The number of equations in p is equal to the number of arguments passed to the extract method.
            p = copy(o);
            if not(all(ismember(varargin, p.equations(:,1))))
                error('Equation(s) missing for:%s.', modBuilder.printlist(varargin(~ismember(varargin, p.equations(:,1)))))
            end
            eqnames = setdiff(p.equations(:,1), varargin);
            p.rm(eqnames{:});
        end

        function p = subsref(o, S)
        % Overlaod subsref method
            if length(S)>1
                if isequal(S(1).type, '()')
                    % Extract a subset of equations and apply methods to the extracted model or display properties.
                    if isequal(S(2).type, '.') && length(S)==2
                        p = o.extract(S(1).subs{:});
                        p = p.(S(2).subs);
                    else
                        p = o.extract(S(1).subs{:});
                        S = modBuilder.shiftS(S, 1);
                        if length(S)>1
                            p = builtin('subsref', p, S);
                        end
                    end
                else
                    p = builtin('subsref', o, S);
                end
            else
                if isequal(S(1).type, '()')
                    % Extract subset of equations.
                    p = o.extract(S(1).subs{:});
                else
                    p = builtin('subsref', o, S);
                end
            end
        end % function

        function o = subsasgn(o,S,B)
        % Overload subsasgn method
            if length(S)>1
                error('Wrong assignment.')
            end
            if isequal(S(1).type, '()')
                if ischar(S(1).subs{1})
                    try
                        [type, id] = typeof(o, S(1).subs{1});
                    catch
                        % Character array S(1).subs{1} is neither a parameter name, endogenous or
                        % exogenous variable name.
                        error('Wrong index (unknwow symbol).')
                    end
                    switch type
                      case 'parameter'
                        if isnumeric(B) && isscalar(B) && isreal(B)
                            % Change parameter value.
                            o.params{id,2} = B;
                        else
                            error('Can only assign a real scalar number to a parameter.')
                        end
                      case 'exogenous'
                        if isnumeric(B) && isscalar(B) && isreal(B)
                            % Change exogenous variable value.
                            o.varexo{id,2} = B;
                        else
                            error('Can only assign a real scalar number to an exogenous variable.')
                        end
                      case 'endogenous'
                        if ischar(B)
                            % Change equation.
                            o.change(S(1).subs{1}, B);
                        else
                            % Assign a value to an endogenous variable.
                            if isnumeric(B) && isscalar(B) && isreal(B)
                                o.var{id,2} = B;
                            else
                                error('Can only assign a real scalar number to an endogenous variable.')
                            end
                        end
                      otherwise
                        error('Wrong assignment.')
                    end
                else
                    error('Wrong assignment (index must be a character array, a known symbol).')
                end
            else
                error('Wrong assignment (cannot index with . or {}).')
            end
        end % function

    end % methods


end % classdef
