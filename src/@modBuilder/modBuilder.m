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
        % Parameters table (n×4 cell array)
        % Column 1: parameter name (char)
        % Column 2: calibration value (double or NaN)
        % Column 3: long_name (char or empty)
        % Column 4: tex_name (char or empty)
        params = cell(0, 4);

        % Exogenous variables table (n×4 cell array)
        % Column 1: variable name (char)
        % Column 2: default value (double or NaN)
        % Column 3: long_name (char or empty)
        % Column 4: tex_name (char or empty)
        varexo = cell(0, 4);

        % Endogenous variables table (n×4 cell array)
        % Column 1: variable name (char)
        % Column 2: steady state value (double or NaN)
        % Column 3: long_name (char or empty)
        % Column 4: tex_name (char or empty)
        var = cell(0, 4);

        % Equation tags: struct with one field per equation
        % Each field contains a struct with tag name/value pairs
        % All equations have at least a 'name' tag
        tags = struct();

        % Temporary list of untyped symbols (1×n cell array)
        % Symbols extracted from equations that haven't been
        % classified as parameter, endogenous, or exogenous
        symbols = cell(1, 0);

        % Equations table (n×2 cell array)
        % Column 1: equation name (associated endogenous variable)
        % Column 2: equation expression (char)
        equations = cell(0, 2);

        % Symbol table: maps symbols to equations where they appear
        % T.params.<NAME> = {eq1, eq2, ...} - equations using parameter NAME
        % T.varexo.<NAME> = {eq1, eq2, ...} - equations using exogenous variable NAME
        % T.var.<NAME> = {eq1, eq2, ...} - equations using endogenous variable NAME
        % T.equations.<EQNAME> = {sym1, sym2, ...} - symbols used in equation EQNAME
        T = struct('params', struct(), 'varexo', struct(), 'var', struct(), 'equations', struct());
    end

    properties (SetAccess = immutable)
        % Creation date (datetime): timestamp when the modBuilder object was created
        % This property is immutable and set only during construction
        date
    end

    properties (Constant, Access = private)
        % Column indices for params, varexo, var tables
        % Using named constants improves code readability and maintainability
        COL_NAME = 1        % Symbol name (char)
        COL_VALUE = 2       % Calibration/value (double or NaN)
        COL_LONG_NAME = 3   % Long description (char or empty)
        COL_TEX_NAME = 4    % TeX representation (char or empty)

        % Column indices for equations table
        EQ_COL_NAME = 1     % Equation name (endogenous variable name)
        EQ_COL_EXPR = 2     % Equation expression (char)
    end

    properties (Constant)
        % Valid symbol/component types for type checking
        % Used by size(), updatesymboltable(), and other methods that accept type arguments
        % Public constant so users can query valid types programmatically
        VALID_TYPES = {'parameters', 'exogenous', 'endogenous', 'equations'}
    end

    properties (Constant, Access = private)
        % Reserved function names that cannot be used as symbol names
        % These are MATLAB/Octave built-in functions and Dynare-specific functions
        % Used by getsymbols() to filter out functions and by validate_symbol_name() to reject reserved names
        RESERVED_NAMES = {'log', 'log10', 'ln', 'exp', 'sqrt', 'cbrt', 'abs', 'sign', ...
                          'sin', 'cos', 'tan', 'asin', 'acos', 'atan', ...
                          'sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh', ...
                          'min', 'max', 'normcdf', 'normpdf', 'erf', ...
                          'diff', 'adl', 'EXPECTATIONS', 'STEADY_STATE'}
    end

    properties (Access = private)
        % Symbol lookup map for O(1) type checking: symbol_name -> struct(type, idx)
        % Updated automatically by update_symbol_map() after structural changes
        % Provides significant performance improvement over linear search
        symbol_map = []
    end


    methods (Access = private)

        function o = update_symbol_map(o)
        % Update the symbol lookup map for O(1) type checking
        %
        % INPUTS:
        % - o   [modBuilder]
        %
        % OUTPUTS:
        % - o   [modBuilder]   updated object with populated symbol_map
        %
        % REMARKS:
        % - Creates a containers.Map for O(1) symbol type lookup
        % - Called automatically after structural changes
        % - Maps symbol_name -> struct('type', <type>, 'idx', <index>)
        % - Significantly faster than linear search through params/varexo/var arrays

            % Initialize empty map if it doesn't exist or is empty
            if isempty(o.symbol_map) || ~isa(o.symbol_map, 'containers.Map')
                o.symbol_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
            else
                % Clear existing map
                remove(o.symbol_map, keys(o.symbol_map));
            end

            % Add all parameters
            for i=1:size(o.params, 1)
                o.symbol_map(o.params{i, modBuilder.COL_NAME}) = ...
                    struct('type', 'parameter', 'idx', i);
            end

            % Add all exogenous variables
            for i=1:size(o.varexo, 1)
                o.symbol_map(o.varexo{i, modBuilder.COL_NAME}) = ...
                    struct('type', 'exogenous', 'idx', i);
            end

            % Add all endogenous variables
            for i=1:size(o.var, 1)
                o.symbol_map(o.var{i, modBuilder.COL_NAME}) = ...
                    struct('type', 'endogenous', 'idx', i);
            end
        end

        function o = handle_implicit_loops(o, symbol_name, symbol_type, varargin)
        % Generic handler for symbols with implicit loops (indices like $1, $2)
        %
        % INPUTS:
        % - o            [modBuilder]
        % - symbol_name  [char]        Symbol name with indices (e.g., 'beta_$1_$2')
        % - symbol_type  [char]        'parameter', 'exogenous', or 'endogenous'
        % - varargin     [cell]        Optional calibration value, optional key/value pairs, then index values
        %
        % OUTPUTS:
        % - o            [modBuilder]  Updated object
        %
        % REMARKS:
        % - Extracts common implicit loop logic used by parameter(), exogenous(), and endogenous() methods
        % - Handles parsing of indices, value extraction, and Cartesian product computation
        % - Recursively calls the appropriate method (parameter, exogenous, or endogenous) for each combination
        % - Supports optional 'long_name' and 'texname' attributes with index placeholders
        % - Argument order: [value], ['long_name', val, 'texname', val], index_array_1, ..., index_array_n

            % Find all indices in the symbol name (e.g., $1, $2)
            inames = unique(regexp(symbol_name, '\$\d*', 'match'));
            nindices = numel(inames);

            % Parse varargin to extract: value (optional), key/value pairs (optional), then index arrays
            % The structure is: [value (optional)], ['key', val, ...], index_array_1, ..., index_array_n

            % First, determine if a value is provided
            % Check if first argument is a scalar numeric value (not a cell or char)
            % For endogenous, default to [] to preserve existing values; for others use NaN
            if strcmp(symbol_type, 'endogenous')
                value = [];  % Empty means preserve existing value
            else
                value = NaN;  % Default value for parameter/exogenous
            end
            value_provided = false;
            remaining = varargin;
            if numel(remaining) > 0 && ~iscell(remaining{1}) && ~ischar(remaining{1})
                value = remaining{1};
                value_provided = true;
                remaining = remaining(2:end);
            end

            % Parse key/value pairs (long_name, texname) until we hit a cell array (index array)
            key_val_args = {};
            idx = 1;
            while idx <= numel(remaining)
                if ischar(remaining{idx}) && ismember(remaining{idx}, {'long_name', 'texname'})
                    % This is a key
                    if idx + 1 > numel(remaining)
                        error('Key "%s" provided without a value.', remaining{idx});
                    end
                    key_val_args = [key_val_args, remaining{idx}, remaining{idx+1}];
                    idx = idx + 2;
                elseif iscell(remaining{idx})
                    % Start of index arrays
                    break;
                else
                    error('Unexpected argument type in implicit loop. Expected key/value pair or index array.');
                end
            end

            % Remaining args are index arrays
            index_args = remaining(idx:end);

            % Validate number of index arrays
            if not(isequal(numel(index_args), nindices))
                error('The number of indices in the "%s" name is %u, but values for %u indices are provided.', ...
                      symbol_type, nindices, numel(index_args))
            end

            % Parse optional long_name and texname from key_val_args
            [long_name, texname] = modBuilder.set_optional_fields(symbol_type, symbol_name, key_val_args{:});

            % Validate that long_name and texname have the same number of indices as symbol_name
            if ~isempty(long_name)
                inames_long = unique(regexp(long_name, '\$\d*', 'match'));
                if numel(inames_long) ~= nindices
                    error('long_name has %u indices but %s name has %u indices.', ...
                          numel(inames_long), symbol_type, nindices);
                end
            end
            if ~isempty(texname)
                inames_tex = unique(regexp(texname, '\$\d*', 'match'));
                if numel(inames_tex) ~= nindices
                    error('texname has %u indices but %s name has %u indices.', ...
                          numel(inames_tex), symbol_type, nindices);
                end
            end

            % Check that indices are uniform (all integers or all strings for each index)
            [allint, ~] = modBuilder.check_indices_values(index_args);

            % Compute Cartesian product of index values
            mIndex = table2cell(combinations(index_args{:}));

            % Prepare template for sprintf (replace $1, $2, etc. with %u or %s)
            tmp_name = symbol_name;
            tmp_long_name = long_name;  % May be empty
            tmp_texname = texname;      % May be empty

            % Escape backslashes for sprintf (\ becomes \\) in texname and long_name
            if ~isempty(long_name)
                tmp_long_name = strrep(tmp_long_name, '\', '\\');
            end
            if ~isempty(texname)
                tmp_texname = strrep(tmp_texname, '\', '\\');
            end

            for i=nindices:-1:1
                if allint(i)
                    tmp_name = strrep(tmp_name, sprintf('$%u',i), '%u');
                    if ~isempty(long_name)
                        tmp_long_name = strrep(tmp_long_name, sprintf('$%u',i), '%u');
                    end
                    if ~isempty(texname)
                        tmp_texname = strrep(tmp_texname, sprintf('$%u',i), '%u');
                    end
                else
                    tmp_name = strrep(tmp_name, sprintf('$%u',i), '%s');
                    if ~isempty(long_name)
                        tmp_long_name = strrep(tmp_long_name, sprintf('$%u',i), '%s');
                    end
                    if ~isempty(texname)
                        tmp_texname = strrep(tmp_texname, sprintf('$%u',i), '%s');
                    end
                end
            end

            % Create symbols for all combinations
            for i=1:size(mIndex, 1)
                id = mIndex(i,:);
                name = sprintf(tmp_name, id{:});

                % Build arguments for recursive call
                call_args = {name, value};

                % Add expanded long_name if provided
                if ~isempty(long_name)
                    expanded_long_name = sprintf(tmp_long_name, id{:});
                    call_args = [call_args, {'long_name', expanded_long_name}];
                end

                % Add expanded texname if provided
                if ~isempty(texname)
                    expanded_texname = sprintf(tmp_texname, id{:});
                    call_args = [call_args, {'texname', expanded_texname}];
                end

                % Call the specific method recursively
                switch symbol_type
                    case 'parameter'
                        o = o.parameter(call_args{:});
                    case 'exogenous'
                        o = o.exogenous(call_args{:});
                    case 'endogenous'
                        o = o.endogenous(call_args{:});
                    otherwise
                        error('Unsupported symbol type: "%s".', symbol_type)
                end
            end
        end

        function validate_merge_compatibility(o, p)
        % Validate that two models can be merged
        %
        % INPUTS:
        % - o   [modBuilder]   First model
        % - p   [modBuilder]   Second model
        %
        % OUTPUTS:
        % None (throws error if models cannot be merged)
        %
        % REMARKS:
        % - Models cannot share endogenous variables
        % - Throws descriptive error listing conflicting variables

            commonvariables = intersect(o.var(:,modBuilder.COL_NAME), p.var(:,modBuilder.COL_NAME));
            if ~isempty(commonvariables)
                error('Models to be merged cannot contain common endogenous variables. Check variable(s)%s.', ...
                      sprintf(' %s', commonvariables{:}))
            end
        end

        function q_params = merge_parameters(o, p)
        % Merge parameters from two models
        %
        % INPUTS:
        % - o   [modBuilder]   First model
        % - p   [modBuilder]   Second model
        %
        % OUTPUTS:
        % - q_params   [cell]   n×4 merged parameter table
        %
        % REMARKS:
        % - Common parameters: p's calibration takes precedence if both are calibrated
        % - Uses optimized O(1) index lookups instead of repeated ismember calls

            o_params_list = o.params(:,modBuilder.COL_NAME);
            p_params_list = p.params(:,modBuilder.COL_NAME);
            common_params = intersect(o_params_list, p_params_list);
            o_only_params_list = setdiff(o_params_list, p_params_list);
            p_only_params_list = setdiff(p_params_list, o_params_list);
            q_params = cell(length(o_only_params_list)+length(p_only_params_list)+length(common_params), 4);

            % Create index maps for O(1) lookups instead of repeated O(n) ismember calls
            [~, o_param_idx] = ismember(o_only_params_list, o.params(:,modBuilder.COL_NAME));
            [~, p_param_idx_common] = ismember(common_params, p.params(:,modBuilder.COL_NAME));
            [~, o_param_idx_common] = ismember(common_params, o.params(:,modBuilder.COL_NAME));
            [~, p_param_idx] = ismember(p_only_params_list, p.params(:,modBuilder.COL_NAME));

            i = 1;
            % Copy o-only parameters
            for j=1:length(o_only_params_list)
                idx = o_param_idx(j);
                q_params{i,modBuilder.COL_NAME} = o_only_params_list{j};
                q_params{i,modBuilder.COL_VALUE} = o.params{idx,modBuilder.COL_VALUE};
                q_params{i,modBuilder.COL_LONG_NAME} = o.params{idx,modBuilder.COL_LONG_NAME};
                q_params{i,modBuilder.COL_TEX_NAME} = o.params{idx,modBuilder.COL_TEX_NAME};
                i = i+1;
            end
            % Handle common parameters (p takes precedence if calibrated)
            for j=1:length(common_params)
                p_idx = p_param_idx_common(j);
                o_idx = o_param_idx_common(j);
                q_params{i,modBuilder.COL_NAME} = common_params{j};
                tmp = p.params{p_idx,modBuilder.COL_VALUE};
                if not(isnan(tmp))
                    q_params{i,modBuilder.COL_VALUE} = tmp;
                    q_params{i,modBuilder.COL_LONG_NAME} = p.params{p_idx,modBuilder.COL_LONG_NAME};
                    q_params{i,modBuilder.COL_TEX_NAME} = p.params{p_idx,modBuilder.COL_TEX_NAME};
                else
                    q_params{i,modBuilder.COL_VALUE} = o.params{o_idx,modBuilder.COL_VALUE};
                    q_params{i,modBuilder.COL_LONG_NAME} = o.params{o_idx,modBuilder.COL_LONG_NAME};
                    q_params{i,modBuilder.COL_TEX_NAME} = o.params{o_idx,modBuilder.COL_TEX_NAME};
                end
                i = i+1;
            end
            % Copy p-only parameters
            for j=1:length(p_only_params_list)
                idx = p_param_idx(j);
                q_params{i,modBuilder.COL_NAME} = p_only_params_list{j};
                q_params{i,modBuilder.COL_VALUE} = p.params{idx,modBuilder.COL_VALUE};
                q_params{i,modBuilder.COL_LONG_NAME} = p.params{idx,modBuilder.COL_LONG_NAME};
                q_params{i,modBuilder.COL_TEX_NAME} = p.params{idx,modBuilder.COL_TEX_NAME};
                i = i+1;
            end
        end

        function [q_var, q_varexo] = merge_variables(o, p)
        % Merge endogenous and exogenous variables from two models
        %
        % INPUTS:
        % - o   [modBuilder]   First model
        % - p   [modBuilder]   Second model
        %
        % OUTPUTS:
        % - q_var      [cell]   n×4 merged endogenous variable table
        % - q_varexo   [cell]   m×4 merged exogenous variable table
        %
        % REMARKS:
        % - Exogenous variables in one model can be endogenous in the other
        % - Type conversion handled automatically

            % Merge endogenous variables (simple concatenation)
            q_var = [o.var; p.var];

            % Merge exogenous variables with type conversion
            o_varexo_list = o.varexo(:,modBuilder.COL_NAME);
            p_varexo_list = p.varexo(:,modBuilder.COL_NAME);
            % Set list of exogenous variables, in model o, that will become endogenous when model o is merged with model p.
            o_varexo2var = intersect(o_varexo_list, p.var(:,modBuilder.COL_NAME));
            % Set list of exogenous variables, in model p, that will become endogenous when model p is merged with model o.
            p_varexo2var = intersect(p_varexo_list, o.var(:,modBuilder.COL_NAME));

            % Set list of exogenous variables
            if ~isempty(o_varexo2var)
                ose = ~ismember(o_varexo_list, o_varexo2var); % Select exogenous variables from model o, excluding those that will be endogeneised when merging with model p.
            else
                ose = true(length(o_varexo_list), 1);
            end
            if ~isempty(p_varexo2var)
                pse = ~ismember(p_varexo_list, p_varexo2var); % Select exogenous variables from model p, excluding those that will be endogeneised when merging with model o.
            else
                pse = true(length(p_varexo_list), 1);
            end

            % Identify common exogenous variables (that remain exogenous in both models)
            o_remaining_exo = o_varexo_list(ose);
            p_remaining_exo = p_varexo_list(pse);
            common_exo = intersect(o_remaining_exo, p_remaining_exo);

            % Build merged exogenous list with deduplication
            % Strategy: o-only, p-only, then common (p takes precedence for common)
            o_only_exo = setdiff(o_remaining_exo, common_exo);
            p_only_exo = setdiff(p_remaining_exo, common_exo);
            tmp = [o_only_exo; p_only_exo; common_exo];

            q_varexo = cell(length(tmp), 4);
            q_varexo(:,modBuilder.COL_NAME) = tmp;
            q_varexo(:,modBuilder.COL_VALUE) = {NaN};

            % Create index maps for O(1) lookups (only if non-empty)
            if ~isempty(o_varexo_list)
                o_varexo_map = containers.Map(o_varexo_list, 1:length(o_varexo_list));
            end
            if ~isempty(p_varexo_list)
                p_varexo_map = containers.Map(p_varexo_list, 1:length(p_varexo_list));
            end

            % Fill in values and metadata
            for i = 1:length(tmp)
                varname = tmp{i};

                % Check if this exogenous variable comes from o, p, or both
                in_o = ismember(varname, o_remaining_exo);
                in_p = ismember(varname, p_remaining_exo);

                if in_p
                    % p takes precedence (for common) or is the only source (for p-only)
                    idx = p_varexo_map(varname);
                    q_varexo{i,modBuilder.COL_VALUE} = p.varexo{idx,modBuilder.COL_VALUE};
                    q_varexo{i,modBuilder.COL_LONG_NAME} = p.varexo{idx,modBuilder.COL_LONG_NAME};
                    q_varexo{i,modBuilder.COL_TEX_NAME} = p.varexo{idx,modBuilder.COL_TEX_NAME};
                elseif in_o
                    % o is the only source (o-only variables)
                    idx = o_varexo_map(varname);
                    q_varexo{i,modBuilder.COL_VALUE} = o.varexo{idx,modBuilder.COL_VALUE};
                    q_varexo{i,modBuilder.COL_LONG_NAME} = o.varexo{idx,modBuilder.COL_LONG_NAME};
                    q_varexo{i,modBuilder.COL_TEX_NAME} = o.varexo{idx,modBuilder.COL_TEX_NAME};
                end
            end
        end

        function q = merge_symbol_tables(o, p, q)
        % Merge symbol tables from two models
        %
        % INPUTS:
        % - o   [modBuilder]   First model
        % - p   [modBuilder]   Second model
        % - q   [modBuilder]   Target merged model
        %
        % OUTPUTS:
        % - q   [modBuilder]   Updated model with merged symbol tables
        %
        % REMARKS:
        % - Merges T.params, T.varexo, T.var, T.equations
        % - Removes exogenous variables that became endogenous

            q.T.params = modBuilder.mergeStructs(o.T.params, p.T.params);
            q.T.varexo = modBuilder.mergeStructs(o.T.varexo, p.T.varexo);
            fnames = fields(q.T.varexo);
            remvarexo = not(ismember(fnames, q.varexo(:,modBuilder.COL_NAME)));
            for i=1:length(remvarexo)
                if remvarexo(i)
                    q.T.varexo = rmfield(q.T.varexo, fnames{i});
                end
            end
            q.T.var = modBuilder.mergeStructs(o.T.var, p.T.var);
            q.T.equations = modBuilder.mergeStructs(o.T.equations, p.T.equations);
            q.tags = modBuilder.mergeStructs(o.tags, p.tags);
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

            % Validate type before processing
            modBuilder.validate_type(type);

            switch type
              case 'parameters'
                for i=1:o.size(type)
                    for j=1:o.size('endogenous') % The number of endogenous variables is equal to the number of equations by construction.
                        if any(matches(o.T.equations.(o.equations{j,modBuilder.EQ_COL_NAME}), o.params{i,modBuilder.COL_NAME}))
                            if isfield(o.T.params, o.params{i,modBuilder.COL_NAME})
                                o.T.params.(o.params{i,modBuilder.COL_NAME}) = horzcat(o.T.params.(o.params{i,modBuilder.COL_NAME}), o.equations(j,modBuilder.EQ_COL_NAME));
                            else
                                o.T.params.(o.params{i,modBuilder.COL_NAME}) = o.equations(j,modBuilder.EQ_COL_NAME);
                            end
                        end
                    end
                end
              case 'exogenous'
                for i=1:o.size(type)
                    for j=1:o.size('endogenous')
                        if any(matches(o.T.equations.(o.equations{j,modBuilder.EQ_COL_NAME}), o.varexo{i,modBuilder.COL_NAME}))
                            if isfield(o.T.varexo, o.varexo{i,modBuilder.COL_NAME})
                                o.T.varexo.(o.varexo{i,modBuilder.COL_NAME}) = horzcat(o.T.varexo.(o.varexo{i,modBuilder.COL_NAME}), o.equations(j,modBuilder.EQ_COL_NAME));
                            else
                                o.T.varexo.(o.varexo{i,modBuilder.COL_NAME}) = o.equations(j,modBuilder.EQ_COL_NAME);
                            end
                        end
                    end
                end
              case 'endogenous'
                for i=1:o.size(type)
                    o.T.var.(o.var{i,modBuilder.COL_NAME}) = o.var(i,modBuilder.COL_NAME);
                end
                for i=1:o.size(type)
                    for j=1:o.size(type)
                        if any(matches (o.T.equations.(o.var{j,modBuilder.COL_NAME}), o.var{i,modBuilder.COL_NAME}))
                            o.T.var.(o.var{i,modBuilder.COL_NAME}) = horzcat(o.T.var.(o.var{i,modBuilder.COL_NAME}), o.var(j,modBuilder.COL_NAME));
                        end
                    end
                    o.T.var.(o.var{i,modBuilder.COL_NAME}) = unique(o.T.var.(o.var{i,modBuilder.COL_NAME}));
                end
            end % switch
        end % function

    end % methods


    methods(Static)

        function validate_type(type)
        % Validate that a type string is one of the allowed symbol/component types
        %
        % INPUTS:
        % - type   [char]   Type string to validate
        %
        % OUTPUTS:
        % None (throws error if invalid)
        %
        % REMARKS:
        % - Validates against modBuilder.VALID_TYPES constant
        % - Provides helpful error message listing valid options
        % - Used internally by size(), updatesymboltable(), and other type-checking methods
        % - Can be called by users to validate type strings before use
        %
        % EXAMPLE:
        % modBuilder.validate_type('parameters')  % OK
        % modBuilder.validate_type('vars')        % Error: Unknown type (vars). Valid types are: ...

            if ~ismember(type, modBuilder.VALID_TYPES)
                error('Unknown type (%s). Valid types are: %s', ...
                      type, strjoin(modBuilder.VALID_TYPES, ', '))
            end
        end

        function validate_equation_syntax(equation)
        % Validate equation string syntax for common errors
        %
        % INPUTS:
        % - equation   [char]   Equation string to validate
        %
        % OUTPUTS:
        % None (throws error if issues found)
        %
        % REMARKS:
        % - Checks for balanced parentheses (error if unbalanced)
        % - Checks for invalid operators: ==, ./, ++, --
        % - Called automatically by add() and change() methods
        % - Can be called by users to validate equations before use
        %
        % EXAMPLE:
        % modBuilder.validate_equation_syntax('y = a*y(-1) + b')      % OK
        % modBuilder.validate_equation_syntax('y = a*(y(-1) + b')     % Error: unbalanced parentheses
        % modBuilder.validate_equation_syntax('y == a*y(-1)')         % Error: contains ==

            % Check balanced parentheses
            if sum(equation == '(') ~= sum(equation == ')')
                error('Equation has unbalanced parentheses: "%s".', equation)
            end

            % Check for invalid equality operator
            if contains(equation, '==')
                error('Equation contains "==". Use "=" for assignment. Equation: "%s"', equation)
            end

            % Check for element-wise division (likely unintended)
            if contains(equation, './')
                error('Equation contains "./". Element-wise division is not allowed. Use "/" instead. Equation: "%s"', equation)
            end

            % Warn about potentially unintended operators
            if contains(equation, '++')
                warning('Equation contains "++". This may be unintended. Equation: "%s"', equation)
            end
            if contains(equation, '--')
                warning('Equation contains "--". This may be unintended. Equation: "%s"', equation)
            end
        end

        function validate_symbol_name(sname, method_name)
        % Validate that symbol name is a non-empty string and not a reserved function name
        %
        % INPUTS:
        % - sname         [char]   Symbol name to validate
        % - method_name   [char]   Name of calling method (for error messages)
        %
        % OUTPUTS:
        % None (throws error if validation fails)
        %
        % REMARKS:
        % - Checks that sname is a char array using validateattributes
        % - Checks that sname is non-empty row vector
        % - Checks that sname is not a reserved MATLAB/Dynare function name
        % - Called by add(), parameter(), exogenous(), endogenous(), change() methods
        % - Compatible with both MATLAB and GNU Octave
        %
        % EXAMPLE:
        % modBuilder.validate_symbol_name('alpha', 'parameter')   % OK
        % modBuilder.validate_symbol_name('log', 'parameter')     % Error: reserved name
        % modBuilder.validate_symbol_name('', 'add')              % Error: empty string

            % Validate that sname is a non-empty row char array
            validateattributes(sname, {'char'}, {'nonempty', 'row'}, method_name, 'symbol name');

            % Check for reserved names
            if ismember(sname, modBuilder.RESERVED_NAMES)
                error('%s: Symbol name "%s" is a reserved function name.', method_name, sname);
            end
        end

    end

    methods(Static, Access = private)

        function skipline(n)
        % Print n blank lines to the console
        %
        % INPUTS:
        % - n    [integer]    number of lines to skip (default: 1)
            if ~nargin || isempty(n)
                n = 1;
            end
            for i=1:n, fprintf('\n'), end
        end

        function dprintf(format, varargin)
        % Display formatted output using fprintf and disp combination
        %
        % INPUTS:
        % - format    [char]     format string (same as fprintf)
        % - varargin  [cell]     optional arguments for format string
            if nargin>1
                disp(fprintf(format, varargin{:}));
            else
                disp(fprintf(format));
            end
        end

        function str = printlist(names)
        % Convert a cell array of names to a space-separated string ending with semicolon
        %
        % INPUTS:
        % - names    [cell]    cell array of character arrays (symbol names)
        %
        % OUTPUTS:
        % - str      [char]    formatted string: " name1 name2 name3;"
            str = sprintf(' %s', names{:});
            str = sprintf('%s;', str);
        end

        function printlist2(fid, type, Table)
        % Write formatted variable/parameter declarations to a file with optional metadata
        %
        % INPUTS:
        % - fid      [integer]    file identifier
        % - type     [char]       'endogenous', 'parameters', or 'exogenous'
        % - Table    [cell]       n×4 array with name, value, long_name, tex_name

            % Validate type (printlist2 only supports these three types)
            valid_printlist_types = {'endogenous', 'parameters', 'exogenous'};
            if ~ismember(type, valid_printlist_types)
                error('printlist2: Unknown type (%s). Valid types are: %s', ...
                      type, strjoin(valid_printlist_types, ', '));
            end

            % Map type to Dynare keyword
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
            % Filter out reserved functions and operators
            tokens(cellfun(@(x) ismember(x, modBuilder.RESERVED_NAMES), tokens)) = [];
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
        % Parse optional 'long_name' and 'texname' arguments from varargin
        %
        % INPUTS:
        % - type        [char]     symbol type ('parameter', 'endogenous', or 'exogenous')
        % - sname       [char]     symbol name
        % - varargin    [cell]     key/value pairs (e.g., 'long_name', 'Some Name', 'texname', '\alpha')
        %
        % OUTPUTS:
        % - long_name   [char]     long name or empty string
        % - texname     [char]     TeX name or empty string
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

        function C = replaceincell(C, oldword, newword)
        % Replace all occurrences of oldword with newword in a cell array
        %
        % INPUTS:
        % - C          [cell]    cell array of character arrays
        % - oldword    [char]    string to find
        % - newword    [char]    replacement string
        %
        % OUTPUTS:
        % - C          [cell]    updated cell array
            s = strcmp(oldword, C);
            if any(s)
                C{strcmp(oldword, C)} = newword;
            end
        end

        function [allint, allstr] = check_indices_values(IndicesValues)
        % Validate that index values are uniformly typed (all integers or all strings)
        %
        % INPUTS:
        % - IndicesValues    [cell]    cell array of cell arrays containing index values
        %
        % OUTPUTS:
        % - allint          [logical]    n×1 array, true if index i is all integers
        % - allstr          [logical]    n×1 array, true if index i is all strings
        %
        % REMARKS:
        % Used for implicit loop validation. Each index must have uniform type.
            isint = @(x) isnumeric(x) && rem(x, 1)==0;
            allint = false(numel(IndicesValues), 1);
            allstr = false(numel(IndicesValues), 1);
            for i=1:numel(IndicesValues)
                if iscell(IndicesValues{i})
                    if isvector(IndicesValues{i})
                        allstr(i) = all(cellfun(@ischar, IndicesValues{i}));
                        allint(i) = all(cellfun(isint, IndicesValues{i}));
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
        % Constructor for modBuilder class
        %
        % USAGE:
        % - o = modBuilder()                          Create empty model
        % - o = modBuilder(datetime_obj)              Create empty model with specific date
        % - o = modBuilder(M_, oo_, jsonfile)         Load from Dynare structures and JSON
        % - o = modBuilder(M_, oo_, jsonfile, tag)    Load with custom equation tag name
        %
        % INPUTS:
        % - varargin{1}    [datetime or struct]    date or M_ structure from Dynare
        % - varargin{2}    [struct]                oo_ structure from Dynare (if loading)
        % - varargin{3}    [char]                  path to JSON file with equations
        % - varargin{4}    [char]                  equation tag name (default: 'name')
        %
        % OUTPUTS:
        % - o              [modBuilder]            new modBuilder object
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
                o.params(:,modBuilder.COL_NAME) = M_.param_names;
                o.params(:,modBuilder.COL_VALUE) = num2cell(M_.params);
                for i=1:n
                    if isequal(M_.param_names{i}, M_.param_names_long{i})
                        o.params{i,modBuilder.COL_LONG_NAME} = '';
                    else
                        o.params{i,modBuilder.COL_LONG_NAME} = M_.param_names_long{i};
                    end
                    if isequal(M_.param_names{i}, M_.param_names_tex{i})
                        o.params{i,modBuilder.COL_TEX_NAME} = '';
                    else
                        o.params{i,modBuilder.COL_TEX_NAME} = M_.param_names_tex{i};
                    end
                end
                %
                % Load exogenous variables
                %
                n = length(M_.exo_names);
                o.varexo = cell(n, 4);
                o.varexo(:,modBuilder.COL_NAME) = M_.exo_names;
                o.varexo(:,modBuilder.COL_VALUE) = num2cell(oo_.exo_steady_state);
                for i=1:n
                    if isequal(M_.exo_names{i}, M_.exo_names_long{i})
                        o.varexo{i,modBuilder.COL_LONG_NAME} = '';
                    else
                        o.varexo{i,modBuilder.COL_LONG_NAME} = M_.exo_names_long{i};
                    end
                    if isequal(M_.exo_names{i}, M_.exo_names_tex{i})
                        o.varexo{i,modBuilder.COL_TEX_NAME} = '';
                    else
                        o.varexo{i,modBuilder.COL_TEX_NAME} = M_.exo_names_tex{i};
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
                    o.equations{i,modBuilder.EQ_COL_EXPR} = sprintf('%s = %s', equation.lhs, equation.rhs);
                    if ismember(equation.tags.(equationtagname), M_.endo_names)
                        o.var{i,modBuilder.COL_NAME} = char(equation.tags.(equationtagname));
                        o.equations{i,modBuilder.EQ_COL_NAME} = o.var{i,modBuilder.COL_NAME};
                        id = strcmp(equation.tags.((equationtagname)), M_.endo_names);
                        o.var{i,modBuilder.COL_VALUE} = oo_.steady_state(id);
                        if isequal(o.var{i,modBuilder.COL_NAME}, M_.endo_names_long{id})
                            o.var{i,modBuilder.COL_LONG_NAME} = '';
                        else
                            o.var{i,modBuilder.COL_LONG_NAME} = M_.endo_names_long{id};
                        end
                        if isequal(o.var{i,modBuilder.COL_NAME}, M_.endo_names_tex{id})
                            o.var{i,modBuilder.COL_TEX_NAME} = '';
                        else
                            o.var{i,modBuilder.COL_TEX_NAME} = M_.endo_names_tex{id};
                        end
                        o.T.equations.(equation.tags.((equationtagname))) = modBuilder.getsymbols(o.equations{i,modBuilder.EQ_COL_EXPR});
                        o.symbols = unique(horzcat(o.symbols, o.T.equations.(equation.tags.((equationtagname)))));
                        o.T.equations.(equation.tags.(equationtagname)) = setdiff(o.T.equations.(equation.tags.((equationtagname))), equation.tags.((equationtagname)));
                        o.tags.(o.var{i,modBuilder.COL_NAME}).name = o.var{i,modBuilder.COL_NAME};
                        % Do we need to populate o.tags with other equation tags?
                        FieldNames = setdiff(fieldnames(o.tags.(o.var{i,modBuilder.COL_NAME})), {equationtagname, 'name'});
                        % Equation tag name cannot be used if fourth argument is used.
                        for j=1:numel(FieldNames)
                            o.tags.(o.var{i,modBuilder.COL_NAME}).(FieldNames{j}) = char(equation.tags.(FieldNames{j}));
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
                listofsymbols = union(listofsymbols, o.getsymbols(o.equations{i,modBuilder.EQ_COL_EXPR}));
            end
        end

        function  n = size(o, type)
        % Return the number of parameters, endogenous variables, exogenous variables, or equations
        %
        % INPUTS:
        % - o      [modBuilder]
        % - type   [char]           type of symbol: 'parameters', 'exogenous', 'endogenous', or 'equations'
        %
        % OUTPUTS:
        % - n      [integer]        scalar, number of elements of the specified type

            % Validate type before processing
            modBuilder.validate_type(type);

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
        %
        % EXAMPLES:
        % % Simple equation
        % m = modBuilder();
        % m.add('c', 'c = w*h');
        %
        % % Equation with lags and leads
        % m.add('k', 'k = (1-delta)*k(-1) + i');
        % m.add('r', '1/beta = (c/c(+1))*(r(+1)+1-delta)');
        %
        % % With implicit loops
        % m.add('x_$1', 'x_$1 = alpha_$1 * y', {1, 2, 3});
        % % Creates: x_1 = alpha_1 * y
        % %          x_2 = alpha_2 * y
        % %          x_3 = alpha_3 * y

            % Validate inputs
            validateattributes(varname, {'char'}, {'nonempty', 'row'}, 'add', 'varname');
            validateattributes(equation, {'char'}, {'nonempty', 'row'}, 'add', 'equation');

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
                [allint, allstr] = modBuilder.check_indices_values(varargin);
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
        % Add an equation to the model and associate an endogenous variable (internal method)
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         name of an endogenous variable
        % - equation    [char]         equation expression
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object (with new equation)
        %
        % REMARKS:
        % - This is the core equation-adding method called by add()
        % - Automatically extracts symbols from the equation
        % - Updates the symbol table T.equations
        % - Creates equation tag with 'name' field
        % - If varname was previously exogenous, it becomes endogenous
        % - Validates equation syntax (parentheses balance, no ==, no ./, etc.)

            % Validate equation syntax
            modBuilder.validate_equation_syntax(equation)

            % Validate symbol name (checks for non-empty char and reserved names)
            modBuilder.validate_symbol_name(varname, 'add')

            if any(ismember(o.equations(:,modBuilder.EQ_COL_NAME), varname))
                error('Variable "%s" already has an equation. Use the change method if you really want to redefine the equation for "%s".', varname, varname)
            end
            id = size(o.equations, 1)+1;
            o.equations{id,modBuilder.EQ_COL_NAME} = varname;
            o.equations{id,modBuilder.EQ_COL_EXPR} = equation;
            o.var{id,modBuilder.COL_NAME} = varname;
            o.var{id,modBuilder.COL_VALUE} = NaN;
            id = strcmp(varname, o.varexo(:,modBuilder.COL_NAME));
            if any(id)
                % The new equation is introducing an endogenous variable replacing an exogenous variable.
                o.varexo(id,:) = [];
            end
            o.T.equations.(varname) = modBuilder.getsymbols(equation);
            o.symbols = horzcat(o.symbols, o.T.equations.(varname));
            o.T.equations.(varname) = setdiff(o.T.equations.(varname), varname);
            o.symbols = setdiff(o.symbols, o.var(:,modBuilder.COL_NAME));
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

        function o = parameter(o, pname, varargin)
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
        %   equal to pvalue, otherwise the parameter is calibrated with the value of the exogeous variable.
        % - Optional arguments in varargin must come by key/value pairs. Allowed keys are 'long_name' and 'texname'.
        % - If pname contains indices (e.g. 'beta_$1_$2'), then parameters are defined for all combinations of values provided
        %   as cell arrays of index values at the end of varargin.
        % - If pname contains indices, pvalue can be provided as the first argument in varargin. If pvalue is not provided, the parameters
        %   are created with default value NaN.
        % - If implicit loops are used (pname contains indices), optional attributes (long_name, texname) should be provided as
        %   key/value pairs before the index value arrays.
        % - If implicit loops are used (pname contains indices), the number of index value arrays must match the number of indices in pname.
        % - If implicit loops are used (pname contains indices), all values provided for a given index must be of the same type
        %   (all char or all integer).
        % - If implicit loops are used with long_name or texname, these must contain the same number of index placeholders ($1, $2, etc.)
        %   as the parameter name. The placeholders will be expanded for each combination.
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k');
        %
        % % Calibrate a parameter
        % m.parameter('alpha', 0.33);
        %
        % % Declare uncalibrated parameter
        % m.parameter('beta');  % value will be NaN
        %
        % % With long name and TeX name
        % m.parameter('rho', 0.95, 'long_name', 'Persistence', 'texname', '\rho');
        %
        % % Implicit loops - create multiple parameters
        % m.parameter('gamma_$1', 0.5, {1, 2, 3});
        % % Creates: gamma_1=0.5, gamma_2=0.5, gamma_3=0.5
        %
        % % Implicit loops with TeX names (note: texname comes before index array)
        % m.parameter('alpha_$1', 0.33, 'texname', '\alpha_{$1}', {1, 2, 3});
        % % Creates: alpha_1, alpha_2, alpha_3 with TeX names \alpha_{1}, \alpha_{2}, \alpha_{3}
        %
        % % Multiple indices with TeX formatting (note: key/value pairs before index arrays)
        % Countries = {'FR', 'DE', 'IT'};
        % Sectors = {1, 2};
        % m.parameter('rho_$1_$2', 0.9, ...
        %             'long_name', 'Persistence for $1 sector $2', ...
        %             'texname', '\rho_{$1,$2}', ...
        %             Countries, Sectors);
        % % Creates: rho_FR_1, rho_FR_2, rho_DE_1, ... with appropriate TeX names
            % Validate that pname is a non-empty row char array
            validateattributes(pname, {'char'}, {'nonempty', 'row'}, 'parameter', 'pname');

            % Check if parameter name contains implicit loop indices (e.g., 'beta_$1_$2')
            inames = unique(regexp(pname, '\$\d*', 'match'));
            if not(isempty(inames))
                % Delegate to common implicit loop handler
                o = o.handle_implicit_loops(pname, 'parameter', varargin{:});
            else
                % Validate symbol name for reserved names (only for non-template names)
                modBuilder.validate_symbol_name(pname, 'parameter')
                if ~(ismember(pname, o.symbols) || ismember(pname, o.varexo(:,modBuilder.COL_NAME)) || ismember(pname, o.params(:,modBuilder.COL_NAME)))
                    if ismember(pname, o.var(:,modBuilder.COL_NAME))
                        error('An endogenous variable cannot be converted into a parameter.')
                    else
                        error('Symbol "%s" does not appear in the model.', pname)
                    end
                end
                if nargin<3 || isempty(varargin{1})
                    % Set default value
                    pvalue = NaN;
                else
                    pvalue = varargin{1};
                end
                [long_name, texname] = modBuilder.set_optional_fields('parameter', pname, varargin{2:end});
                idp = ismember(o.params(:,modBuilder.COL_NAME), pname);
                if any(idp) % The parameter is already defined
                    o.params{idp, modBuilder.COL_VALUE} = pvalue;
                    if not(isempty(long_name))
                        o.params{idp,modBuilder.COL_LONG_NAME} = long_name;
                    end
                    if not(isempty(texname))
                        o.params{idp,modBuilder.COL_TEX_NAME} = texname;
                    end
                else
                    idx = ismember(o.varexo(:,modBuilder.COL_NAME), pname);
                    if any(idx)
                        % pname is an exogenous variable, we change its type to parameter.
                        o.params(length(idp)+1,:) = o.varexo(idx,:);
                        o.varexo(idx,:) = [];
                        if not(isnan(pvalue))
                            o.params{length(idp)+1,modBuilder.COL_VALUE} = pvalue;
                        end
                        if not(isempty(long_name))
                            o.params{length(idp)+1,modBuilder.COL_LONG_NAME} = long_name;
                        end
                        if not(isempty(texname))
                            o.params{length(idp)+1,modBuilder.COL_TEX_NAME} = texname;
                        end
                    else
                        % Symbol pname has no predefined type.
                        o.params{length(idp)+1,modBuilder.COL_NAME} = pname;
                        o.params{length(idp)+1,modBuilder.COL_VALUE} = pvalue;
                        o.params{length(idp)+1,modBuilder.COL_LONG_NAME} = long_name;
                        o.params{length(idp)+1,modBuilder.COL_TEX_NAME} = texname;
                    end
                end
                % Remove pname from the list of untyped symbols
                o.symbols = setdiff(o.symbols, pname);
            end
        end % function

        function o = exogenous(o, xname, varargin)
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
        % Same remarks as for method parameter, with obvious changes for exogenous variables.
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('y', 'y = a + epsilon');
        % m.parameter('a', 1.5);
        %
        % % Declare exogenous variable with default value
        % m.exogenous('epsilon', 0);
        %
        % % Declare without setting value (defaults to NaN)
        % m.exogenous('u');
        %
        % % With long name and TeX name
        % m.exogenous('e', 0, 'long_name', 'Technology shock', 'texname', '\varepsilon');
        %
        % % Implicit loops with TeX names (note: texname comes before index array)
        % m.exogenous('A_$1', 1.0, 'texname', 'A^{$1}', {'FR', 'DE', 'IT'});
        % % Creates: A_FR, A_DE, A_IT with TeX names A^{FR}, A^{DE}, A^{IT}
        %
        % % Multiple indices with TeX formatting (note: key/value pairs before index arrays)
        % Countries = {'FR', 'DE'};
        % Sectors = {1, 2, 3};
        % m.exogenous('K_$1_$2', 1.0, ...
        %             'long_name', 'Capital in $1 sector $2', ...
        %             'texname', 'K^{$1}_{$2}', ...
        %             Countries, Sectors);
        % % Creates: K_FR_1, K_FR_2, K_FR_3, K_DE_1, ... with appropriate TeX names
            % Validate that xname is a non-empty row char array
            validateattributes(xname, {'char'}, {'nonempty', 'row'}, 'exogenous', 'xname');

            % Check if exogenous name contains implicit loop indices (e.g., 'epsilon_$1_$2')
            inames = unique(regexp(xname, '\$\d*', 'match'));
            if not(isempty(inames))
                % Delegate to common implicit loop handler
                o = o.handle_implicit_loops(xname, 'exogenous', varargin{:});
            else
                % Validate symbol name for reserved names (only for non-template names)
                modBuilder.validate_symbol_name(xname, 'exogenous')
                if ~(ismember(xname, o.symbols) || ismember(xname, o.varexo(:,modBuilder.COL_NAME)) || ismember(xname, o.params(:,modBuilder.COL_NAME)))
                    if ismember(xname, o.var(:,modBuilder.COL_NAME))
                        error('An endogenous variable cannot be converted into an exogenous variable. Please remove the equation associated to the endogenous variable.')
                    else
                        error('Symbol "%s" does not appear in the model.', xname)
                    end
                end
                if nargin<3 || isempty(varargin{1})
                    % Set default value
                    xvalue = NaN;
                else
                    xvalue = varargin{1};
                end
                [long_name, texname] = modBuilder.set_optional_fields('exogenous', xname, varargin{2:end});
                idx = ismember(o.varexo(:,modBuilder.COL_NAME), xname);
                if any(idx) % The exogenous variable is already defined
                    o.varexo{idx,modBuilder.COL_VALUE} = xvalue;
                    if not(isempty(long_name))
                        o.varexo{idx,modBuilder.COL_LONG_NAME} = long_name;
                    end
                    if not(isempty(texname))
                        o.varexo{idx,modBuilder.COL_TEX_NAME} = texname;
                    end
                else
                    idp = ismember(o.params(:,modBuilder.COL_NAME), xname);
                    if any(idp)
                        % pname is a parameter, we change its type to exogenous variable.
                        o.varexo(length(idx)+1,:) = o.params(idp,:);
                        o.params(idp,:) = [];
                        if not(isnan(xvalue))
                            o.varexo{length(idx)+1,modBuilder.COL_VALUE} = xvalue;
                        end
                        if not(isempty(long_name))
                            o.varexo{length(idx)+1,modBuilder.COL_LONG_NAME} = long_name;
                        end
                        if not(isempty(texname))
                            o.varexo{length(idx)+1,modBuilder.COL_TEX_NAME} = texname;
                        end
                    else
                        o.varexo{length(idx)+1,modBuilder.COL_NAME} = xname;
                        o.varexo{length(idx)+1,modBuilder.COL_VALUE} = xvalue;
                        o.varexo{length(idx)+1,modBuilder.COL_LONG_NAME} = long_name;
                        o.varexo{length(idx)+1,modBuilder.COL_TEX_NAME} = texname;
                    end
                end
                % Remove xname from the list of untyped symbols
                o.symbols = setdiff(o.symbols, xname);
            end
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
        % - If ename contains indices (e.g. 'y_$1_$2'), then endogenous variables are set for all combinations of values provided
        %   as cell arrays of index values at the end of varargin.
        % - If ename contains indices, evalue can be provided as the second argument. If evalue is not provided or is empty,
        %   existing values are preserved (or NaN if not set).
        % - If implicit loops are used (ename contains indices), optional attributes (long_name, texname) should be provided as
        %   key/value pairs before the index value arrays.
        % - If implicit loops are used (ename contains indices), the number of index value arrays must match the number of indices in ename.
        % - If implicit loops are used (ename contains indices), all values provided for a given index must be of the same type
        %   (all char or all integer).
        % - If implicit loops are used with long_name or texname, these must contain the same number of index placeholders ($1, $2, etc.)
        %   as the endogenous variable name. The placeholders will be expanded for each combination.
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k');
        %
        % % Set value for endogenous variable
        % m.endogenous('c', 1.5);
        %
        % % With long name and TeX name
        % m.endogenous('c', 1.5, 'long_name', 'Consumption', 'texname', 'C');
        %
        % % Implicit loops - set values for multiple endogenous variables
        % m.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
        % m.exogenous('A_$1', 1.0, {1, 2, 3});
        % m.exogenous('K_$1', 1.0, {1, 2, 3});
        % m.endogenous('Y_$1', 2.0, {1, 2, 3});
        % % Sets: Y_1=2.0, Y_2=2.0, Y_3=2.0
        %
        % % Implicit loops with TeX names (note: texname comes before index array)
        % m.add('C_$1', 'C_$1 = Y_$1 - I_$1', {'FR', 'DE', 'IT'});
        % m.exogenous('I_$1', 0.2, {'FR', 'DE', 'IT'});
        % m.endogenous('Y_$1', 1.0, {'FR', 'DE', 'IT'});
        % m.endogenous('C_$1', 0.8, 'texname', 'C^{$1}', {'FR', 'DE', 'IT'});
        % % Creates: C_FR, C_DE, C_IT with TeX names C^{FR}, C^{DE}, C^{IT}
        %
        % % Multiple indices with TeX formatting (note: key/value pairs before index arrays)
        % Countries = {'FR', 'DE'};
        % Sectors = {1, 2};
        % m.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
        % m.exogenous('A_$1_$2', 1.0, Countries, Sectors);
        % m.exogenous('K_$1_$2', 1.0, Countries, Sectors);
        % m.endogenous('Y_$1_$2', 1.0, ...
        %              'long_name', 'Output for $1 sector $2', ...
        %              'texname', 'Y_{$1,$2}', ...
        %              Countries, Sectors);
        % % Sets values and attributes for: Y_FR_1, Y_FR_2, Y_DE_1, Y_DE_2
            % Validate that ename is a non-empty row char array
            validateattributes(ename, {'char'}, {'nonempty', 'row'}, 'endogenous', 'ename');

            % Check if endogenous name contains implicit loop indices (e.g., 'y_$1_$2')
            inames = unique(regexp(ename, '\$\d*', 'match'));
            if not(isempty(inames))
                % Delegate to common implicit loop handler
                if nargin < 3 || isempty(evalue)
                    % No value provided
                    o = o.handle_implicit_loops(ename, 'endogenous', varargin{:});
                else
                    % Value provided
                    o = o.handle_implicit_loops(ename, 'endogenous', evalue, varargin{:});
                end
            else
                % Validate symbol name for reserved names (only for non-template names)
                modBuilder.validate_symbol_name(ename, 'endogenous')

                % Check that ename is defined as an endogenous variable (has an equation)
                if ~ismember(ename, o.equations(:,modBuilder.EQ_COL_NAME))
                    error('Symbol "%s" is not an endogenous variable.', ename)
                end

                if nargin<3 || isempty(evalue)
                    if isempty(o.var(ismember(o.var(:,modBuilder.COL_NAME), ename), modBuilder.COL_VALUE))
                        % Set default value
                        evalue = NaN;
                    else
                        % Endogenous variable already has a value (long run level), keep it.
                        evalue = o.var{ismember(o.var(:,modBuilder.COL_NAME), ename), modBuilder.COL_VALUE};
                    end
                end

                [long_name, texname] = modBuilder.set_optional_fields('endogenous', ename, varargin{:});
                ide = ismember(o.var(:,modBuilder.COL_NAME), ename);
                if any(ide) % The endogenous variable is already defined
                    o.var{ide,modBuilder.COL_VALUE} = evalue;
                    if not(isempty(long_name))
                        o.var{ide,modBuilder.COL_LONG_NAME} = long_name;
                    end
                    if not(isempty(texname))
                        o.var{ide,modBuilder.COL_TEX_NAME} = texname;
                    end
                else
                    o.var{length(ide)+1,modBuilder.COL_NAME} = ename;
                    o.var{length(ide)+1,modBuilder.COL_VALUE} = evalue;
                    o.var{length(ide)+1,modBuilder.COL_LONG_NAME} = long_name;
                    o.var{length(ide)+1,modBuilder.COL_TEX_NAME} = texname;
                end
                % Remove ename from the list of untyped symbols
                o.symbols = setdiff(o.symbols, ename);
            end
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
        %
        % REMARKS:
        % - Clears symbol_map to force typeof() to use linear search during removals
        % - This prevents stale index references after deletions
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = w*h');
        % m.add('y', 'y = c + i');
        % m.parameter('w', 1.5);
        %
        % % Remove the consumption equation
        % m.remove('c');  % Also removes h if it doesn't appear elsewhere

            % Clear symbol_map so typeof() uses linear search (safe during deletions)
            o.symbol_map = [];

            ide = ismember(o.equations(:,modBuilder.EQ_COL_NAME), eqname);
            if not(any(ide))
                error('Unknown equation "%s".', eqname)
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
            % Check if eqname exists in T.var before accessing (might not if tables not fully initialized)
            if isfield(o.T.var, eqname)
                o.T.var.(eqname) = setdiff(o.T.var.(eqname), eqname); % Remove reference to the equation defining eqname.
                if not(isempty(o.T.var.(eqname)))
                    % If the variable eqname is referenced in another equation, it must be converted to an exogenous variable.
                    o.varexo = [o.varexo; o.var(ismember(o.var(:,modBuilder.COL_NAME), eqname),:)];
                    o.T.varexo.(eqname) = o.T.var.(eqname);
                    o.T.var = rmfield(o.T.var, eqname);
                end
            end
            o.var(ismember(o.var(:,modBuilder.COL_NAME), eqname),:) = [];
            o.updatesymboltables();
        end % function

        function o = rm(o, varargin)
        % Remove multiple equations from the model in one call
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqname1    [char]            name of an equation (endogenous variable)
        % - eqname2    [char]            name of another equation
        % - …          [char]            additional equation names
        %
        % OUTPUTS:
        % - o          [modBuilder]      updated object
        %
        % REMARKS:
        % - This is a convenience method that calls remove() for each equation
        % - Duplicate equation names are handled automatically
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
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k');
        % m.parameter('alpha', 0.33);
        %
        % % Rename parameter
        % m.rename('alpha', 'beta');
        %
        % % Rename endogenous variable
        % m.rename('c', 'consumption');
            [type, id] = o.typeof(oldsymbol);
            switch type
              case 'parameter'
                o.params{id,modBuilder.COL_NAME} = newsymbol;
                o.T.params.(newsymbol) = o.T.params.(oldsymbol);
                o.T.params = rmfield(o.T.params, oldsymbol);
              case 'exogenous'
                o.varexo{id,modBuilder.COL_NAME} = newsymbol;
                o.T.varexo.(newsymbol) = o.T.varexo.(oldsymbol);
                o.T.varexo = rmfield(o.T.varexo, oldsymbol);
              case 'endogenous'
                o.var{id,modBuilder.COL_NAME} = newsymbol;
                o.equations{strcmp(oldsymbol, o.equations(:,modBuilder.EQ_COL_NAME)),modBuilder.EQ_COL_NAME} = newsymbol;
                o.T.var.(newsymbol) = o.T.var.(oldsymbol);
                o.T.var = rmfield(o.T.var, oldsymbol);
                o.T.equations.(newsymbol) = o.T.equations.(oldsymbol);
                o.T.equations = rmfield(o.T.equations, oldsymbol);
                o.tags.(newsymbol) = o.tags.(oldsymbol);
                o.tags = rmfield(o.tags, oldsymbol);
                o.tags.(newsymbol).name = newsymbol;
                for i=1:o.size('parameters')
                    o.T.params.(o.params{i,modBuilder.COL_NAME}) = modBuilder.replaceincell(o.T.params.(o.params{i,modBuilder.COL_NAME}), oldsymbol, newsymbol);
                end
                for i=1:o.size('exogenous')
                    o.T.varexo.(o.varexo{i,modBuilder.COL_NAME}) = modBuilder.replaceincell(o.T.varexo.(o.varexo{i,modBuilder.COL_NAME}), oldsymbol, newsymbol);
                end
                for i=1:o.size('endogenous')
                    o.T.var.(o.var{i,modBuilder.COL_NAME}) = modBuilder.replaceincell(o.T.var.(o.var{i,modBuilder.COL_NAME}), oldsymbol, newsymbol);
                end
            end
            for i=1:o.size('equations')
                o.equations{i,modBuilder.EQ_COL_EXPR} = regexprep(o.equations{i,modBuilder.EQ_COL_EXPR}, ['(?<!\w)' oldsymbol  '(?!\w)'], newsymbol);
                o.T.equations.(o.equations{i,modBuilder.EQ_COL_NAME}) = modBuilder.replaceincell(o.T.equations.(o.equations{i,modBuilder.EQ_COL_NAME}), oldsymbol, newsymbol);
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
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k');
        % m.parameter('alpha', 0.33);
        %
        % % Write to file 'mymodel.mod'
        % m.write('mymodel');
            fid = fopen(sprintf('%s.mod', basename), 'w');
            %
            % Print list of endogenous variables
            %
            if all(cellfun(@(x) isempty(x), o.var(:,modBuilder.COL_LONG_NAME))) && all(cellfun(@(x) isempty(x), o.var(:,modBuilder.COL_TEX_NAME)))
                fprintf(fid, 'var%s\n\n', modBuilder.printlist(o.var(:,modBuilder.COL_NAME)));
            else
                modBuilder.printlist2(fid, 'endogenous', o.var);
            end
            %
            % Print list of exogenous variables
            %
            if all(cellfun(@(x) isempty(x), o.varexo(:,modBuilder.COL_LONG_NAME))) && all(cellfun(@(x) isempty(x), o.varexo(:,modBuilder.COL_TEX_NAME)))
                fprintf(fid, 'varexo%s\n\n', modBuilder.printlist(o.varexo(:,modBuilder.COL_NAME)));
            else
                modBuilder.printlist2(fid, 'exogenous', o.varexo);
            end
            %
            % Print list of fprintf
            %
            if all(cellfun(@(x) isempty(x), o.params(:,modBuilder.COL_LONG_NAME))) && all(cellfun(@(x) isempty(x), o.params(:,modBuilder.COL_TEX_NAME)))
                fprintf(fid, 'parameters%s\n\n', modBuilder.printlist(o.params(:,modBuilder.COL_NAME)));
            else
                modBuilder.printlist2(fid, 'parameters', o.params);
            end
            %
            % Print calibration if any
            %
            % Find all calibrated parameters at once (vectorized operation)
            calibrated_idx = ~cellfun(@isnan, o.params(:, modBuilder.COL_VALUE));
            calibrated_params = o.params(calibrated_idx, :);
            % Write in batch
            for i=1:size(calibrated_params, 1)
                fprintf(fid, '%s = %f;\n', ...
                        calibrated_params{i, modBuilder.COL_NAME}, ...
                        calibrated_params{i, modBuilder.COL_VALUE});
            end
            fprintf(fid, '\n');
            %
            % Print model block
            %
            fprintf(fid, 'model;\n\n');
            for i=1:o.size('endogenous')
                Tags = o.tags.(o.equations{i,modBuilder.EQ_COL_NAME});
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
                fprintf(fid, '%s;\n\n', o.equations{i,modBuilder.EQ_COL_EXPR});
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
        % Update fields under o.T using optimized single-pass algorithm
        %
        % INPUTS:
        % - o   [modBuilder]
        %
        % OUTPUTS:
        % - o   [modBuilder]   updated object with populated symbol tables
        %
        % REMARKS:
        % - OPTIMIZED VERSION: O(n×m) complexity instead of O(n²)
        % - Single pass through equations populates all symbol types
        % - Uses containers.Map for O(1) symbol type lookups
        % - Significantly faster for large models (100+ equations)

            % Initialize all symbol tables
            o.T.params = struct();
            o.T.varexo = struct();
            o.T.var = struct();

            % Pre-initialize fields for all known symbols (O(n))
            for i=1:size(o.params, 1)
                o.T.params.(o.params{i, modBuilder.COL_NAME}) = cell(1, 0);
            end
            for i=1:size(o.varexo, 1)
                o.T.varexo.(o.varexo{i, modBuilder.COL_NAME}) = cell(1, 0);
            end
            % For endogenous variables, initialize with the variable itself (its own equation)
            for i=1:size(o.var, 1)
                o.T.var.(o.var{i, modBuilder.COL_NAME}) = o.var(i, modBuilder.COL_NAME);
            end

            % Update symbol map for O(1) lookups
            o = o.update_symbol_map();

            % Single pass through equations (O(n_equations × avg_symbols))
            for j=1:size(o.equations, 1)
                eqname = o.equations{j, modBuilder.EQ_COL_NAME};
                symbols = o.T.equations.(eqname);

                % For each symbol in equation, determine its type and add equation reference
                for k=1:length(symbols)
                    sym = symbols{k};

                    % O(1) lookup instead of O(n) ismember
                    if o.symbol_map.isKey(sym)
                        sym_info = o.symbol_map(sym);
                        switch sym_info.type
                          case 'parameter'
                            o.T.params.(sym){end+1} = eqname;
                          case 'exogenous'
                            o.T.varexo.(sym){end+1} = eqname;
                          case 'endogenous'
                            o.T.var.(sym){end+1} = eqname;
                        end
                    end
                    % Note: symbols not in symbol_map are ignored (could be untyped)
                end
            end

            % Ensure unique entries for endogenous variables
            % (Parameters and exogenous are already unique since each appears once per equation)
            var_names = fieldnames(o.T.var);
            for i=1:length(var_names)
                o.T.var.(var_names{i}) = unique(o.T.var.(var_names{i}));
            end
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
            b = any(ismember(o.params(:,modBuilder.COL_NAME), name));
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
            b = any(ismember(o.varexo(:,modBuilder.COL_NAME), name));
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
            b = any(ismember(o.var(:,modBuilder.COL_NAME), name));
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
        % Return the type of a symbol (optimized with O(1) lookup when symbol_map available)
        %
        % INPUTS:
        % - o        [modBuilder]
        % - name     [char]            1×n array, name of a symbol
        %
        % OUTPUTS:
        % - type     [char]            1×m array, type of the symbol
        % - id       [logical or integer]  Position of symbol in respective array
        %
        % REMARKS:
        % - Uses O(1) hash map lookup when symbol_map is available
        % - Falls back to O(n) linear search if symbol_map is not initialized
        % - Significantly faster for repeated lookups in large models
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k + epsilon');
        % m.parameter('alpha', 0.33);
        % m.exogenous('epsilon', 0);
        %
        % % Check symbol types
        % [type, id] = m.typeof('alpha');    % Returns 'parameter'
        % [type, id] = m.typeof('c');        % Returns 'endogenous'
        % [type, id] = m.typeof('epsilon');  % Returns 'exogenous'

            % Try O(1) lookup first if symbol_map is available
            if ~isempty(o.symbol_map) && isa(o.symbol_map, 'containers.Map') && o.symbol_map.isKey(name)
                sym_info = o.symbol_map(name);
                type = sym_info.type;
                % Convert to logical array for backward compatibility
                switch type
                  case 'parameter'
                    id = false(size(o.params, 1), 1);
                    id(sym_info.idx) = true;
                  case 'exogenous'
                    id = false(size(o.varexo, 1), 1);
                    id(sym_info.idx) = true;
                  case 'endogenous'
                    id = false(size(o.var, 1), 1);
                    id(sym_info.idx) = true;
                end
                return
            end

            % Fallback to O(n) linear search
            id = ismember(o.params(:,modBuilder.COL_NAME), name);
            if any(id)
                type = 'parameter';
                return
            end
            id = ismember(o.varexo(:,modBuilder.COL_NAME), name);
            if any(id)
                type = 'exogenous';
                return
            end
            id = ismember(o.var(:,modBuilder.COL_NAME), name);
            if any(id)
                type = 'endogenous';
                return
            end
            error('Unknown type for symbol "%s".', name)
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
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = w*h');
        % m.add('y', 'y = c + i');
        % m.add('i', 'i = delta*k');
        % m.parameter('w', 1.5);
        % m.parameter('delta', 0.1);
        %
        % % Find all equations containing 'c'
        % m.lookfor('c');
        % % Output: Endogenous variable c appears in 2 equations:
        % %         [c]  c = w*h
        % %         [y]  y = c + i
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
                    equation = o.equations(strcmp(eqnames{i}, o.equations(:,modBuilder.EQ_COL_NAME)),2);
                    modBuilder.skipline()
                    fprintf('[%s]\t\t%s\n', o.tags.(eqnames{i}).name, equation{1});
                end
                modBuilder.skipline()
            end
        end % function


        function o = summary(o)
        % Display a formatted summary of the model
        %
        % INPUTS:
        % - o      [modBuilder]
        %
        % OUTPUTS:
        % - o      [modBuilder]  (returns the object for method chaining)
        %
        % EXAMPLE:
        % m = modBuilder();
        % m.parameter('alpha', 0.33);
        % m.parameter('beta', NaN);
        % m.add('c', 'c = alpha * k');
        % m.summary();
        %
        % EXAMPLE OUTPUT:
        % Model Summary
        % =============
        % Created: 2025-01-15 10:30:00
        %
        % Parameters: 2 (1 calibrated, 1 uncalibrated)
        % Endogenous: 1
        % Exogenous: 0
        % Equations: 1

            fprintf('\nModel Summary\n');
            fprintf('=============\n');
            fprintf('Created: %s\n\n', char(o.date));

            % Count calibrated and uncalibrated parameters
            n_params = o.size('parameters');
            if n_params > 0
                n_params_calibrated = sum(~cellfun(@isnan, o.params(:, modBuilder.COL_VALUE)));
                n_params_uncalibrated = n_params - n_params_calibrated;
                fprintf('Parameters: %d (%d calibrated, %d uncalibrated)\n', ...
                        n_params, n_params_calibrated, n_params_uncalibrated);
            else
                fprintf('Parameters: 0\n');
            end

            fprintf('Endogenous: %d\n', o.size('endogenous'));
            fprintf('Exogenous: %d\n', o.size('exogenous'));
            fprintf('Equations: %d\n', o.size('equations'));

            if ~isempty(o.symbols)
                fprintf('\nWarning: %d untyped symbol(s)\n', length(o.symbols));
            end

            fprintf('\n');
        end


        function tbl = table(o, type)
        % Convert params/varexo/var to MATLAB table for easier viewing
        %
        % INPUTS:
        % - o      [modBuilder]
        % - type   [char]        'parameters', 'exogenous', or 'endogenous'
        %
        % OUTPUTS:
        % - tbl    [table]       MATLAB table with columns: Name, Value, LongName, TeXName
        %
        % EXAMPLE:
        % m = modBuilder();
        % m.parameter('alpha', 0.33, 'Capital share');
        % m.parameter('beta', 0.99);
        % t = m.table('parameters');
        % disp(t);

            % Validate type
            switch type
                case 'parameters'
                    data = o.params;
                case 'exogenous'
                    data = o.varexo;
                case 'endogenous'
                    data = o.var;
                otherwise
                    error('Unknown type: %s. Valid types are: parameters, exogenous, endogenous', type);
            end

            % Convert to MATLAB table
            if isempty(data)
                % Create empty table with correct structure
                tbl = table(categorical([]), [], categorical([]), categorical([]), ...
                           'VariableNames', {'Name', 'Value', 'LongName', 'TeXName'});
            else
                % Extract columns and convert to categorical for clean display (no quotes)
                names = categorical(data(:, modBuilder.COL_NAME));
                values = cell2mat(data(:, modBuilder.COL_VALUE));

                % Process LongName and TeXName, replacing empty with 'NA'
                longnames_cell = cell(size(data, 1), 1);
                texnames_cell = cell(size(data, 1), 1);
                for i = 1:size(data, 1)
                    if isempty(data{i, modBuilder.COL_LONG_NAME})
                        longnames_cell{i} = 'NA';
                    else
                        longnames_cell{i} = data{i, modBuilder.COL_LONG_NAME};
                    end
                    if isempty(data{i, modBuilder.COL_TEX_NAME})
                        texnames_cell{i} = 'NA';
                    else
                        texnames_cell{i} = data{i, modBuilder.COL_TEX_NAME};
                    end
                end
                longnames = categorical(longnames_cell);
                texnames = categorical(texnames_cell);

                tbl = table(names, values, longnames, texnames, ...
                           'VariableNames', {'Name', 'Value', 'LongName', 'TeXName'});
            end
        end


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
            ie = ismember(o.var(:,modBuilder.COL_NAME), varname);
            if not(any(ie))
                error('"%s" is not a known endogenous variable.', varname)
            end
            ix = ismember(o.varexo(:,modBuilder.COL_NAME), varexoname);
            if not(any(ix))
                error('"%s" is not a known exogenous variable.', varexoname)
            end
            % Copy variables
            o.var = [o.var; {varexoname o.varexo{ix,modBuilder.COL_VALUE} o.varexo{ix,modBuilder.COL_LONG_NAME} o.varexo{ix,modBuilder.COL_TEX_NAME}}];
            o.varexo = [o.varexo; {varname o.var{ie,modBuilder.COL_VALUE} o.var{ie,modBuilder.COL_LONG_NAME} o.var{ie,modBuilder.COL_TEX_NAME}}];
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
            o.equations{strcmp(varname, o.equations(:,modBuilder.EQ_COL_NAME)),modBuilder.EQ_COL_NAME} = varexoname;
            % Update tags
            o.tags.(varexoname) = o.tags.(varname);
            o.tags = rmfield(o.tags, varname);
        end % function

        function p = copy(o)
        % Create a deep copy of the modBuilder object
        %
        % INPUTS:
        % - o   [modBuilder]    source object
        %
        % OUTPUTS:
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k');
        % m.parameter('alpha', 0.33);
        %
        % % Create a copy to experiment with
        % m2 = m.copy();
        % m2.change('c', 'c = beta*k');
        % % Original m is unchanged
        % - p   [modBuilder]    independent copy with same content
        %
        % REMARKS:
        % - All properties are copied, including symbol tables
        % - The copy has the same creation date as the original
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
        % Test equality of two modBuilder objects (overloads == operator)
        %
        % INPUTS:
        % - o   [modBuilder]    first object
        % - p   [modBuilder]    second object
        %
        % OUTPUTS:
        % - b   [logical]       true if objects are identical, false otherwise
        %
        % REMARKS:
        % - Compares all properties: params, varexo, var, symbols, equations, tags, and symbol tables
        % - Order of elements does not matter for cell arrays (treated as sets)
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
                if not(isequal(o.tags.(o.equations{i,modBuilder.EQ_COL_NAME}), p.tags.(o.equations{i,modBuilder.EQ_COL_NAME})))
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
        % Replace an existing equation in the model
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         name of the endogenous variable (equation name)
        % - equation    [char]         new equation expression
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object
        %
        % REMARKS:
        % - Raises error if varname has no associated equation
        % - Validates equation syntax (parentheses balance, no ==, no ./, etc.)
        % - Extracts and validates symbols from the new equation
        % - Updates symbol tables automatically
        % - Removes parameters/exogenous variables that no longer appear in any equation
        % - Warns if new equation introduces untyped symbols
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = w*h');
        % m.parameter('w', 1.5);
        %
        % % Replace the equation for c
        % m.change('c', 'c = alpha*k + w*h');
        % m.parameter('alpha', 0.3);

            % Validate inputs
            validateattributes(varname, {'char'}, {'nonempty', 'row'}, 'change', 'varname');
            validateattributes(equation, {'char'}, {'nonempty', 'row'}, 'change', 'equation');

            % Validate equation syntax
            modBuilder.validate_equation_syntax(equation)

            warning('off','backtrace')
            ide = ismember(o.equations(:,modBuilder.EQ_COL_NAME), varname);
            if not(any(ide))
                error('There is no equation for "%s".', varname)
            end
            o.equations{ide,modBuilder.EQ_COL_EXPR} = equation;
            otokens = o.T.equations.(varname);
            ntokens = setdiff(modBuilder.getsymbols(equation), varname);
            o.symbols = [o.symbols, ntokens];
            % Remove symbols that are already known. If o.symbols is empty, it indicates that the updated equation introduces no
            % new symbols. Otherwise, a warning is issued, and the user is expected to provide types for the new symbols.
            o.symbols = setdiff(o.symbols, [o.params(:,modBuilder.COL_NAME); o.varexo(:,modBuilder.COL_NAME); o.var(:,modBuilder.COL_NAME)]);
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
        % Internal method for substitution: replace expr1 with expr2 in equations
        %
        % INPUTS:
        % - o           [modBuilder]
        % - expr1       [char]         expression to find (string literal or regex pattern)
        % - expr2       [char]         replacement expression
        % - eqname      [char or cell] equation name(s) or [] for all equations
        % - usestrrep   [logical]      true=use strrep (literal), false=use regexprep (regex)
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object
        %
        % REMARKS:
        % - If eqname is empty, substitution applies to all equations
        % - When usestrrep=false, validates that regex matches exactly one expression
        % - Automatically uses rename() if substitution affects a symbol across all equations
        % - Updates symbol tables after substitution
        % - Warns about new unknown symbols introduced by substitution
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
                eqnames = o.equations(:,modBuilder.EQ_COL_NAME);
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
                    id = strcmp(eqnames{i}, o.equations(:,modBuilder.EQ_COL_NAME));
                    matches = union(matches, unique(regexp(o.equations{id,modBuilder.EQ_COL_EXPR}, expr1, 'match')));
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
                    eqnames_ = setdiff(o.equations(:,modBuilder.EQ_COL_NAME), eqnames);
                    matches = {};
                    for i=1:numel(eqnames_)
                        id = strcmp(eqnames_{i}, o.equations(:,modBuilder.EQ_COL_NAME));
                        matches = union(matches, unique(regexp(o.equations{id,modBuilder.EQ_COL_EXPR}, expr1, 'match')));
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
            % Preallocate with reasonable max size (optimize for common case)
            list_of_unknown_symbols = cell(1, numel(eqnames) * 5); % Assume max 5 new symbols per equation
            unknown_count = 0;

            for i=1:numel(eqnames)
                eqname = eqnames{i};
                select = strcmp(eqname, o.equations(:,modBuilder.EQ_COL_NAME));
                if usestrrep
                    o.equations(select,modBuilder.EQ_COL_EXPR) = strrep(o.equations(select,modBuilder.EQ_COL_EXPR), expr1, expr2);
                else
                    o.equations(select,modBuilder.EQ_COL_EXPR) = regexprep(o.equations(select,modBuilder.EQ_COL_EXPR), expr1, expr2);
                end
                % Validate the modified equation syntax
                modBuilder.validate_equation_syntax(o.equations{select,modBuilder.EQ_COL_EXPR})
                Symbols = modBuilder.getsymbols(o.equations{select,modBuilder.EQ_COL_EXPR});
                newsyms = setdiff(Symbols, o.T.equations.(eqname)); % New symbols in updated equation
                if ~isempty(newsyms)
                    for j=1:length(newsyms)
                        if ~o.issymbol(newsyms{j})
                            if ~ismember(newsyms{j}, list_of_unknown_symbols(1:unknown_count))
                                modBuilder.dprintf('Symbol %s is unknown, you need to provide a type (parameter, endogenous or exogenous variable).', newsyms{j})
                                unknown_count = unknown_count + 1;
                                list_of_unknown_symbols{unknown_count} = newsyms{j};
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
                                modBuilder.dprintf('Parameter %s will be removed).', delsyms{j})
                                o.params(id,:) = [];
                              case 'exogenous'
                                modBuilder.dprintf('Exogenous variable %s will be removed).', delsyms{j})
                                o.varexo(id,:) = [];
                              case 'endogenous'
                                modBuilder.dprintf('Endogenous variable %s will be removed).', delsyms{j})
                                o.var(id,:) = [];
                            end
                        else
                            %
                        end
                    end
                end
                o.T.equations.(eqname) = Symbols;
            end
            % Trim preallocated array to actual size
            list_of_unknown_symbols = list_of_unknown_symbols(1:unknown_count);
            o.updatesymboltables;
        end % function

        function p = extract(o, varargin)
        % Extract a subset of equations to create a new submodel
        %
        % INPUTS:
        % - o      [modBuilder]
        % - ...    [char]          equation names to extract (variable arguments)
        %
        % OUTPUTS:
        % - p      [modBuilder]    new model containing only the specified equations
        %
        % REMARKS:
        % - The number of equations in p equals the number of arguments
        % - Automatically includes all parameters and exogenous variables used by extracted equations
        % - Removes unused symbols that don't appear in the extracted equations
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = w*h');
        % m.add('y', 'y = c + i');
        % m.add('i', 'i = delta*k');
        % m.parameter('w', 1.5);
        % m.parameter('delta', 0.1);
        %
        % % Extract only consumption and output equations
        % submodel = m.extract('c', 'y');
        % % submodel has 2 equations, w parameter, but not delta
            p = copy(o);
            if not(all(ismember(varargin, p.equations(:,modBuilder.EQ_COL_NAME))))
                error('Equation(s) missing for:%s.', modBuilder.printlist(varargin(~ismember(varargin, p.equations(:,modBuilder.EQ_COL_NAME)))))
            end
            eqnames = setdiff(p.equations(:,modBuilder.EQ_COL_NAME), varargin);
            p.rm(eqnames{:});
        end

        function q = merge(o, p)
        % Merge two models into a single larger model
        %
        % INPUTS:
        % - o    [modBuilder]    first model
        % - p    [modBuilder]    second model
        %
        % OUTPUTS:
        % - q    [modBuilder]    merged model containing all equations from o and p
        %
        % REMARKS:
        % - Models o and p cannot share endogenous variables (error if intersect(o.var, p.var) is not empty)
        % - Common parameters are allowed; p's calibration takes precedence if both are calibrated
        % - Exogenous variables in one model can be endogenous in the other (type conversion handled automatically)
        % - Symbol tables are merged appropriately
        % - Useful for combining independent blocks of a larger model
        %
        % EXAMPLES:
        % % Create first model (consumption block)
        % m1 = modBuilder();
        % m1.add('c', 'c = w*h');
        % m1.parameter('w', 1.5);
        %
        % % Create second model (production block)
        % m2 = modBuilder();
        % m2.add('y', 'y = alpha*k');
        % m2.parameter('alpha', 0.33);
        %
        % % Merge the two models
        % full_model = m1.merge(m2);
        % % full_model contains both equations and all parameters

            % Validate that models can be merged
            o.validate_merge_compatibility(p);

            % Create new model
            q = modBuilder();

            % Merge parameters (handles common parameters with precedence rules)
            q.params = o.merge_parameters(p);

            % Merge endogenous and exogenous variables (handles type conversions)
            [q.var, q.varexo] = o.merge_variables(p);

            % Merge equations (simple concatenation)
            q.equations = [o.equations; p.equations];

            % Merge symbol tables
            q = o.merge_symbol_tables(p, q);

            % Update symbol tables for the merged model
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
            eqID = cellfun(eq, o.equations(:,modBuilder.EQ_COL_NAME));
            equation = regexprep(o.equations{eqID,modBuilder.EQ_COL_EXPR}, '(\w+)\([+-]?\d+\)', '$1');
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
                    LHS = regexprep(LHS, ['\<', symbol, '\>'], num2str(o.params{id,modBuilder.COL_VALUE}, 15));
                    RHS = regexprep(RHS, ['\<', symbol, '\>'], num2str(o.params{id,modBuilder.COL_VALUE}, 15));
                  case 'exogenous'
                    LHS = regexprep(LHS, ['\<', symbol, '\>'], num2str(o.varexo{id,modBuilder.COL_VALUE}, 15));
                    RHS = regexprep(RHS, ['\<', symbol, '\>'], num2str(o.varexo{id,modBuilder.COL_VALUE}, 15));
                  case 'endogenous'
                    LHS = regexprep(LHS, ['\<', symbol, '\>'], num2str(o.var{id,modBuilder.COL_VALUE}, 15));
                    RHS = regexprep(RHS, ['\<', symbol, '\>'], num2str(o.var{id,modBuilder.COL_VALUE}, 15));
                  otherwise
                    error('Unknown symbol type.')
                end
            end
            evaleq.lhs = eval(LHS);
            evaleq.rhs = eval(RHS);
            evaleq.resid = evaleq.lhs-evaleq.rhs;
            if printflag
                modBuilder.skipline()
                modBuilder.dprintf('Static equation: %s', equation);
                modBuilder.skipline()
                modBuilder.dprintf('LHS:             %f', evaleq.lhs);
                modBuilder.dprintf('RHS:             %f', evaleq.rhs);
                if evaleq.resid<0
                    modBuilder.dprintf('residual:       %f', evaleq.resid);
                else
                    modBuilder.dprintf('residual:        %f', evaleq.resid);
                end
                modBuilder.skipline()
            end
        end

        function o = solve(o, eqname, sname, sinit)
        % Numerically solve an equation for a symbol (parameter, endogenous, or exogenous)
        %
        % INPUTS:
        % - o            [modBuilder]
        % - eqname       [char]         equation name to solve
        % - sname        [char]         symbol to solve for
        % - sinit        [double]       initial guess for the solution
        %
        % OUTPUTS:
        % - o            [modBuilder]   updated object with calibrated symbol value
        %
        % REMARKS:
        % - Converts equation to static form (removes time subscripts)
        % - Uses Newton's method via solvers.newton
        % - All other symbols must have known values
        % - Updates the calibration value of sname in o.params, o.varexo, or o.var
            if not(ismember(sname, o.T.equations.(eqname)))
                if o.isendogenous(sname)
                    if not(ismember(eqname, o.T.var.(sname)))
                        error('Symbol "%s" does not appear in equation "%s".', sname, eqname)
                    end
                else
                    error('Symbol "%s" does not appear in equation "%s".', sname, eqname)
                end
            end
            %
            % Get static version of the equation
            %
            eq = @(x) isequal(x, eqname);
            eqID = cellfun(eq, o.equations(:,modBuilder.EQ_COL_NAME));
            equation = regexprep(o.equations{eqID,modBuilder.EQ_COL_EXPR}, '(\w+)\([+-]?\d+\)', '$1');
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
                    equation = regexprep(equation, ['\<', symbol, '\>'], num2str(o.params{id,modBuilder.COL_VALUE}, 15));
                  case 'exogenous'
                    equation = regexprep(equation, ['\<', symbol, '\>'], num2str(o.varexo{id,modBuilder.COL_VALUE}, 15));
                  case 'endogenous'
                    equation = regexprep(equation, ['\<', symbol, '\>'], num2str(o.var{id,modBuilder.COL_VALUE}, 15));
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
                o.params{id,modBuilder.COL_VALUE} = x;
              case 'exogenous'
                o.varexo{id,modBuilder.COL_VALUE} = x;
              case 'endogenous'
                o.var{id,modBuilder.COL_VALUE} = x;
              otherwise
                error('Unknown symbol type.')
            end
        end

        function p = subsref(o, S)
        % Overload subsref to enable custom indexing: o('eqname') extracts equation, o.method() calls method
        %
        % INPUTS:
        % - o    [modBuilder]
        % - S    [struct]         subscript structure from MATLAB
        %
        % OUTPUTS:
        % - p    [varies]         extracted submodel, property value, or method result
        %
        % REMARKS:
        % - o('eq1', 'eq2') extracts equations by name
        % - o.varname extracts equation or calls method
        % - Enables natural syntax like: submodel = model('consumption', 'investment')
            if isequal(S(1).type, '()')
                p = o.extract(S(1).subs{:});
                    S = modBuilder.shiftS(S, 1);
            elseif isequal(S(1).type, '.')
                if ~ismember(S(1).subs, {metaclass(o).PropertyList.Name})
                    if isscalar(S)
                        if ismember(S(1).subs, o.equations(:,modBuilder.EQ_COL_NAME))
                            p = o.extract(S(1).subs);
                        else
                            p = feval(S(1).subs, o);
                        end
                        S = modBuilder.shiftS(S, 1);
                    else
                        if ismember(S(1).subs, o.equations(:,modBuilder.EQ_COL_NAME))
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
        % Overload subsasgn to enable custom assignment: o('symbol') = value or equation
        %
        % INPUTS:
        % - o    [modBuilder]
        % - S    [struct]         subscript structure
        % - B    [varies]         value to assign (numeric for calibration, char for equation change)
        %
        % OUTPUTS:
        % - o    [modBuilder]     updated object
        %
        % REMARKS:
        % - o('param') = 0.5 sets parameter value
        % - o('var') = 'new_equation' changes equation
        % - o('endovar') = 1.0 sets steady state value
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
                        error('Wrong index (unknown symbol).')
                    end
                    switch type
                      case 'parameter'
                        if isnumeric(B) && isscalar(B) && isreal(B)
                            % Change parameter value.
                            o.params{id,modBuilder.COL_VALUE} = B;
                        else
                            error('Can only assign a real scalar number to a parameter.')
                        end
                      case 'exogenous'
                        if isnumeric(B) && isscalar(B) && isreal(B)
                            % Change exogenous variable value.
                            o.varexo{id,modBuilder.COL_VALUE} = B;
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
                                o.var{id,modBuilder.COL_VALUE} = B;
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
