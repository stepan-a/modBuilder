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
        params = cell(0, 4);             % List of parameters
        varexo = cell(0, 4);             % List of exogenous variables.
        var = cell(0, 4);                % List of endogenous variables.
        tags = struct();                 % struct of dictionaries (one for each equation) for tags.
        symbols = cell(1, 0);            % List of untyped symbols
        equations = cell(0, 2);          % List of equations.
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
                    o.T.var.(o.var{i,1}) = unique(o.T.var.(o.var{i,1}));
                end
              otherwise
                error('Unknown type (%)', type)
            end % switch
        end % function

    end % methods


    methods(Static, Access = private)

        function skipline(n)
            if ~nargin || isempty(n)
                n = 1;
            end
            for i=1:n, fprintf('\n'), end
        end

        function str = printlist(names)
            str = sprintf(' %s', names{:});
            str = sprintf('%s;', str);
        end

        function printlist2(fid, type, Table)
            switch type
              case 'endogenous'
                keyword = 'var';
              case 'parameters'
                keyword = 'parameters';
              case 'exogenous'
                keyword = 'varexo';
            end
            if not(isempty(Table{1,4})) && not(isempty(Table{1,3}))
                fprintf(fid, '%s %s $%s$ (long_name=''%s'')\n\t', keyword, Table{1,1}, Table{1,4}, Table{1,3});
            elseif isempty(Table{1,4}) && not(isempty(Table{1,3}))
                fprintf(fid, '%s %s (long_name=''%s'')\n\t', keyword, Table{1,1}, Table{1,3});
            elseif not(isempty(Table{1,4})) && isempty(Table{1,3})
                fprintf(fid, '%s %s $%s$\n\t', keyword, Table{1,1}, Table{1,4});
            else
                fprintf(fid, '%s %s\n\t', keyword, Table{1,1});
            end
            for i=2:size(Table,1)
                if not(isempty(Table{i,4})) && not(isempty(Table{i,3}))
                    fprintf(fid, '%s $%s$ (long_name=''%s'')\n\t', Table{i,1}, Table{i,4}, Table{i,3});
                elseif isempty(Table{i,4}) && not(isempty(Table{i,3}))
                    fprintf(fid, '%s (long_name=''%s'')\n\t', Table{i,1}, Table{i,3});
                elseif not(isempty(Table{i,4})) && isempty(Table{i,3})
                    fprintf(fid, '%s $%s$\n\t', Table{i,1}, Table{i,4});
                else
                    fprintf(fid, '%s\n\t', Table{i,1});
                end
            end
            fprintf(fid, ';\n\n');
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
            % Filter out functions and operators
            tokens(cellfun(@(x) ismember(x, {'log', 'log10', 'ln', 'exp', 'sqrt', 'cbrt', 'abs', 'sign', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh', 'min', 'max', 'normcdf', 'normpdf', 'erf', 'diff', 'adl', 'EXPECTATIONS', 'STEADY_STATE'}), tokens)) = [];
            % Filter out empty elements.
            tokens(cellfun(@(x) all(isempty(x)), tokens)) = [];
            % Remove duplicates
            tokens = unique(tokens);
        end % function

        function b = isequalcell(cA, cB)
        % Return true iff n×2 cell arrays are identical (without taking care the ordering of the rowscA and cB are interpreted as sets of rows).
        %
        % INPUTS;
        % - cA    [cell]       n×2 array
        % - cB    [cell]       n×2 array
        %
        % OUTPUTS:
        % - b     [logical]    scalar
        %
        % REMARKS:
        % - Both ojects must have the same number of rows.
        % - It is assumed that the second columns are made only of characters or only of numbers.
        % - Since cA and cB are interpreted as sets of rows, ordering of the rows does not matter.
            b = false;
            if not(isequal(size(cA), size(cB)))
                return
            end
            cA = sortrows(cA, 1);
            cB = sortrows(cB, 1);
            if all(cellfun(@isnumeric, cA(:,2))) && all(cellfun(@isnumeric, cB(:,2)))
                isnanA = cellfun(@isnan, cA(:,2));
                isnanB = cellfun(@isnan, cB(:,2));
                if not(isequal(isnanA, isnanB))
                    return
                end
                b = isequal(cA(~isnanA,2), cB(~isnanB,2));
            elseif all(cellfun(@ischar, cA(:,2))) && all(cellfun(@ischar, cB(:,2)))
                b = isequal(cA(:,2), cB(:,2));
            else
                error('Second columns of cell arays must contain only numerics or only characters.')
            end
        end

        function b = isequalsymboltable(o, p, type)
        % Test if two tables of symbols are identical.
        %
        % INPUTS:
        % - o      [modBuilder]     model object
        % - p      [modBuilder]     model object
        % - type   [char]           row char array equal to 'params', 'var', 'varexo' or 'equations'
        %
        % OUTPUTS:
        % - b      [logical]        scalar, true iff the symbol tables are identical.
            b = false;
            S1 = o.T.(type);
            S2 = p.T.(type);
            f1 = fields(S1);
            f2 = fields(S2);
            if not(isequal(length(f1), length(f2)))
                return
            end
            if not(isequal(sort(f1), sort(f2)))
                return
            end
            for i=1:length(f1)
                b = isequal(sort(S1.(f1{i})), sort(S2.(f1{i})));
                if not(b)
                    return
                end
            end
        end

        function S = mergeStructs(S1, S2)
        % Merge two structures.
        %
        % INPUTS:
        % - S1   [struct]
        % - S2   [struct]
        %
        % OUTPUTS:
        % - S     [struct]
        %
        % REMARKS:
        % Each field of S1 or S2 holds row cell arrays or row character arrays (of endogenous variable names).
            f1 = fields(S1);
            f2 = fields(S2);
            f3 = intersect(f1, f2);
            S = struct();
            if isempty(f3)
                for i=1:length(f1)
                    S.(f1{i}) = S1.(f1{i});
                end
                for i=1:length(f2)
                    S.(f2{i}) = S2.(f2{i});
                end
            else
                for i=1:length(f1)
                    if ismember(f1{i}, f3)
                        S.(f1{i}) = union(S1.(f1{i}), S2.(f1{i}));
                    else
                        S.(f1{i}) = S1.(f1{i});
                    end
                end
                for i=1:length(f2)
                    if not(ismember(f2{i}, f3))
                        S.(f2{i}) = S2.(f2{i});
                    end
                end
            end
        end

        function [long_name, texname] = set_optional_fields(type, sname, varargin)
            long_name = '';
            texname='';
            if ~isempty(varargin)
                if ismember(type, {'endogenous', 'exogenous'})
                    type = sprintf('%s variable', type);
                end
                n = length(varargin);
                assert(mod(n, 2)==0, 'Wrong number of arguments.')
                for i=1:2:n
                    switch varargin{i}
                      case 'long_name'
                        long_name = varargin{i+1};
                      case 'texname'
                        texname = varargin{i+1};
                      otherwise
                        error('Unknown property for %s %s.', type, sname)
                    end
                end
            end
        end

        function C = replaceincell(C, oldword, newword);
            s = strcmp(oldword, C);
            if any(s)
                C{strcmp(oldword, C)} = newword;
            end
        end

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
                    o.tags = s.tags;
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

        function o = modBuilder(varargin)
        % Return an empty modBuilder object
            if nargin==1 && isdatetime(varargin{1})
                o.date = varargin{1};
            elseif nargin==0
                o.date = datetime;
            elseif (nargin==3 && isstruct(varargin{1}) && isstruct(varargin{2}) && ischar(varargin{3}) && isfile(varargin{3})) || ...
                    (nargin==4 && isstruct(varargin{1}) && isstruct(varargin{2}) && ischar(varargin{3}) && isfile(varargin{3}) && ischar(varargin{4}))
                M_ = varargin{1};
                oo_ = varargin{2};
                %
                % Load parameters
                %
                n = length(M_.param_names);
                o.params = cell(n, 4);
                o.params(:,1) = M_.param_names;
                o.params(:,2) = num2cell(M_.params);
                for i=1:n
                    if isequal(M_.param_names{i}, M_.param_names_long{i})
                        o.params{i,3} = '';
                    else
                        o.params{i,3} = M_.param_names_long{i};
                    end
                    if isequal(M_.param_names{i}, M_.param_names_tex{i})
                        o.params{i,4} = '';
                    else
                        o.params{i,4} = M_.param_names_tex{i};
                    end
                end
                %
                % Load exogenous variables
                %
                n = length(M_.exo_names);
                o.varexo = cell(n, 4);
                o.varexo(:,1) = M_.exo_names;
                o.varexo(:,2) = num2cell(oo_.exo_steady_state);
                for i=1:n
                    if isequal(M_.exo_names{i}, M_.exo_names_long{i})
                        o.varexo{i,3} = '';
                    else
                        o.varexo{i,3} = M_.exo_names_long{i};
                    end
                    if isequal(M_.exo_names{i}, M_.exo_names_tex{i})
                        o.varexo{i,4} = '';
                    else
                        o.varexo{i,4} = M_.exo_names_tex{i};
                    end
                end
                %
                % Read equations, set list of equations and endogenous variables.
                %
                JSON = readstruct(varargin{3});
                if nargin==4
                    equationtagname = varargin{4};
                else
                    equationtagname = 'name';
                end
                n = length(JSON.model);
                o.equations = cell(n, 2);
                o.var = cell(n, 4);
                for i=1:n
                    equation = JSON.model(i);
                    if not(isfield(equation, 'tags'))
                        error('Each equation must have a tag %s (to associate an endogenous variable).', equationtagname)
                    end
                    o.equations{i,2} = sprintf('%s = %s', equation.lhs, equation.rhs);
                    if ismember(equation.tags.(equationtagname), M_.endo_names)
                        o.var{i,1} = char(equation.tags.(equationtagname));
                        o.equations{i,1} = o.var{i,1};
                        id = strcmp(equation.tags.((equationtagname)), M_.endo_names);
                        o.var{i,2} = oo_.steady_state(id);
                        if isequal(o.var{i,1}, M_.endo_names_long{id})
                            o.var{i,3} = '';
                        else
                            o.var{i,3} = M_.endo_names_long{id};
                        end
                        if isequal(o.var{i,1}, M_.endo_names_tex{id})
                            o.var{i,4} = '';
                        else
                            o.var{i,4} = M_.endo_names_tex{id};
                        end
                        o.T.equations.(equation.tags.((equationtagname))) = modBuilder.getsymbols(o.equations{i,2});
                        o.symbols = unique(horzcat(o.symbols, o.T.equations.(equation.tags.((equationtagname)))));
                        o.T.equations.(equation.tags.(equationtagname)) = setdiff(o.T.equations.(equation.tags.((equationtagname))), equation.tags.((equationtagname)));
                        o.tags.(o.var{i,1}).name = o.var{i,1};
                        % Do we need to populate o.tags with other equation tags?
                        FieldNames = setdiff(fieldnames(o.tags.(o.var{i,1})), {equationtagname, 'name'});
                        % Equation tag name cannot be used if fourth argument is used.
                        for j=1:numel(FieldNames)
                            o.tags.(o.var{i,1}).(FieldNames{j}) = char(equation.tags.(FieldNames{j}));
                        end
                    else
                        error('The name (equation tag) of an equation should be an endogenous variable.')
                    end
                end
                o.updatesymboltables();
                o.symbols = setdiff(o.symbols, fields(o.T.params));
                o.symbols = setdiff(o.symbols, fields(o.T.varexo));
                o.symbols = setdiff(o.symbols, fields(o.T.var));
                if not(isempty(o.symbols))
                    warning('unknown symbols:%s.', modBuilder.printlist(o.symbols))
                end
                %
                % Set date
                %
                o.date = datetime;
            end
        end

        function listofsymbols = getallsymbols(o)
        % Return a cell array with all the symbols in a model.
        %
        % INPUTS:
        %  - o              [modBuilder]
        %
        % OUTPUTS:
        % - listofsymbols   [cell]          n×1, each element is a row character array (name of a symbol).
            listofsymbols = {};
            for i=1:o.size('equations')
                listofsymbols = union(listofsymbols, o.getsymbols(o.equations{i,2}));
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

        function o = add(o, varname, equation, varargin)
        % Add an equation to the model and associate an endogenous variable
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         1×n array, name of an endogenous variable
        % - equation    [char]         1×m array, expression
        % - ...         [cell]         1×p array, indices for implicit loops
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object (with new equation)
            number_of_loops = length(varargin);
            if not(number_of_loops)
                o = addeq(o, varname, equation);
            else
                indices = unique(regexp(equation, '\$[0-9]*', 'match'));
                % Check the number of indices (for loops)
                if ~isequal(numel(indices), number_of_loops)
                    error('The expected number of indices in the equation is %u but the equation has %u indices.', number_of_loops, numel(indices))
                end
                inames = regexp(varname, '\$[0-9]*', 'match');
                if not(isequal(numel(indices), numel(inames))) || ~isempty(setdiff(indices, inames)) || ~isempty(setdiff(inames, indices))
                    error('This case of implicit loops is not covered. Indices must be the same in the equation and in varname.')
                end
                % Check that the indices are uniform.
                isint = @(x) isnumeric(x) && rem(x, 1)==0;
                allint = false(number_of_loops, 1);
                allstr = false(number_of_loops, 1);
                for i=1:number_of_loops
                    if iscell(varargin{i})
                        if isvector(varargin{i})
                            allstr(i) = all(cellfun(@ischar, varargin{i}));
                            allint(i) = all(cellfun(isint, varargin{i}));
                            if not(allstr(i) || allint(i))
                                error('Values for index $%u should be all char or all integer.', i)
                            end
                        else
                            error('Values for index $%u should be pass as a one dimensional cell array.', i)
                        end
                    else
                        error('Values for index $%u should be pass as a cell array.', i)
                    end
                end
                % Compute Cartesian product of set of values
                mIndex = table2cell(combinations(varargin{:}));
                % Prepare
                Name = varname;
                for i=number_of_loops:-1:1
                    if allint(i)
                        Name = strrep(Name, sprintf('$%u',i), '%u');
                        % Equation = strrep(Equation, sprintf('$%u',i), '%u');
                    else
                        Name = strrep(Name, sprintf('$%u',i), '%s');
                        % Equation = strrep(Equation, sprintf('$%u',i), '%s');
                    end
                end
                for i=1:size(mIndex,1)
                    id = mIndex(i,:);
                    NAME = sprintf(Name, id{:});
                    Equation = equation;
                    for j=number_of_loops:-1:1
                        if allstr(j)
                            Equation = strrep(Equation, sprintf('$%u', j), id{j});
                        else
                            Equation = strrep(Equation, sprintf('$%u', j), num2str(id{j}));
                        end
                    end
                    o.add(NAME, Equation);
                end
            end
        end % function

        function o = addeq(o, varname, equation)
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
            id = strcmp(varname, o.varexo(:,1));
            if any(id)
                % The new equation is introducing an endogenous variable replacing an exogenous variable.
                o.varexo(id,:) = [];
            end
            o.T.equations.(varname) = modBuilder.getsymbols(equation);
            o.symbols = horzcat(o.symbols, o.T.equations.(varname));
            o.T.equations.(varname) = setdiff(o.T.equations.(varname), varname);
            o.symbols = setdiff(o.symbols, o.var(:,1));
            o.symbols = setdiff(o.symbols, o.symbols(cellfun(@o.issymbol, o.symbols)));
            o.tags.(varname).name = varname;
        end % function

        function o = tag(o, eqname, tagname, value)
        % Add or change an equation tag in model o.
        %
        % INPUTS:
        % - o           [modBuilder]
        % - eqname      [char]         1×n array, name of an equation
        % - tagname     [char]         1×m array, name of the tag
        % - value       [char]         1×p array, tag value
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object
        %
        % REMARKS:
        % This method cannot change the name of an equation, tagname=='name' will raise an error.
            if strcmp(tagname, 'name')
                error('Method tag cannot be used to change the name of an equation. Instead, use the rename method to change the name of an endogenous variable.')
            end
            o.tags.(eqname).(tagname) = value;
        end % function

        function o = parameter(o, pname, pvalue, varargin)
        % Declare or calibrate a parameter
        %
        % INPUTS:
        % - o         [modBuilder]
        % - pname     [char]         1×n array, name of a parameter
        % - pvalue    [double]       scalar, value of the parameter (default is NaN)
        % - ...
        %
        % OUTPUTS:
        % - o         [modBuilder]   updated object
        %
        % REMARKS:
        % - If symbol pname is known as an exogenous variable, it is converted to a parameter. If pvalue is not NaN, pname is set
        % equal to pvalue, otherwise the parameter is calibrated with the value of the exogeous variable.
        % - Optional arguments in varargin must come by key/value pairs. Allowed keys are 'long_name' and 'texname'.
            if ~(ismember(pname, o.symbols) || ismember(pname, o.varexo(:,1)) || ismember(pname, o.params(:,1)))
                if ismember(pname, o.var(:,1))
                    error('An endogenous variable cannot be converted into a parameter.')
                else
                    error('Symbol %s appears nowhere in the model.', pname)
                end
            end
            if nargin<3 || isempty(pvalue)
                % Set default value
                pvalue = NaN;
            end
            [long_name, texname] = modBuilder.set_optional_fields('parameter', pname, varargin{:});
            idp = ismember(o.params(:,1), pname);
            if any(idp) % The parameter is already defined
                o.params{idp, 2} = pvalue;
                if not(isempty(long_name))
                    o.params{idp,3} = long_name;
                end
                if not(isempty(texname))
                    o.params{idp,4} = texname;
                end
            else
                idx = ismember(o.varexo(:,1), pname);
                if any(idx)
                    % pname is an exogenous variable, we change its type to parameter.
                    o.params(length(idp)+1,:) = o.varexo(idx,:);
                    o.varexo(idx,:) = [];
                    if not(isnan(pvalue))
                        o.params{length(idp)+1,2} = pvalue;
                    end
                    if not(isempty(long_name))
                        o.params{length(idp)+1,3} = long_name;
                    end
                    if not(isempty(texname))
                        o.params{length(idp)+1,4} = texname;
                    end
                else
                    % Symbol pname has no predefined type.
                    o.params{length(idp)+1,1} = pname;
                    o.params{length(idp)+1,2} = pvalue;
                    o.params{length(idp)+1,3} = long_name;
                    o.params{length(idp)+1,4} = texname;
                end
            end
            % Remove pname from the list of untyped symbols
            o.symbols = setdiff(o.symbols, pname);
        end % function

        function o = exogenous(o, xname, xvalue, varargin)
        % Declare or set default value for an exogenous variables
        %
        % INPUTS:
        % - o         [modBuilder]
        % - xname     [char]         1×n array, name of an exogenous variable
        % - xvalue    [double]       scalar, value of the exogenous variable (default is NaN)
        % - ...
        %
        % OUTPUTS:
        % - o         [modBuilder]   updated object
        %
        % REMARKS:
        % - If symbol xname is known as a parameter, it is converted to an exogenous variable. If xvalue is not NaN, xname is set
        % equal to xvalue, otherwise the exogenous variable is calibrated with the value of the parameter.
        % - Optional arguments in varargin must come by key/value pairs. Allowed keys are 'long_name' and 'texname'.
            if ~(ismember(xname, o.symbols) || ismember(xname, o.varexo(:,1)) || ismember(xname, o.params(:,1)))
                if ismember(xname, o.var(:,1))
                    error('An endogenous variable cannot be converted into an exogenous variable.\nPlease remove the equation associated to the endogenous variable.')
                else
                    error('Symbol %s appears nowhere in the model.', pname)
                end
            end
            if nargin<3 || isempty(xvalue)
                % Set default value
                xvalue = NaN;
            end
            [long_name, texname] = modBuilder.set_optional_fields('exogenous', xname, varargin{:});
            idx = ismember(o.varexo(:,1), xname);
            if any(idx) % The exogenous variable is already defined
                o.varexo{idx,2} = xvalue;
                if not(isempty(long_name))
                    o.varexo{idx,3} = long_name;
                end
                if not(isempty(texname))
                    o.varexo{idx,4} = texname;
                end
            else
                idp = ismember(o.params(:,1), xname);
                if any(idp)
                    % pname is a parameter, we change its type to exogenous variable.
                    o.varexo(length(idx)+1,:) = o.params(idp,:);
                    o.params(idp,:) = [];
                    if not(isnan(xvalue))
                        o.varexo{length(idx)+1,2} = xvalue;
                    end
                    if not(isempty(long_name))
                        o.varexo{length(idx)+1,3} = long_name;
                    end
                    if not(isempty(texname))
                        o.varexo{length(idx)+1,4} = texname;
                    end
                else
                    o.varexo{length(idx)+1,1} = xname;
                    o.varexo{length(idx)+1,2} = xvalue;
                    o.varexo{length(idx)+1,3} = long_name;
                    o.varexo{length(idx)+1,4} = texname;
                end
            end
            % Remove xname from the list of untyped symbols
            o.symbols = setdiff(o.symbols, xname);
        end % function

        function o = endogenous(o, ename, evalue, varargin)
        % Declare or set default value for endogenous variables
        %
        % INPUTS:
        % - o         [modBuilder]
        % - ename     [char]         1×n array, name of an endogenous variable
        % - evalue    [double]       scalar, value of the endogenous variable (default is NaN)
        % - ...
        %
        % OUTPUTS:
        % - o         [modBuilder]   updated object
        %
        % REMARKS:
        % - Optional arguments in varargin must come by key/value pairs. Allowed keys are 'long_name' and 'texname'.
            if nargin<3 || isempty(evalue)
                % Set default value
                evalue = NaN;
            end
            [long_name, texname] = modBuilder.set_optional_fields('endogenous', ename, varargin{:});
            ide = ismember(o.var(:,1), ename);
            if any(ide) % The endogenous variable is already defined
                o.var{ide,2} = evalue;
                if not(isempty(long_name))
                    o.var{ide,3} = long_name;
                end
                if not(isempty(texname))
                    o.var{ide,4} = texname;
                end
            else
                o.var{length(ide)+1,1} = ename;
                o.var{length(ide)+1,2} = evalue;
                o.var{length(ide)+1,3} = long_name;
                o.var{length(ide)+1,4} = texname;
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
            ide = ismember(o.equations(:,1), eqname);
            if not(any(ide))
                error('Unknown equation (%s).', eqname)
            end
            o.equations(ide,:) = [];
            o.tags = rmfield(o.tags, eqname);
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

        function o = rename(o, oldsymbol, newsymbol)
        % Rename a symbol.
        %
        % INPUTS:
        % - o            [modBuilder]
        % - oldsymbol    [char]            1×n array, name of a symbol (parameter, endogenous or exogenous variable)
        % - newsymbol    [char]            1×m array, name of a symbol (parameter, endogenous or exogenous variable)
        %
        % OUTPUTS:
        % - o            [char]            updated object
            [type, id] = o.typeof(oldsymbol);
            switch type
              case 'parameter'
                o.params{id,1} = newsymbol;
                o.T.params.(newsymbol) = o.T.params.(oldsymbol);
                o.T.params = rmfield(o.T.params, oldsymbol);
              case 'exogenous'
                o.varexo{id,1} = newsymbol;
                o.T.varexo.(newsymbol) = o.T.varexo.(oldsymbol);
                o.T.varexo = rmfield(o.T.varexo, oldsymbol);
              case 'endogenous'
                o.var{id,1} = newsymbol;
                o.equations{strcmp(oldsymbol, o.equations(:,1)),1} = newsymbol;
                o.T.var.(newsymbol) = o.T.var.(oldsymbol);
                o.T.var = rmfield(o.T.var, oldsymbol);
                o.T.equations.(newsymbol) = o.T.equations.(oldsymbol);
                o.T.equations = rmfield(o.T.equations, oldsymbol);
                o.tags.(newsymbol) = o.tags.(oldsymbol);
                o.tags = rmfield(o.tags, oldsymbol);
                o.tags.(newsymbol).name = newsymbol;
                for i=1:o.size('parameters')
                    o.T.params.(o.params{i,1}) = modBuilder.replaceincell(o.T.params.(o.params{i,1}), oldsymbol, newsymbol);
                end
                for i=1:o.size('exogenous')
                    o.T.varexo.(o.varexo{i,1}) = modBuilder.replaceincell(o.T.varexo.(o.varexo{i,1}), oldsymbol, newsymbol);
                end
                for i=1:o.size('endogenous')
                    o.T.var.(o.var{i,1}) = modBuilder.replaceincell(o.T.var.(o.var{i,1}), oldsymbol, newsymbol);
                end
            end
            for i=1:o.size('equations')
                o.equations{i,2} = regexprep(o.equations{i,2}, ['(?<!\w)' oldsymbol  '(?!\w)'], newsymbol);
                o.T.equations.(o.equations{i,1}) = modBuilder.replaceincell(o.T.equations.(o.equations{i,1}), oldsymbol, newsymbol);
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
            if all(cellfun(@(x) isempty(x), o.var(:,3))) && all(cellfun(@(x) isempty(x), o.var(:,4)))
                fprintf(fid, 'var%s\n\n', modBuilder.printlist(o.var(:,1)));
            else
                modBuilder.printlist2(fid, 'endogenous', o.var);
            end
            %
            % Print list of exogenous variables
            %
            if all(cellfun(@(x) isempty(x), o.varexo(:,3))) && all(cellfun(@(x) isempty(x), o.varexo(:,4)))
                fprintf(fid, 'varexo%s\n\n', modBuilder.printlist(o.varexo(:,1)));
            else
                modBuilder.printlist2(fid, 'exogenous', o.varexo);
            end
            %
            % Print list of fprintf
            %
            if all(cellfun(@(x) isempty(x), o.params(:,3))) && all(cellfun(@(x) isempty(x), o.params(:,4)))
                fprintf(fid, 'parameters%s\n\n', modBuilder.printlist(o.params(:,1)));
            else
                modBuilder.printlist2(fid, 'parameters', o.params);
            end
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
                Tags = o.tags.(o.equations{i,1});
                tagnames = fieldnames(Tags);
                if isequal(numel(tagnames), 1)
                    fprintf(fid, '[name = ''%s'']\n', Tags.name);
                else
                    fprintf(fid, '[name = ''%s''', Tags.name);
                    tagnames = setdiff(tagnames, 'name');
                    while ~isempty(tagnames)
                        fprintf(fid, ', %s = ''%s''', tagnames{1}, Tags.(tagnames{1}));
                        tagnames = setdiff(tagnames, tagnames{1});
                    end
                    fprintf(fid, ']\n');
                end
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
            s.tags = o.tags;
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

        function b = issymbol(o, name)
        % Return true iff name is an endogenous variabl, an exogenous variable or a parameter.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            b = o.isexogenous(name) || o.isendogenous(name) || o.isparameter(name);
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

        function o = lookfor(o, name)
        % Print equations where symbol 'name' appears.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol.
        %
        % OUTPUTS:
        % - b         [logical]      scalar
            if o.isparameter(name)
                symboltype = 'Parameter';
                eqnames = o.T.params.(name);
            elseif o.isexogenous(name)
                symboltype = 'Exogenous variable';
                eqnames = o.T.varexo.(name);
            elseif o.isendogenous(name)
                symboltype = 'Endogenous variable';
                eqnames = o.T.var.(name);
            else
                symboltype = 'Unknown';
                eqnames = {};
            end
            modBuilder.skipline()
            if strcmp(symboltype, 'Unknown')
                fprintf('Symbol %s does not appear in any of the equations.\n', name);
                modBuilder.skipline()
            else
                n = length(eqnames);
                if n>1
                    fprintf('%s %s appears in %u equations:\n', symboltype, name, n);
                else
                    fprintf('%s %s appears in one equation:\n', symboltype, name);
                end
                for i=1:n
                    equation = o.equations(strcmp(eqnames{i}, o.equations(:,1)),2);
                    modBuilder.skipline()
                    fprintf('[%s]\t\t%s\n', o.tags.(eqnames{i}).name, equation{1});
                end
                modBuilder.skipline()
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
            o.var = [o.var; {varexoname o.varexo{ix,2} o.varexo{ix,3} o.varexo{ix,4}}];
            o.varexo = [o.varexo; {varname o.var{ie,2} o.var{ie,3} o.var{ie,4}}];
            % Remove variables
            o.var(ie,:) = [];
            o.varexo(ix,:) = [];
            % Update symbol tables
            o.T.var.(varexoname) = o.T.varexo.(varexoname);
            o.T.varexo.(varname) = o.T.var.(varname);
            o.T.varexo = rmfield(o.T.varexo, varexoname);
            o.T.var = rmfield(o.T.var, varname);
            o.T.equations.(varexoname) = o.T.equations.(varname);
            o.T.equations = rmfield(o.T.equations, varname);
            mask = strcmp(varexoname, o.T.equations.(varexoname));
            o.T.equations.(varexoname){mask} = varname;
            % Associate new endogenous variable to an equation (the one previously associated with varname)
            o.equations{strcmp(varname, o.equations(:,1)),1} = varexoname;
            % Update tags
            o.tags.(varexoname) = o.tags.(varname);
            o.tags = rmfield(o.tags, varname);
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
            p.tags = o.tags;
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
            if not(modBuilder.isequalcell(o.params, p.params))
                b = false;
                return
            end
            if not(modBuilder.isequalcell(o.varexo, p.varexo))
                b = false;
                return
            end
            if not(modBuilder.isequalcell(o.var, p.var))
                b = false;
                return
            end
            if not(isequal(sort(o.symbols), sort(p.symbols)))
                b = false;
                return
            end
            if not(modBuilder.isequalcell(o.equations, p.equations))
                b = false;
                return
            end
            for i=1:o.size('equations')
                if not(isequal(o.tags.(o.equations{i,1}), p.tags.(o.equations{i,1})))
                    b = false;
                    return
                end
            end
            if not(modBuilder.isequalsymboltable(o, p, 'params'))
                b = false;
                return
            end
            if not(modBuilder.isequalsymboltable(o, p, 'varexo'))
                b = false;
                return
            end
            if not(modBuilder.isequalsymboltable(o, p, 'var'))
                b = false;
                return
            end
            if not(modBuilder.isequalsymboltable(o, p, 'equations'))
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

        function o = subs(o, expr1, expr2, eqname)
        % Substitute expr1 by expr2 in equation eqname (use strrep).
        %
        % INPUTS:
        % - o           [modBuilder]
        % - expr1       [char]         1×n array, expression
        % - expr2       [char]         1×m array, expression
        % - eqname      [char]         1×p array, name of an equation
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object (with new equation)
        %
        % REMARKS:
        % If last argument is not provided, expr1 is substituted by expr2 in all the model.
            if nargin<4
                eqname = [];
            end
            o = substitution(o, expr1, expr2, eqname, true);
        end % function

        function o = substitute(o, expr1, expr2, eqname)
        % Substitute expr1 by expr2 in equation eqname (use regexprep).
        %
        % INPUTS:
        % - o           [modBuilder]
        % - expr1       [char]         1×n array, expression
        % - expr2       [char]         1×m array, expression
        % - eqname      [char]         1×p array, name of an equation
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object (with new equation)
        %
        % REMARKS:
        % If last argument is not provided, expr1 is substituted by expr2 in all the model.
            if nargin<4
                eqname = [];
            end
            o = substitution(o, expr1, expr2, eqname, false);
        end % function

        function o = substitution(o, expr1, expr2, eqname, usestrrep)
        % Substitute expr1 by expr2 in equation eqname (use strrep or ).
        %
        % INPUTS:
        % - o           [modBuilder]
        % - expr1       [char]         1×n array, expression
        % - expr2       [char]         1×m array, expression
        % - eqname      [char]         1×p array, name of an equation
        % - usestrrep   [logicdal]      scalar, use strrep if true, use regexprep otherwise.
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object (with new equation)
        %
        % REMARKS:
        % If last argument is not provided, expr1 is substituted by expr2 in all the model.
            if usestrrep
                % Is it safe to use the subs method?
                if o.issymbol(expr1)
                    warning('It is not safe to use the subs method to change a symbol. I switch to the substitute method with a regular expression. If the change applies to all the equations you could also use the rename method.')
                    o.substitute(['(?<!\w)' expr1  '(?!\w)'], expr2, eqname);
                    return
                end
            else
                % Test if expr1 is a valid regular expression
                try
                    regexp('', expr1);
                catch
                    error('You did not provide a valid regular expression.')
                end
            end
            % Where does the substitution should be done?
            if isempty(eqname)
                % Apply the change to all the equations
                eqnames = o.equations(:,1);
            else
                if ischar(eqname)
                    eqnames = {eqname};
                else
                    if iscellstr(eqname)
                        eqnames = eqname(:);
                    else
                        error('Unexpected input type. Last input must be a row character array (designating an equation) or a univariate cell array of row char arrays.')
                    end
                end
            end
            if ~usestrrep
                % Test that the regular expression matches only one expression in all the selected equations.
                matches = {};
                for i=1:numel(eqnames)
                    id = strcmp(eqnames{i}, o.equations(:,1));
                    matches = union(matches, unique(regexp(o.equations{id,2}, expr1, 'match')));
                end
                if length(matches)>1
                    error('The provided regular expression matches more than one expression in the equation(s).')
                else
                    expr0 = matches{1};
                end
            end
            % Can we use the rename method (is the substitution for a symbol in all the equations where it appears)?
            userename = false;
            if ~usestrrep && o.issymbol(expr0)
                if isequal(numel(eqnames), o.size('equations'))
                    userename = true;
                else
                    % Does the matched symbol appear in other equations?
                    eqnames_ = setdiff(o.equations(:,1), eqnames);
                    matches = {};
                    for i=1:numel(eqnames_)
                        id = strcmp(eqnames_{i}, o.equations(:,1));
                        matches = union(matches, unique(regexp(o.equations{id,2}, expr1, 'match')));
                    end
                    if isempty(matches)
                        % expr1 does not appear in any other equation, we can safely use the rename method
                        userename = true;
                    end
                end
            end
            if userename
                % We can safely use the rename method.
                o.rename(expr0, expr2);
                return
            end
            list_of_unknown_symbols = {};
            for i=1:numel(eqnames)
                eqname = eqnames{i};
                select = strcmp(eqname, o.equations(:,1));
                if usestrrep
                    o.equations(select,2) = strrep(o.equations(select,2), expr1, expr2);
                else
                    o.equations(select,2) = regexprep(o.equations(select,2), expr1, expr2);
                end
                Symbols = modBuilder.getsymbols(o.equations{select,2});
                newsyms = setdiff(Symbols, o.T.equations.(eqname)); % New symbols in updated equation
                if ~isempty(newsyms)
                    for j=1:length(newsyms)
                        if ~o.issymbol(newsyms{j})
                            if ~ismember(newsyms{j}, list_of_unknown_symbols)
                                disp(sprintf('Symbol %s is unknown, you need to provide a type (parameter, endogenous or exogenous variable).', newsyms{j}))
                                list_of_unknown_symbols{end+1} = newsyms{j};
                            end
                        end
                    end
                end
                delsyms = setdiff(o.T.equations.(eqname), Symbols); % Deleted symbols in updated equation
                if ~isempty(delsyms)
                    for j=1:length(delsyms)
                        [type, id] = o.typeof(delsyms{j});
                        if ~o.appear_in_more_than_one_equation(delsyms{j})
                            switch type
                              case 'parameter'
                                disp(sprintf('Parameter %s will be removed).', delsyms{j}))
                                o.params(id,:) = [];
                              case 'exogenoous'
                                disp(sprintf('Exogenous variable %s will be removed).', delsyms{j}))
                                o.varexo(id,:) = [];
                              case 'endogenous'
                                disp(sprintf('Endogenous variable %s will be removed).', delsyms{j}))
                                o.var(id,:) = [];
                            end
                        else
                            %
                        end
                    end
                end
                o.T.equations.(eqname) = Symbols;
            end
            o.updatesymboltables;
        end % function

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

        function q = merge(o, p)
        % Merge two models.
        %
        % INPUTS:
        % - o    [modBuilder]
        % - p    [modBuilder]
        %
        % OUTPUTS:
        % - q    [modBuilder]
        %
        % REMARKS:
        % Endogenous variables in models o and p must be different, i.e. intersect(o.var, p.var) must be empty. If this is not the case, the user must remove
        % the common endogenous variables (and associated equations) in one of the model.
            commonvariables = intersect(o.var(:,1), p.var(:,1));
            if ~isempty(commonvariables)
                error('Models to be merged cannot contain common endogenous variables. Check variable(s)%s.', sprintf(' %s', commonvariables{:}))
            end
            q = modBuilder();
            %
            % Set parameters of the new model.
            %
            o_params_list = o.params(:,1);
            p_params_list = p.params(:,1);
            common_params = intersect(o_params_list, p_params_list);
            o_only_params_list = setdiff(o_params_list, p_params_list);
            p_only_params_list = setdiff(p_params_list, o_params_list);
            q_params = cell(length(o_only_params_list)+length(p_only_params_list)+length(common_params), 4);
            i = 1;
            for j=1:length(o_only_params_list)
                q_params{i,1} = o_only_params_list{j};
                q_params{i,2} = o.params{ismember(o.params(:,1), o_only_params_list{j}),2};
                q_params{i,3} = o.params{ismember(o.params(:,1), o_only_params_list{j}),3};
                q_params{i,4} = o.params{ismember(o.params(:,1), o_only_params_list{j}),4};
                i = i+1;
            end
            for j=1:length(common_params)
                q_params{i,1} = common_params{j};
                tmp = p.params{ismember(p.params(:,1), common_params{j}),2};
                if not(isnan(tmp))
                    q_params{i,2} = tmp;
                    q_params{i,3} = p.params{ismember(p.params(:,1), common_params{j}),3};
                    q_params{i,4} = p.params{ismember(p.params(:,1), common_params{j}),4};
                else
                    q_params{i,2} = o.params{ismember(o.params(:,1), o_only_params_list{j}),2};
                    q_params{i,3} = o.params{ismember(o.params(:,1), o_only_params_list{j}),3};
                    q_params{i,4} = o.params{ismember(o.params(:,1), o_only_params_list{j}),4};
                end
                i = i+1;
            end
            for j=1:length(p_only_params_list)
                q_params{i,1} = p_only_params_list{j};
                q_params{i,2} = p.params{ismember(p.params(:,1), p_only_params_list{j}),2};
                q_params{i,3} = p.params{ismember(p.params(:,1), p_only_params_list{j}),3};
                q_params{i,4} = p.params{ismember(p.params(:,1), p_only_params_list{j}),4};
                i = i+1;
            end
            q.params = q_params;
            %
            % Set list of endogenous variables in the new model and change type of some exogenous variables.
            %
            o_varexo_list = o.varexo(:,1);
            p_varexo_list = p.varexo(:,1);
            % Set list of exogenous variables, in model o, that will become endogenous when model o is merged with model p.
            o_varexo2var = intersect(o_varexo_list, p.var(:,1));
            % Set list of exogenous variables, in model p, that will become endogenous when model p is merged with model o.
            p_varexo2var = intersect(p_varexo_list, o.var(:,1));
            % Set list of endogenous variables (with calibration)
            q.var = [o.var; p.var];
            %
            % Set list of exogenous variables
            %
            if ~isempty(o_varexo2var)
                ose = ~ismember(o_varexo2var, o_varexo_list); % Select exogenous variables from model o, excluding those that will be endogeneised when merging with model p.
            else
                ose = true(length(o_varexo_list), 1);
            end
            if ~isempty(p_varexo2var)
                pse = ~ismember(p_varexo2var, p_varexo_list); % Select exogenous variables from model p, excluding those that will be endogeneised when merging with model o.
            else
                pse = true(length(p_varexo_list), 1);
            end
            tmp = [o_varexo_list(ose); p_varexo_list(pse)];
            q_varexo = cell(length(tmp), 4);
            q_varexo(:,1) = tmp;
            q_varexo(:,2) = {NaN};
            [ido, io] = ismember(q_varexo(:,1), o_varexo_list);
            [idp, ip] = ismember(q_varexo(:,1), p_varexo_list);
            if any(ido)
                for i=1:length(o_varexo_list(ose))
                    if ido(i)
                        q_varexo{i,2} = o.varexo{io(i),2};
                        q_varexo{i,3} = o.varexo{io(i),3};
                        q_varexo{i,4} = o.varexo{io(i),4};
                    end
                end
            end
            if any(idp)
                for i=length(o_varexo_list(ose))+1:length(p_varexo_list(pse))
                    if idp(i)
                        q_varexo{i,2} = p.varexo{ip(i),2};
                        q_varexo{i,3} = p.varexo{ip(i),3};
                        q_varexo{i,4} = p.varexo{ip(i),4};
                    end
                end
            end
            q.varexo = q_varexo;
            %
            % Set list of equations
            %
            q.equations = [o.equations; p.equations];
            %
            % Set symbol tables
            %
            q.T.params = modBuilder.mergeStructs(o.T.params, p.T.params);
            q.T.varexo = modBuilder.mergeStructs(o.T.varexo, p.T.varexo);
            fnames = fields(q.T.varexo);
            remvarexo = not(ismember(fnames, q.varexo(:,1)));
            for i=1:length(remvarexo)
                if remvarexo(i)
                    rmfield(q.T.varexo, fnames{i});
                end
            end
            clear('fnames', 'remvarexo');
            q.T.var = modBuilder.mergeStructs(o.T.var, p.T.var);
            q.T.equations = modBuilder.mergeStructs(o.T.equations, p.T.equations);
            q.tags = modBuilder.mergeStructs(o.tags, p.tags);
            q.updatesymboltables();
        end

        function evaleq = evaluate(o, eqname, printflag)
        % Evaluate an equation.
        %
        % INPUTS:
        % - o            [modBuilder]
        % - eqname       [char]         1×n array, name of an equation (endogenous variable)
        % - printflag    [logical]      scalar, print results if true (default is false)
        %
        % OUTPUTS:
        % - lhs          [double]       scalar, evaluation of the LHS member of the equation
        % - rhs          [double]       scalar, evaluation of the RHS member of the equation
        % - resid        [double]       scalar, evaluation of LHS-RHS
        %
        % REMARKS:
        % If the equation does not contain an ‘=’ symbol — and thus no LHS or RHS — the expression is evaluated as the left-hand
        % side (lhs) and its residual (resid), while the right-hand side (rhs) is set to 0.
            if nargin<3
                printflag = false;
            end
            %
            % Initialise outputs
            %
            evaleq.lhs = NaN;
            evaleq.rhs = NaN;
            evaleq.resid = NaN;
            %
            % Get static version of the equation
            %
            eq = @(x) isequal(x, eqname);
            eqID = cellfun(eq, o.equations(:,1));
            equation = regexprep(o.equations{eqID, 2}, '(\w+)\([+-]?\d+\)', '$1');
            %
            % Is there an equal symbol? If not we just evaluate the expression and return resid.
            %
            LHSRHS = strsplit(equation, '=');
            if isscalar(LHSRHS)
                LHS = LHSRHS{1};
                RHS = '0';
            elseif length(LHSRHS)==2
                LHS = LHSRHS{1};
                RHS = LHSRHS{2};
            else
                error('An equation cannot have more than one equal (=) symbol.')
            end
            %
            % Evaluate the equation
            %
            Symbols = o.T.equations.(eqname);
            Symbols = [Symbols, eqname];
            for i=1:length(Symbols)
                symbol = Symbols{i};
                [type, id] = o.typeof(symbol);
                switch type
                  case 'parameter'
                    LHS = regexprep(LHS, ['\<', symbol, '\>'], num2str(o.params{id,2}, 15));
                    RHS = regexprep(RHS, ['\<', symbol, '\>'], num2str(o.params{id,2}, 15));
                  case 'exogenous'
                    LHS = regexprep(LHS, ['\<', symbol, '\>'], num2str(o.varexo{id,2}, 15));
                    RHS = regexprep(RHS, ['\<', symbol, '\>'], num2str(o.varexo{id,2}, 15));
                  case 'endogenous'
                    LHS = regexprep(LHS, ['\<', symbol, '\>'], num2str(o.var{id,2}, 15));
                    RHS = regexprep(RHS, ['\<', symbol, '\>'], num2str(o.var{id,2}, 15));
                  otherwise
                    error('Unknown symbol type.')
                end
            end
            evaleq.lhs = eval(LHS);
            evaleq.rhs = eval(RHS);
            evaleq.resid = evaleq.lhs-evaleq.rhs;
            if printflag
                disp(' ')
                disp(sprintf('Static equation: %s', equation));
                disp(' ')
                disp(sprintf('LHS:             %f', evaleq.lhs));
                disp(sprintf('RHS:             %f', evaleq.rhs));
                if evaleq.resid<0
                    disp(sprintf('residual:       %f', evaleq.resid));
                else
                    disp(sprintf('residual:        %f', evaleq.resid));
                end
                disp(' ')
            end
        end

        function o = solve(o, eqname, sname, sinit)
        % Solve static equation eqname for symbol sname.
        %
        % INPUTS:
        % - o            [modBuilder]
        % - eqname       [char]         1×n array, name of an equation (endogenous variable)
        % - sname        [char]         1×m array, name of a symbol
        % - sinit        [double]       scalar, initial guess
        %
        % OUTPUTS:
        % - o            [modBuilder]
            if not(ismember(sname, o.T.equations.(eqname)))
                if o.isendogenous(sname)
                    if not(ismember(eqname, o.T.var.(sname)))
                        error('Symbol %s does not appear in equation %s', sname, eqname)
                    end
                else
                    error('Symbol %s does not appear in equation %s', sname, eqname)
                end
            end
            %
            % Get static version of the equation
            %
            eq = @(x) isequal(x, eqname);
            eqID = cellfun(eq, o.equations(:,1));
            equation = regexprep(o.equations{eqID, 2}, '(\w+)\([+-]?\d+\)', '$1');
            %
            % List of known symbols
            %
            knownsymbols = o.T.equations.(eqname);
            knownsymbols = setdiff([knownsymbols, eqname], sname);
            %
            % Replace the known symbols with their respective values.
            %
            for i=1:length(knownsymbols)
                symbol = knownsymbols{i};
                [type, id] = o.typeof(symbol);
                switch type
                  case 'parameter'
                    equation = regexprep(equation, ['\<', symbol, '\>'], num2str(o.params{id,2}, 15));
                  case 'exogenous'
                    equation = regexprep(equation, ['\<', symbol, '\>'], num2str(o.varexo{id,2}, 15));
                  case 'endogenous'
                    equation = regexprep(equation, ['\<', symbol, '\>'], num2str(o.var{id,2}, 15));
                  otherwise
                    error('Unknown symbol type.')
                end
            end
            %
            % Set anonymous function
            %
            equation = regexprep(equation, ['\<', sname, '\>'], 'x');
            LHSRHS = strsplit(equation, '=');
            if isscalar(LHSRHS)
                equation = sprintf('@(x) %s', LHSRHS{1});
            elseif length(LHSRHS)==2
                equation = sprintf('@(x) %s-(%s)', LHSRHS{1}, LHSRHS{2});
            else
                error('An equation cannot have more than one equal (=) symbol.')
            end
            f = str2func(equation);
            %
            % Set initial guess for the unknown symbol
            %
            [x, ~, ~] = solvers.newton(f, sinit, 1e-6, 100);
            [type, id] = o.typeof(sname);
            switch type
              case 'parameter'
                o.params{id,2} = x;
              case 'exogenous'
                o.varexo{id,2} = x;
              case 'endogenous'
                o.var{id,2} = x;
              otherwise
                error('Unknown symbol type.')
            end
        end

        function p = subsref(o, S)
            if isequal(S(1).type, '()')
                p = o.extract(S(1).subs{:});
                    S = modBuilder.shiftS(S, 1);
            elseif isequal(S(1).type, '.')
                if ~ismember(S(1).subs, {metaclass(o).PropertyList.Name})
                    if isscalar(S)
                        if ismember(S(1).subs, o.equations(:,1))
                            p = o.extract(S(1).subs);
                        else
                            p = feval(S(1).subs, o);
                        end
                        S = modBuilder.shiftS(S, 1);
                    else
                        if ismember(S(1).subs, o.equations(:,1))
                            p = o.extract(S(1).subs);
                            S = modBuilder.shiftS(S, 1);
                        else
                            p = feval(S(1).subs, o, S(2).subs{:});
                            S = modBuilder.shiftS(S, 2);
                        end
                    end
                else
                    p = o.(S(1).subs);
                    S = modBuilder.shiftS(S, 1);
                end
            else
                error('Indexing a modBuilder object with {} is not allowed.')
            end
            if ~isempty(S)
                p = subsref(p, S);
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
