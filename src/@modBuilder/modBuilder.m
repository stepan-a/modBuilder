classdef modBuilder < handle

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

        % Analytical steady-state expressions (n×2 cell array)
        % Column 1: symbol name — endogenous variable or parameter (char)
        % Column 2: RHS expression (char)
        % Row order = insertion order (used for tie-breaking in topological sort)
        steady_state = cell(0, 2);

        % Calibration role swaps recorded by m.calibrate.
        % Each row holds {endo_name, target_value, param_name}: at steady-state
        % analysis time the endogenous is treated as a known constant pinned to
        % target_value, and the parameter is treated as an unknown to be solved.
        % The swap is metadata only — it does not modify params / var / varexo.
        calibration_swaps = cell(0, 3);

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

        % Column indices for steady_state table
        SS_COL_NAME = 1     % Symbol name (endogenous variable or parameter)
        SS_COL_EXPR = 2     % RHS expression (char)

        % Valid symbol/component types for type checking
        % Used by size(), validate_type(), and other methods
        VALID_TYPES = {'parameters', 'exogenous', 'endogenous', 'equations'}

        % Reserved function names that cannot be used as symbol names
        % These are MATLAB/Octave built-in functions and Dynare-specific functions
        % Used by getsymbols() to filter out functions
        % The list is shared with the ast class (see dynare_reserved_function_names.m)
        DYNARE_RESERVED_NAMES = dynare_reserved_function_names()

        % Standalone flags (options without a value) for the steady command
        % Used by format_dynare_options() to distinguish flags from key-value pairs
        STEADY_STANDALONE_FLAGS = {'nocheck', 'noprint'}

        % Complete list of reserved names: Dynare's built-in functions + properties + methods Computed once
        % when class is loaded by calling compute_all_reserved_names()
        % Used by validate_symbol_name() to prevent conflicts with
        % class interface
        ALL_RESERVED_NAMES = modBuilder.compute_all_reserved_names()
    end

    properties (Access = private)
        % Symbol lookup map for O(1) type checking: symbol_name -> struct(type, idx)
        % Updated automatically by update_symbol_map() after structural changes
        % Provides significant performance improvement over linear search
        symbol_map = []

        % Flag indicating if symbol tables (T) need updating
        % true = tables are stale and need updating
        % false = tables are up-to-date
        % Automatically managed by modification and read methods
        tables_dirty = false
    end


    methods (Access = private)

        function val = get_value(o, name)
        % Return the calibration/steady-state value of a symbol
        %
        % INPUTS:
        % - o      [modBuilder]
        % - name   [char]         symbol name
        %
        % OUTPUTS:
        % - val    [double]       scalar value
            arguments
                o
                name (1,:) char {mustBeNonempty}
            end
            [type, id] = o.typeof(name);
            switch type
              case 'parameter'
                val = o.params{id, modBuilder.COL_VALUE};
              case 'exogenous'
                val = o.varexo{id, modBuilder.COL_VALUE};
              case 'endogenous'
                val = o.var{id, modBuilder.COL_VALUE};
            end
        end % function

        function set_value(o, name, val)
        % Set the calibration/steady-state value of a symbol
        %
        % INPUTS:
        % - o      [modBuilder]
        % - name   [char]         symbol name
        % - val    [double]       scalar value
            arguments
                o
                name (1,:) char   {mustBeNonempty}
                val  (1,1) double
            end
            [type, id] = o.typeof(name);
            switch type
              case 'parameter'
                o.params{id, modBuilder.COL_VALUE} = val;
              case 'exogenous'
                o.varexo{id, modBuilder.COL_VALUE} = val;
              case 'endogenous'
                o.var{id, modBuilder.COL_VALUE} = val;
            end
        end % function

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
        % - Creates a dictionary for O(1) symbol type lookup
        % - Called automatically after structural changes
        % - Maps symbol_name -> struct('type', <type>, 'idx', <index>)
        % - Significantly faster than linear search through params/varexo/var arrays

            % Build a fresh dictionary; key/value types are inferred from the
            % first insertion (string -> struct).
            o.symbol_map = dictionary();

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
        end % function

        function [found, type, id] = lookup_symbol(o, name)
        % Resolve a name to its (type, id) without throwing.
        %
        % INPUTS:
        % - o      [modBuilder]
        % - name   [char]        symbol name
        %
        % OUTPUTS:
        % - found  [logical]     true iff name is a declared symbol
        % - type   [char]        'parameter' / 'exogenous' / 'endogenous',
        %                        or '' when found is false
        % - id     [integer]     row position in the corresponding table,
        %                        or [] when found is false
        %
        % REMARKS:
        % - Tries the O(1) symbol_map shortcut first; falls back to a linear
        %   scan of o.params / o.varexo / o.var (the source of truth) when
        %   symbol_map is empty or the name is not (yet) keyed.
        % - Shared backend for typeof, isparameter, isexogenous, isendogenous
        %   and issymbol so the lookup logic lives in one place.
        % - When tables are stale, the symbol_map shortcut is bypassed: a
        %   prior flip/rename may have changed a symbol's type without
        %   refreshing the map, and o.params / o.varexo / o.var are the
        %   source of truth.
            if ~o.tables_dirty && ~isempty(o.symbol_map) && isa(o.symbol_map, 'dictionary') && o.symbol_map.isKey(name)
                sym_info = o.symbol_map(name);
                found = true;
                type  = sym_info.type;
                id    = sym_info.idx;
                return
            end

            id = find(strcmp(o.params(:,modBuilder.COL_NAME), name), 1);
            if ~isempty(id)
                found = true; type = 'parameter'; return
            end

            id = find(strcmp(o.varexo(:,modBuilder.COL_NAME), name), 1);
            if ~isempty(id)
                found = true; type = 'exogenous'; return
            end

            id = find(strcmp(o.var(:,modBuilder.COL_NAME), name), 1);
            if ~isempty(id)
                found = true; type = 'endogenous'; return
            end

            found = false;
            type  = '';
            id    = [];
        end % function

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
            arguments
                o
                symbol_name (1,:) char {mustBeNonempty}
                symbol_type (1,:) char {mustBeMember(symbol_type, {'parameter', 'exogenous', 'endogenous'})}
            end
            arguments (Repeating)
                varargin
            end

            % Find all indices in the symbol name (e.g., $1, $2)
            inames = modBuilder.placeholders(symbol_name);
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
            remaining = varargin;
            if numel(remaining) > 0 && ~iscell(remaining{1}) && ~ischar(remaining{1})
                value = remaining{1};
                remaining = remaining(2:end);
            end

            % Parse key/value pairs (long_name, texname) until we hit a cell array (index array)
            key_val_args = {};
            idx = 1;
            while idx <= numel(remaining)
                if ischar(remaining{idx}) && ismember(remaining{idx}, {'long_name', 'texname'})
                    % This is a key
                    if idx + 1 > numel(remaining)
                        error('modBuilder:handle_implicit_loops:missingValue', 'Key "%s" provided without a value.', remaining{idx});
                    end
                    key_val_args = [key_val_args, remaining{idx}, remaining{idx+1}];
                    idx = idx + 2;
                elseif iscell(remaining{idx})
                    % Start of index arrays
                    break;
                else
                    error('modBuilder:handle_implicit_loops:badType', 'Unexpected argument type in implicit loop. Expected key/value pair or index array.');
                end
            end

            % Remaining args are index arrays
            index_args = remaining(idx:end);

            % Validate number of index arrays
            if not(isequal(numel(index_args), nindices))
                error('modBuilder:handle_implicit_loops:indexMismatch', 'The number of indices in the "%s" name is %u, but values for %u indices are provided.', ...
                      symbol_type, nindices, numel(index_args))
            end

            % Parse optional long_name and texname from key_val_args
            [long_name, texname] = modBuilder.set_optional_fields(symbol_type, symbol_name, key_val_args{:});

            % Validate that long_name and texname have the same number of indices as symbol_name
            if ~isempty(long_name)
                inames_long = modBuilder.placeholders(long_name);
                if numel(inames_long) ~= nindices
                    error('modBuilder:handle_implicit_loops:indexMismatch', 'long_name has %u indices but %s name has %u indices.', ...
                          numel(inames_long), symbol_type, nindices);
                end
            end
            if ~isempty(texname)
                inames_tex = modBuilder.placeholders(texname);
                if numel(inames_tex) ~= nindices
                    error('modBuilder:handle_implicit_loops:indexMismatch', 'texname has %u indices but %s name has %u indices.', ...
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
                        o.parameter(call_args{:});
                    case 'exogenous'
                        o.exogenous(call_args{:});
                    case 'endogenous'
                        o.endogenous(call_args{:});
                    otherwise
                        error('modBuilder:handle_implicit_loops:unsupportedType', 'Unsupported symbol type: "%s".', symbol_type)
                end
            end
        end % function

        function o = declare_symbol(o, type, name, value, varargin)
        % Common implementation for parameter / exogenous / endogenous.
        %
        % INPUTS:
        % - type     [char]    'parameter' | 'exogenous' | 'endogenous'
        % - name     [char]    1×n, symbol name (no implicit-loop placeholders;
        %                      the public wrappers have already dispatched).
        % - value    [double]  scalar; semantics depend on the call path:
        %                        * existing-row update: set unconditionally
        %                          (NaN clobbers the existing value);
        %                        * type-conversion path (varexo↔params): if
        %                          NaN, preserve the source row's value;
        %                          otherwise override;
        %                        * untyped → typed promotion: set unconditionally.
        %                      Endogenous's "preserve existing on missing arg"
        %                      semantics is resolved by the public wrapper
        %                      before getting here.
        % - varargin           Optional key/value pairs forwarded to
        %                      set_optional_fields (long_name, texname).
        %
        % OUTPUTS:
        % - o        [modBuilder]
        %
        % REMARKS:
        % - tables_dirty is set on every type conversion and on every
        %   parameter/exogenous untyped-promotion, but NOT on plain
        %   existing-row updates and (preserving pre-refactor behaviour)
        %   NOT on the unreachable endogenous-promotion path.
            arguments
                o
                type  (1,:) char {mustBeMember(type, {'parameter', 'exogenous', 'endogenous'})}
                name  (1,:) char {mustBeNonempty}
                value (1,1) double = NaN
            end
            arguments (Repeating)
                varargin
            end

            modBuilder.validate_symbol_name(name, type);

            switch type
              case 'parameter'
                if ~(ismember(name, o.symbols) || ...
                     ismember(name, o.varexo(:,modBuilder.COL_NAME)) || ...
                     ismember(name, o.params(:,modBuilder.COL_NAME)))
                    if ismember(name, o.var(:,modBuilder.COL_NAME))
                        error('modBuilder:declare_symbol:typeConversion', 'An endogenous variable cannot be converted into a parameter.')
                    else
                        error('modBuilder:declare_symbol:unknownSymbol', 'Symbol "%s" does not appear in the model.', name)
                    end
                end
                tbl_name     = 'params';
                src_tbl_name = 'varexo';
              case 'exogenous'
                if ~(ismember(name, o.symbols) || ...
                     ismember(name, o.varexo(:,modBuilder.COL_NAME)) || ...
                     ismember(name, o.params(:,modBuilder.COL_NAME)))
                    if ismember(name, o.var(:,modBuilder.COL_NAME))
                        error('modBuilder:declare_symbol:typeConversion', 'An endogenous variable cannot be converted into an exogenous variable. Please remove the equation associated to the endogenous variable.')
                    else
                        error('modBuilder:declare_symbol:unknownSymbol', 'Symbol "%s" does not appear in the model.', name)
                    end
                end
                tbl_name     = 'varexo';
                src_tbl_name = 'params';
              case 'endogenous'
                if ~ismember(name, o.equations(:,modBuilder.EQ_COL_NAME))
                    error('modBuilder:declare_symbol:notEndogenous', 'Symbol "%s" is not an endogenous variable.', name)
                end
                tbl_name     = 'var';
                src_tbl_name = '';
              otherwise
                error('modBuilder:declare_symbol:badType', ...
                      'Unknown symbol type "%s".', type);
            end

            [long_name, texname] = modBuilder.set_optional_fields(type, name, varargin{:});

            tbl    = o.(tbl_name);
            in_tbl = ismember(tbl(:,modBuilder.COL_NAME), name);

            if any(in_tbl)
                % Existing-row update: set value unconditionally, update
                % metadata only if non-empty.
                tbl{in_tbl, modBuilder.COL_VALUE} = value;
                if ~isempty(long_name)
                    tbl{in_tbl, modBuilder.COL_LONG_NAME} = long_name;
                end
                if ~isempty(texname)
                    tbl{in_tbl, modBuilder.COL_TEX_NAME} = texname;
                end
                o.(tbl_name) = tbl;
                o.symbols    = setdiff(o.symbols, name);
                return
            end

            new_idx   = size(tbl, 1) + 1;
            converted = false;

            if ~isempty(src_tbl_name)
                src_tbl = o.(src_tbl_name);
                in_src  = ismember(src_tbl(:,modBuilder.COL_NAME), name);
                if any(in_src)
                    % Type-conversion path: migrate the row, then optionally
                    % override its value/metadata.
                    tbl(new_idx,:) = src_tbl(in_src,:);
                    src_tbl(in_src,:) = [];
                    o.(src_tbl_name) = src_tbl;
                    if ~isnan(value)
                        tbl{new_idx, modBuilder.COL_VALUE} = value;
                    end
                    if ~isempty(long_name)
                        tbl{new_idx, modBuilder.COL_LONG_NAME} = long_name;
                    end
                    if ~isempty(texname)
                        tbl{new_idx, modBuilder.COL_TEX_NAME} = texname;
                    end
                    converted = true;
                end
            end

            if ~converted
                % Untyped → typed promotion: a fresh row, value set as given.
                tbl{new_idx, modBuilder.COL_NAME}      = name;
                tbl{new_idx, modBuilder.COL_VALUE}     = value;
                tbl{new_idx, modBuilder.COL_LONG_NAME} = long_name;
                tbl{new_idx, modBuilder.COL_TEX_NAME}  = texname;
            end

            o.(tbl_name) = tbl;
            if ~strcmp(type, 'endogenous')
                % Preserve pre-refactor behaviour: parameter/exogenous flag
                % the symbol tables as dirty on both type-conversion and
                % promotion; endogenous (in its unreachable promotion path)
                % did not. Equation-driven endogenous declarations go via
                % add(), which manages the dirty flag itself.
                o.tables_dirty = true;
            end

            o.symbols = setdiff(o.symbols, name);
        end % function

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
            arguments
                o
                p (1,1) modBuilder
            end

            commonvariables = intersect(o.var(:,modBuilder.COL_NAME), p.var(:,modBuilder.COL_NAME));
            if ~isempty(commonvariables)
                error('modBuilder:validate_merge_compatibility:conflict', 'Models to be merged cannot contain common endogenous variables. Check variable(s)%s.', ...
                      sprintf(' %s', commonvariables{:}))
            end
        end % function

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
            arguments
                o
                p (1,1) modBuilder
            end

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
        end % function

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
            arguments
                o
                p (1,1) modBuilder
            end

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
                o_varexo_map = dictionary(string(o_varexo_list(:)), (1:length(o_varexo_list))');
            end
            if ~isempty(p_varexo_list)
                p_varexo_map = dictionary(string(p_varexo_list(:)), (1:length(p_varexo_list))');
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
        end % function

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
            arguments
                o
                p (1,1) modBuilder
                q (1,1) modBuilder
            end

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
        end % function


        function matches = findsymbol(o, pattern)
        % Find all symbols matching a regular expression pattern.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - pattern   [char]         1×n    regular expression pattern
        %
        % OUTPUTS:
        % - matches   [struct]       struct array with fields:
        %                            .name       - symbol name
        %                            .type       - 'Parameter', 'Exogenous variable', or 'Endogenous variable'
        %                            .equations  - cell array of equation names where symbol appears
        %
        % REMARKS:
        % - Searches through all parameters, exogenous, and endogenous variables
        % - Returns empty struct array if no matches found
            arguments
                o
                pattern (1,:) char {mustBeNonempty}
            end

            n_total = size(o.params, 1) + size(o.varexo, 1) + size(o.var, 1);
            matches = repmat(struct('name', '', 'type', '', 'equations', {{}}), 1, n_total);
            count = 0;

            % Search parameters
            for i = 1:size(o.params, 1)
                name = o.params{i, modBuilder.COL_NAME};
                if ~isempty(regexp(name, pattern, 'once'))
                    count = count + 1;
                    matches(count).name = name;
                    matches(count).type = 'Parameter';
                    matches(count).equations = o.T.params.(name);
                end
            end

            % Search exogenous variables
            for i = 1:size(o.varexo, 1)
                name = o.varexo{i, modBuilder.COL_NAME};
                if ~isempty(regexp(name, pattern, 'once'))
                    count = count + 1;
                    matches(count).name = name;
                    matches(count).type = 'Exogenous variable';
                    matches(count).equations = o.T.varexo.(name);
                end
            end

            % Search endogenous variables
            for i = 1:size(o.var, 1)
                name = o.var{i, modBuilder.COL_NAME};
                if ~isempty(regexp(name, pattern, 'once'))
                    count = count + 1;
                    matches(count).name = name;
                    matches(count).type = 'Endogenous variable';
                    matches(count).equations = o.T.var.(name);
                end
            end

            matches = matches(1:count);
        end % function

        function [fhandles, incidence] = compile_equations(o, eqnames, snames)
        % Pre-compile equations into function handles with solve variables accessed via cell array v{k}.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqnames    [cell]        1×m cell array of equation names
        % - snames   [cell]        1×n cell array of symbol names (solve variables)
        %
        % OUTPUTS:
        % - fhandles   [cell]        1×m cell array of function handles @(v) LHS-(RHS)
        % - incidence  [logical]     m×n matrix, incidence(i,j)=true if snames{j} appears in eqnames{i}
            arguments
                o
                eqnames cell
                snames  cell
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

            m = length(eqnames);
            n = length(snames);

            % Build var-name-to-index map
            varmap = dictionary(string(snames(:)), (1:n)');

            % Build equation-name-to-row map for O(1) lookups
            eqmap = dictionary(string(o.equations(:, modBuilder.EQ_COL_NAME)), (1:size(o.equations, 1))');

            fhandles = cell(1, m);
            incidence = false(m, n);

            for i = 1:m
                % Get static version of the equation
                eqID = eqmap(eqnames{i});
                equation = regexprep(o.equations{eqID, modBuilder.EQ_COL_EXPR}, '(\w+)\([+-]?\d+\)', '$1');

                % Split on = and form LHS-(RHS)
                LHSRHS = strsplit(equation, '=');
                if length(LHSRHS) == 2
                    expr = sprintf('%s-(%s)', LHSRHS{1}, LHSRHS{2});
                elseif isscalar(LHSRHS)
                    expr = LHSRHS{1};
                else
                    error('modBuilder:compile_equations:multipleEquals', 'An equation cannot have more than one equal (=) symbol.')
                end

                % Get all symbols in this equation
                symbols = o.T.equations.(eqnames{i});
                symbols = [symbols, eqnames{i}]; %#ok<AGROW>
                symbols = unique(symbols);

                % First pass: replace solve variables with v{k}
                for s = 1:length(symbols)
                    symbol = symbols{s};
                    if varmap.isKey(symbol)
                        k = varmap(symbol);
                        expr = regexprep(expr, ['\<', symbol, '\>'], sprintf('v{%d}', k));
                        incidence(i, k) = true;
                    end
                end

                % Second pass: replace known symbols with numeric values
                for s = 1:length(symbols)
                    symbol = symbols{s};
                    if ~varmap.isKey(symbol)
                        val = o.get_value(symbol);
                        expr = regexprep(expr, ['\<', symbol, '\>'], num2str(val, 15));
                    end
                end

                fhandles{i} = str2func(sprintf('@(v) %s', expr));
            end
        end % function

        function [J, residuals] = jacobian(o, eqnames, snames)
        % Compute a sparse Jacobian matrix using automatic differentiation.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqnames    [cell]        1×m cell array of equation names
        % - snames   [cell]        1×n cell array of symbol names to differentiate w.r.t.
        %
        % OUTPUTS:
        % - J          [sparse]      m×n sparse Jacobian matrix evaluated at current calibration
        % - residuals  [double]      m×1 residual vector (LHS−RHS for each equation)
            arguments
                o
                eqnames cell
                snames  cell
            end

            [fhandles, incidence] = o.compile_equations(eqnames, snames);
            m = length(eqnames);
            n = length(snames);

            % Build evaluation point
            x0 = zeros(n, 1);
            for j = 1:n
                x0(j) = o.get_value(snames{j});
            end

            % Compute residuals with plain doubles
            v = num2cell(x0);
            residuals = zeros(m, 1);
            for i = 1:m
                residuals(i) = fhandles{i}(v);
            end

            % Compute Jacobian column by column using AD (COO → sparse)
            nnzJ = nnz(incidence);
            II = zeros(nnzJ, 1);
            JJ = zeros(nnzJ, 1);
            VV = zeros(nnzJ, 1);
            idx = 0;
            for j = 1:n
                affected = find(incidence(:, j));
                if isempty(affected), continue; end
                v_ad = cell(n, 1);
                for k = 1:n
                    if k == j
                        v_ad{k} = autoDiff1(x0(k), 1.0);
                    else
                        v_ad{k} = autoDiff1(x0(k), 0.0);
                    end
                end
                for ii = affected'
                    r = fhandles{ii}(v_ad);
                    idx = idx + 1;
                    II(idx) = ii;
                    JJ(idx) = j;
                    VV(idx) = r.dx;
                end
            end
            J = sparse(II, JJ, VV, m, n);
        end % function

        function matches = collect_matches(o, eqnames, pattern)
        % Return the unique regex matches found across the specified equations.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqnames    [cell]        cell array of equation names to scan
        % - pattern    [char]        regex pattern (same form as regexp 'match')
        %
        % OUTPUTS:
        % - matches    [cell]        unique matches across all scanned equations,
        %                            empty cell if none found or no eqnames given
            matches = {};
            if isempty(eqnames)
                return
            end
            [~, rows] = ismember(eqnames, o.equations(:, modBuilder.EQ_COL_NAME));
            rows = rows(rows > 0);
            if isempty(rows)
                return
            end
            hits = regexp(o.equations(rows, modBuilder.EQ_COL_EXPR), pattern, 'match');
            matches = unique([hits{:}]);
        end % function

        function refresh_tables(o)
        % Refresh the symbol tables if they are stale; no-op otherwise.
        %
        % INPUTS:
        % - o   [modBuilder]
        %
        % REMARKS:
        % - Called from read-side methods that depend on a fresh o.T before
        %   touching the symbol tables. updatesymboltables() resets the
        %   tables_dirty flag, so subsequent calls are cheap no-ops.
            if o.tables_dirty
                o.updatesymboltables();
            end
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
        % - Used internally by size() and other type-checking methods
        % - Can be called by users to validate type strings before use
        %
        % EXAMPLE:
        % modBuilder.validate_type('parameters')  % OK
        % modBuilder.validate_type('vars')        % Error: Unknown type (vars). Valid types are: ...

            if ~ismember(type, modBuilder.VALID_TYPES)
                error('modBuilder:validate_type:unknownType', 'Unknown type (%s). Valid types are: %s', ...
                      type, strjoin(modBuilder.VALID_TYPES, ', '))
            end
        end % function

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
                error('modBuilder:validate_equation_syntax:unbalancedParens', 'Equation has unbalanced parentheses: "%s".', equation)
            end

            % Check for invalid equality operator
            if contains(equation, '==')
                error('modBuilder:validate_equation_syntax:multipleEquals', 'Equation contains "==". Use "=" for assignment. Equation: "%s"', equation)
            end

            % Check for element-wise division (likely unintended)
            if contains(equation, './')
                error('modBuilder:validate_equation_syntax:invalidOp', 'Equation contains "./". Element-wise division is not allowed. Use "/" instead. Equation: "%s"', equation)
            end

            % Warn about potentially unintended operators
            if contains(equation, '++')
                warning('Equation contains "++". This may be unintended. Equation: "%s"', equation)
            end
            if contains(equation, '--')
                warning('Equation contains "--". This may be unintended. Equation: "%s"', equation)
            end
        end % function

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
        % - Checks (via the arguments block) that sname is a non-empty row char array
        % - Checks that sname is not a reserved MATLAB/Dynare function name
        % - Called by add(), parameter(), exogenous(), endogenous(), change() methods
        % - Compatible with both MATLAB and GNU Octave
        %
        % EXAMPLE:
        % modBuilder.validate_symbol_name('alpha', 'parameter')   % OK
        % modBuilder.validate_symbol_name('log', 'parameter')     % Error: reserved name
        % modBuilder.validate_symbol_name('', 'add')              % Error: empty string
            arguments
                sname       (1,:) char {mustBeNonempty}
                method_name (1,:) char {mustBeNonempty}
            end

            % Check for reserved names (built-in functions + properties + methods)
            if ismember(sname, modBuilder.ALL_RESERVED_NAMES)
                error('modBuilder:validate_symbol_name:reservedName', '%s: Symbol name "%s" is reserved (conflicts with modBuilder property/method or built-in function).', method_name, sname);
            end
        end % function

    end

    methods(Static, Access = private)

        function names = placeholders(s)
        % Return the sorted unique set of implicit-loop placeholders ($0, $1, ...) in s.
        %
        % INPUTS:
        % - s      [char]   1×n expression / equation name / template
        %
        % OUTPUTS:
        % - names  [cell]   1×k cell of placeholder tokens, sorted ascending.
            names = unique(regexp(s, '\$\d+', 'match'));
        end % function

        function expand_implicit_loops(leaf_fn, expr1, expr2, eqname, index_values, method_id, strict_expr2)
        % Expand $-placeholders in (expr1, expr2, eqname) and call leaf_fn for each tuple.
        %
        % INPUTS:
        % - leaf_fn       [function_handle]  fcn(ce1, ce2, ceq) invoked per expansion.
        % - expr1, expr2  [char]             1×n templates with $0/$1/... placeholders.
        % - eqname        [char]             '' for "all equations", otherwise an equation
        %                                    name that may itself carry $-placeholders.
        % - index_values  [cell]             one per unique placeholder across expr1 and
        %                                    eqname (and expr2 when strict_expr2 is true).
        % - method_id     [char]             'subs' or 'substitute'; embedded in error IDs
        %                                    so the caller's previous error IDs survive.
        % - strict_expr2  [logical]          true  → setxor(expr1, expr2) placeholders must
        %                                            be empty (substitute);
        %                                    false → expr2 may use a subset of expr1's
        %                                            placeholders, but no extras (subs).
        %
        % REMARKS:
        % - Caller must have already routed the no-placeholders base case; this helper
        %   assumes implicit-loop expansion is required.
        % - leaf_fn receives '' as eqname when the caller's eqname is empty; the caller's
        %   substitute/subs arg parser treats '' identically to "no eqname".
            inames_expr1 = modBuilder.placeholders(expr1);
            inames_expr2 = modBuilder.placeholders(expr2);

            if strict_expr2
                if ~isempty(setxor(inames_expr1, inames_expr2))
                    error(sprintf('modBuilder:%s:indexMismatch', method_id), 'Both expressions must contain the same index placeholders. Found %s in expr1 and %s in expr2.', strjoin(inames_expr1, ', '), strjoin(inames_expr2, ', '))
                end
            else
                extras = setdiff(inames_expr2, inames_expr1);
                if ~isempty(extras)
                    error(sprintf('modBuilder:%s:placeholderMismatch', method_id), 'subs: expr2 contains placeholders not present in expr1: %s. Each placeholder in expr2 must also appear in expr1.', strjoin(extras, ', '))
                end
            end

            inames_eq = {};
            if ~isempty(eqname)
                inames_eq = modBuilder.placeholders(eqname);
            end
            all_indices = unique([inames_expr1, inames_eq]);

            if length(index_values) ~= numel(all_indices)
                if strict_expr2
                    error(sprintf('modBuilder:%s:indexMismatch', method_id), 'Expected %d index value arrays (for indices %s), but got %d.', numel(all_indices), strjoin(all_indices, ', '), length(index_values))
                else
                    error(sprintf('modBuilder:%s:indexMismatch', method_id), 'subs: expected %d index value array(s) (for indices %s), but got %d.', numel(all_indices), strjoin(all_indices, ', '), length(index_values))
                end
            end

            [allint, ~] = modBuilder.check_indices_values(index_values);
            index_map = dictionary(string(all_indices(:)), index_values(:));

            % Build sprintf templates from expr1/expr2 (replace each placeholder with %u or %s).
            tmp_expr1 = expr1;
            tmp_expr2 = expr2;
            for k = numel(inames_expr1):-1:1
                is_int = allint(strcmp(all_indices, inames_expr1{k}));
                fmt = '%s';
                if is_int, fmt = '%u'; end
                tmp_expr1 = strrep(tmp_expr1, inames_expr1{k}, fmt);
                tmp_expr2 = strrep(tmp_expr2, inames_expr1{k}, fmt);
            end

            % Expression-side Cartesian product (degenerate single iteration if expr1 has no placeholders).
            if isempty(inames_expr1)
                mIndex_expr = {{}};
            else
                expr_values = cellfun(@(x) index_map{x}, inames_expr1, 'UniformOutput', false);
                mIndex_expr = table2cell(combinations(expr_values{:}));
            end

            if isempty(inames_eq)
                % eqname has no placeholders. leaf_fn is called variadically: empty
                % eqname → 2 args (so the leaf's own arg parser stays on the natural
                % "no-eqname" path), non-empty → 3 args.
                for i = 1:size(mIndex_expr, 1)
                    if isempty(inames_expr1)
                        ce1 = expr1; ce2 = expr2;
                    else
                        ce1 = sprintf(tmp_expr1, mIndex_expr{i,:});
                        ce2 = sprintf(tmp_expr2, mIndex_expr{i,:});
                    end
                    if isempty(eqname)
                        leaf_fn(ce1, ce2);
                    else
                        leaf_fn(ce1, ce2, eqname);
                    end
                end
            else
                % eqname has its own (possibly disjoint) placeholders.
                eq_values = cellfun(@(x) index_map{x}, inames_eq, 'UniformOutput', false);
                tmp_eqname = eqname;
                for k = numel(inames_eq):-1:1
                    is_int = allint(strcmp(all_indices, inames_eq{k}));
                    fmt = '%s';
                    if is_int, fmt = '%u'; end
                    tmp_eqname = strrep(tmp_eqname, inames_eq{k}, fmt);
                end
                mIndex_eq = table2cell(combinations(eq_values{:}));
                for j = 1:size(mIndex_eq, 1)
                    current_eqname = sprintf(tmp_eqname, mIndex_eq{j,:});
                    for i = 1:size(mIndex_expr, 1)
                        if isempty(inames_expr1)
                            ce1 = expr1; ce2 = expr2;
                        else
                            ce1 = sprintf(tmp_expr1, mIndex_expr{i,:});
                            ce2 = sprintf(tmp_expr2, mIndex_expr{i,:});
                        end
                        leaf_fn(ce1, ce2, current_eqname);
                    end
                end
            end
        end % function

        function str = format_dynare_options(opts, flags)
        % Convert a cell array of options to a Dynare option string.
        %
        % INPUTS:
        % - opts   [cell]   1×n    cell array of key-value pairs and flags
        %                          e.g. {'maxit', 100, 'nocheck', 'solve_algo', 4}
        % - flags  [cell]   1×m    cell array of standalone flag names (no value expected)
        %
        % OUTPUTS:
        % - str    [char]   option string, e.g. '(maxit=100, nocheck, solve_algo=4)'
        %                   Returns '' if opts is empty.
            arguments
                opts  cell
                flags cell = {}
            end
            if isempty(opts)
                str = '';
                return
            end
            parts = {};
            idx = 1;
            while idx <= numel(opts)
                name = opts{idx};
                if ~ischar(name)
                    error('modBuilder:format_dynare_options:badType', 'Expected option name (char array) at position %d.', idx);
                end
                if ismember(name, flags)
                    parts{end+1} = name; %#ok<AGROW>
                    idx = idx + 1;
                else
                    if idx + 1 > numel(opts)
                        error('modBuilder:format_dynare_options:missingValue', 'Option ''%s'' requires a value.', name);
                    end
                    value = opts{idx + 1};
                    if isnumeric(value)
                        parts{end+1} = sprintf('%s=%s', name, num2str(value)); %#ok<AGROW>
                    elseif ischar(value)
                        parts{end+1} = sprintf('%s=%s', name, value); %#ok<AGROW>
                    else
                        error('modBuilder:format_dynare_options:badType', 'Value for option ''%s'' must be numeric or char.', name);
                    end
                    idx = idx + 2;
                end
            end
            str = ['(', strjoin(parts, ', '), ')'];
        end % function

        function reserved = compute_all_reserved_names()
        % Compute complete list of reserved names (called once when class loads)
        %
        % OUTPUTS:
        % - reserved [cell array] Complete list of reserved symbol names
        %
        % REMARKS:
        % - Includes DYNARE_RESERVED_NAMES (Dynare's built-in functions)
        % - Includes all property names from modBuilder class
        % - Includes all public method names from modBuilder class
        % - This prevents symbol names from conflicting with class interface
        % - Called automatically when ALL_RESERVED_NAMES constant is initialized

            % Start with built-in reserved names
            reserved = modBuilder.DYNARE_RESERVED_NAMES;

            % Get metaclass information
            mc = ?modBuilder;

            % Add all property names
            for i = 1:length(mc.PropertyList)
                reserved{end+1} = mc.PropertyList(i).Name;
            end

            % Add all public method names (excluding constructor)
            for i = 1:length(mc.MethodList)
                method = mc.MethodList(i);
                % Only add public methods (exclude constructor)
                if strcmp(method.Access, 'public') && ~strcmp(method.Name, 'modBuilder')
                    reserved{end+1} = method.Name;
                end
            end

            % Make unique in case of duplicates
            reserved = unique(reserved);
        end % function

        function skipline(n)
        % Print n blank lines to the console
        %
        % INPUTS:
        % - n    [integer]    number of lines to skip (default: 1)
            if ~nargin || isempty(n)
                n = 1;
            end
            for i=1:n, fprintf('\n'), end
        end % function

        function dprintf(format, varargin)
        % Display formatted output using dprintf and disp combination
        %
        % INPUTS:
        % - format    [char]     format string (same as fprintf)
        % - varargin  [cell]     optional arguments for format string
            if nargin>1
                disp(sprintf(format, varargin{:}));
            else
                disp(sprintf(format));
            end
        end % function

        function warn_silent(varargin)
        % Issue a warning with the 'backtrace' state temporarily turned off,
        % then restore the prior state.
        %
        % INPUTS:
        % - varargin   forwarded verbatim to warning(): (msg), (msg, args, ...),
        %              or (msgid, msg, args, ...).
        %
        % REMARKS:
        % - onCleanup guarantees the prior backtrace state is restored even
        %   if warning() errors out.
            bt = warning('query', 'backtrace');
            warning('off', 'backtrace');
            restore = onCleanup(@() warning(bt.state, 'backtrace')); %#ok<NASGU>
            warning(varargin{:});
        end % function

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
        end % function

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
                error('modBuilder:printlist2:unknownType', 'printlist2: Unknown type (%s). Valid types are: %s', ...
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
            for i=1:size(Table,1)
                % Print keyword before first symbol, tab before others
                if i == 1
                    fprintf(fid, '%s ', keyword);
                end
                fprintf(fid, '%s', Table{i,1});
                if ~isempty(Table{i,4})
                    fprintf(fid, ' $%s$', Table{i,4});
                end
                if ~isempty(Table{i,3})
                    fprintf(fid, ' (long_name=''%s'')', Table{i,3});
                end
                fprintf(fid, '\n\t');
            end
            fprintf(fid, ';\n\n');
        end % function

        function S = shiftS(S,n)
        % Removes the first n elements of a one dimensional cell array.
            if length(S) >= n+1
                S = S(n+1:end);
            else
                S = {};
            end
        end % function

        function tokens = getsymbols(expr)
        % Extract symbols from an expression
        %
        % INPUTS:
        % - expr    [char]          1×n array, expression
        %
        % OUTPUTS:
        % - tokens  [cell]          1×m array of row char arrays, list of symbols
            % Extract valid identifiers (start with letter or _, followed by word characters)
            % The negative lookbehind (?<![.\d]) rejects identifiers preceded by a digit
            % or dot, correctly ignoring scientific notation (1e5, 1e-5) and decimals (0.33)
            tokens = regexp(expr, '(?<![.\d])[a-zA-Z_]\w*', 'match');
            % Filter out reserved functions and operators
            tokens(cellfun(@(x) ismember(x, modBuilder.DYNARE_RESERVED_NAMES), tokens)) = [];
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
                error('modBuilder:isequalcell:badType', 'Second columns of cell arays must contain only numerics or only characters.')
            end
        end % function

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
            b = true;
            for i=1:length(f1)
                b = isequal(sort(S1.(f1{i})), sort(S2.(f1{i})));
                if not(b)
                    return
                end
            end
        end % function

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
        end % function

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
            arguments
                type  (1,:) char {mustBeNonempty}
                sname (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end
            long_name = '';
            texname='';
            if ~isempty(varargin)
                if ismember(type, {'endogenous', 'exogenous'})
                    type = sprintf('%s variable', type);
                end
                n = length(varargin);
                if mod(n, 2) ~= 0
                    error('modBuilder:set_optional_fields:badPair', 'Wrong number of arguments.')
                end
                for i=1:2:n
                    switch varargin{i}
                      case 'long_name'
                        long_name = varargin{i+1};
                      case 'texname'
                        texname = varargin{i+1};
                      otherwise
                        error('modBuilder:set_optional_fields:unknownProperty', 'Unknown property for %s %s.', type, sname)
                    end
                end
            end
        end % function

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
        end % function

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
                            error('modBuilder:check_indices_values:indexMismatch', 'Values for index $%u should be all char or all integer.', i)
                        end
                    else
                        error('modBuilder:check_indices_values:badType', 'Values for index $%u should be pass as a one dimensional cell array.', i)
                    end
                else
                    error('modBuilder:check_indices_values:badType', 'Values for index $%u should be pass as a cell array.', i)
                end
            end
        end % function

        function expanded = expand_templates(templates, index_values)
        % Expand implicit loop templates into concrete strings.
        %
        % INPUTS:
        % - templates      [cell]   1×k cell array of template strings (e.g., {'Y_$1_$2', 'Y_$1 = A_$1*K_$2'})
        % - index_values   [cell]   1×n cell array of cell arrays of index values
        %
        % OUTPUTS:
        % - expanded       [cell]   m×k cell array of expanded strings (m = number of combinations)
        %
        % REMARKS:
        % - Detects $N placeholders in the first template
        % - Validates that the number of index arrays matches the number of placeholders
        % - Computes Cartesian product of index values
        % - Uses strrep for expansion, so $N placeholders can appear multiple times
            arguments
                templates    cell
                index_values cell
            end

            inames = modBuilder.placeholders(templates{1});
            nindices = numel(inames);

            if numel(index_values) ~= nindices
                error('modBuilder:expand_templates:indexMismatch', 'The number of indices in the template is %u, but values for %u indices are provided.', nindices, numel(index_values))
            end

            [allint, ~] = modBuilder.check_indices_values(index_values);
            mIndex = table2cell(combinations(index_values{:}));

            % Expand all combinations using strrep
            expanded = cell(size(mIndex, 1), numel(templates));
            for i = 1:size(mIndex, 1)
                for t = 1:numel(templates)
                    s = templates{t};
                    for j = nindices:-1:1
                        if allint(j)
                            s = strrep(s, sprintf('$%u', j), num2str(mIndex{i, j}));
                        else
                            s = strrep(s, sprintf('$%u', j), mIndex{i, j});
                        end
                    end
                    expanded{i, t} = s;
                end
            end
        end % function

    end % methods

    methods(Static)

        function n = total_residual_count(blocks)
        % Count the total number of unresolved variables across all simultaneous blocks
        % of a steady-state plan. Used by suggest_calibrations to score candidate swaps.
            n = 0;
            for k = 1:numel(blocks)
                b = blocks(k);
                if strcmp(b.kind, 'simultaneous')
                    resolved = {b.closed_form.var};
                    n = n + numel(setdiff(b.vars, resolved));
                end
            end
        end % function

        function f = static_residual(o, eq_idx)
        % Build the static residual AST for the equation at row eq_idx of o.equations.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - eq_idx   [integer]    row index in o.equations
        %
        % OUTPUTS:
        % - f        [ast]   staticised "LHS - RHS" tree (or "LHS" if the equation has
        %                    no '=' symbol). Empty if the equation cannot be parsed.
        %
        % REMARKS:
        % - Used by steady_plan to feed ast.isolate / ast.linearise_system without
        %   duplicating the LHS/RHS-split-and-staticise boilerplate.
            eq_str = o.equations{eq_idx, modBuilder.EQ_COL_EXPR};
            LHSRHS = strsplit(eq_str, '=');
            if isscalar(LHSRHS)
                f = ast(strtrim(LHSRHS{1})).staticise();
            elseif length(LHSRHS) == 2
                Lt = ast(strtrim(LHSRHS{1})).staticise();
                Rt = ast(strtrim(LHSRHS{2})).staticise();
                f = ast('binop', '-', {Lt, Rt});
            else
                f = [];
            end
        end % function

        function [eq2var, unmatched_eqs, unmatched_vars] = matchequations(eqasts, eqlhs_symbols, candidates)
        % Match each equation to a unique endogenous variable using bipartite matching.
        %
        % Builds a bipartite graph where an edge connects equation i to candidate
        % variable j iff j appears in equation i AND does not cancel out of the
        % static reduction of equation i (tested via ast.check_factor on the
        % staticised residual). A minimum-cost perfect matching is then computed
        % with matchpairs (Duff-Koster). Edge weights apply stable tie-breakers:
        % prefer a variable that appears on the LHS of the equation, then prefer
        % rarer candidates (Hall-style scarcity), then break remaining ties
        % lexicographically by (equation index, candidate index).
        %
        % INPUTS:
        % - eqasts          [cell]    n×1, each element is a staticised ast tree of the static residual
        %                             of equation i (LHS - RHS, with all time subscripts collapsed).
        %                             check_factor is called on each tree to test whether a candidate
        %                             cancels out of equation i.
        % - eqlhs_symbols   [cell]    n×1, each element is a cell array of symbols appearing in the LHS
        %                             of equation i (used as a tie-breaker hint, not for the admission rule).
        % - candidates      [cell]    m×1, names of candidate endogenous variables
        %
        % OUTPUTS:
        % - eq2var          [cell]    n×1, matched variable name for each equation ('' if unmatched)
        % - unmatched_eqs   [vector]  column vector with indices of equations that could not be matched
        % - unmatched_vars  [cell]    candidate variable names that could not be matched
        %
        % REMARKS:
        % - Returns a partial matching when no perfect matching exists; the caller
        %   inspects unmatched_eqs / unmatched_vars to report the structural gap.
        % - The constructor passes simplified static residuals (ast.staticise().simplify()):
        %   the question that auto-matching answers is "which variable does this equation
        %   pin down in the steady state?", since the equation/variable mapping is mainly
        %   used downstream to assist the user in writing the analytical steady-state
        %   block. Variables that disappear from the simplified static residual (e.g. c
        %   inside a c(t)/c(t+1) factor in an Euler equation) are correctly excluded —
        %   the steady state does not determine them through that equation.
        %
        % REFERENCES:
        % - Assignment problem (linear-sum bipartite matching):
        %   https://en.wikipedia.org/wiki/Assignment_problem
        % - Hall's marriage theorem (perfect-matching feasibility, motivates the
        %   scarcity tiebreaker): https://en.wikipedia.org/wiki/Hall%27s_marriage_theorem
        % - matchpairs (the MATLAB primitive used here, an implementation of
        %   Duff & Koster's algorithm):
        %   https://www.mathworks.com/help/matlab/ref/matchpairs.html
        % - I. S. Duff and J. Koster, "On Algorithms for Permuting Large Entries
        %   to the Diagonal of a Sparse Matrix", SIAM J. Matrix Anal. Appl.,
        %   22(4):973-996, 2001.
            n = numel(eqasts);
            m = numel(candidates);
            eq2var = repmat({''}, n, 1);
            if n == 0 || m == 0
                unmatched_eqs = (1:n)';
                unmatched_vars = candidates(:);
                return
            end
            contains_eq = false(n, m);
            for j = 1:m
                v = candidates{j};
                for i = 1:n
                    [has, cancels] = eqasts{i}.check_factor(v);
                    if has && ~cancels
                        contains_eq(i, j) = true;
                    end
                end
            end
            degree = sum(contains_eq, 1)';
            lhs_has = false(n, m);
            for j = 1:m
                v = candidates{j};
                for i = 1:n
                    if any(strcmp(v, eqlhs_symbols{i}))
                        lhs_has(i, j) = true;
                    end
                end
            end
            % Dense cost matrix: large value forbids non-edges, edge weights
            % encode the LHS bonus, the scarcity penalty, and the lex tiebreak.
            % matchpairs treats unstored sparse entries as cost 0, so dense is mandatory here.
            forbid = 1e6;
            C = forbid * ones(n, m);
            for i = 1:n
                for j = 1:m
                    if contains_eq(i, j)
                        c = 1.0;
                        if lhs_has(i, j)
                            c = c - 0.5;
                        end
                        c = c + 0.1 * degree(j) / (m + 1);
                        c = c + 1e-6 * (i * (m + 1) + j);
                        C(i, j) = c;
                    end
                end
            end
            % costUnmatched between edge cost and forbid forces matchpairs to
            % maximize matching size and never select a forbidden non-edge.
            M = matchpairs(C, 1e3);
            matched_rows = false(n, 1);
            matched_cols = false(m, 1);
            for k = 1:size(M, 1)
                i = M(k, 1);
                j = M(k, 2);
                eq2var{i} = candidates{j};
                matched_rows(i) = true;
                matched_cols(j) = true;
            end
            unmatched_eqs = find(~matched_rows);
            unmatched_vars = candidates(~matched_cols);
        end % function

        function tf = isregexp(str)
        % Check if string contains regular expression metacharacters.
        %
        % Valid symbol names only use letters, digits, and underscores.
        % Any other character indicates a regex pattern.
        %
        % INPUTS:
        % - str    [char]    1×n    string to check
        %
        % OUTPUTS:
        % - tf     [logical] scalar true if string contains regex metacharacters
        %
        % EXAMPLES:
        % modBuilder.isregexp('alpha')       % Returns false
        % modBuilder.isregexp('beta_1')      % Returns false
        % modBuilder.isregexp('beta_.*')     % Returns true (contains . and *)
        % modBuilder.isregexp('theta_\d+')   % Returns true (contains \ and +)
        % modBuilder.isregexp('^alpha')      % Returns true (contains ^)

            % Regex metacharacters to check for
            regexChars = '.*+?^$[]{}()|\\';

            tf = any(ismember(str, regexChars));
        end % function


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
                    if isfield(s, 'steady_state')
                        o.steady_state = s.steady_state;
                    end
                    if isfield(s, 'calibration_swaps')
                        o.calibration_swaps = s.calibration_swaps;
                    end
                else
                    error('modBuilder:loadobj:invalidObject', 'Cannot instantiate a modBuilder object (missing fields).')
                end
            else
                o = s;
            end
        end % function

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
        %
        % REMARKS:
        % - Equations whose tag is missing or does not match an endogenous variable
        %   are matched automatically via bipartite matching (matchequations). The
        %   constructor errors out only if no perfect matching exists.

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

                % First pass: build equation expressions and collect equations
                % that already carry a valid endogenous-variable tag.
                hastag = false(n, 1);
                tagvar = repmat({''}, n, 1);
                for i=1:n
                    equation = JSON.model(i);
                    o.equations{i,modBuilder.EQ_COL_EXPR} = sprintf('%s = %s', equation.lhs, equation.rhs);
                    if isfield(equation, 'tags') && isfield(equation.tags, equationtagname)
                        tname = char(equation.tags.(equationtagname));
                        if ismember(tname, M_.endo_names)
                            hastag(i) = true;
                            tagvar{i} = tname;
                        end
                    end
                end

                % Second pass: when some equations have no valid tag, match them
                % to the remaining endogenous variables using bipartite matching.
                if any(~hastag)
                    untagged_idx = find(~hastag);
                    available = setdiff(M_.endo_names, tagvar(hastag), 'stable');
                    nu = numel(untagged_idx);
                    eqlhs_symbols = cell(nu, 1);
                    eqasts = cell(nu, 1);
                    for k=1:nu
                        i = untagged_idx(k);
                        eqstr = o.equations{i,modBuilder.EQ_COL_EXPR};
                        eqlhs_symbols{k} = modBuilder.getsymbols(char(JSON.model(i).lhs));
                        % Build the static residual AST (LHS - RHS, with leads/lags collapsed)
                        % for the cancellation filter inside matchequations.
                        LHSRHS = strsplit(eqstr, '=');
                        if length(LHSRHS) == 2
                            residual_str = sprintf('(%s) - (%s)', strtrim(LHSRHS{1}), strtrim(LHSRHS{2}));
                        elseif isscalar(LHSRHS)
                            residual_str = strtrim(LHSRHS{1});
                        else
                            error('modBuilder:badEquation', 'Equation #%d contains more than one "=" symbol: %s', i, eqstr)
                        end
                        eqasts{k} = ast(residual_str).staticise().simplify();
                    end
                    [eq2var, umeqs, umvars] = modBuilder.matchequations(eqasts, eqlhs_symbols, available);
                    if ~isempty(umeqs) || ~isempty(umvars)
                        bullets = {};
                        for k = 1:numel(umeqs)
                            i = untagged_idx(umeqs(k));
                            bullets{end+1} = sprintf('  equation #%d: %s', i, o.equations{i,modBuilder.EQ_COL_EXPR}); %#ok<AGROW>
                        end
                        if ~isempty(umvars)
                            bullets{end+1} = sprintf('  unmatched endogenous variables:%s', modBuilder.printlist(umvars));
                        end
                        error('modBuilder:modBuilder:ambiguousEquation', 'Unable to associate every equation with a unique endogenous variable. Provide explicit tags (%s) for these:\n%s', equationtagname, strjoin(bullets, '\n'));
                    end
                    nm = cell(nu, 1);
                    ex = cell(nu, 1);
                    for k=1:nu
                        i = untagged_idx(k);
                        tagvar{i} = eq2var{k};
                        nm{k} = tagvar{i};
                        ex{k} = o.equations{i, modBuilder.EQ_COL_EXPR};
                    end
                    ws = warning('query', 'modBuilder:autoMatch');
                    warning('modBuilder:autoMatch', 'Automatically matched %d untagged equation(s) to endogenous variables.', nu);
                    if strcmp(ws.state, 'on')
                        disp(table(categorical(nm), categorical(ex), 'VariableNames', {'Endogenous', 'Equation'}));
                    end
                end

                % Third pass: populate var / equations / tags / T.equations.
                for i=1:n
                    equation = JSON.model(i);
                    name = tagvar{i};
                    o.var{i,modBuilder.COL_NAME} = name;
                    o.equations{i,modBuilder.EQ_COL_NAME} = name;
                    id = strcmp(name, M_.endo_names);
                    o.var{i,modBuilder.COL_VALUE} = oo_.steady_state(id);

                    if isequal(name, M_.endo_names_long{id})
                        o.var{i,modBuilder.COL_LONG_NAME} = '';
                    else
                        o.var{i,modBuilder.COL_LONG_NAME} = M_.endo_names_long{id};
                    end

                    if isequal(name, M_.endo_names_tex{id})
                        o.var{i,modBuilder.COL_TEX_NAME} = '';
                    else
                        o.var{i,modBuilder.COL_TEX_NAME} = M_.endo_names_tex{id};
                    end

                    o.T.equations.(name) = modBuilder.getsymbols(o.equations{i,modBuilder.EQ_COL_EXPR});
                    o.symbols = unique(horzcat(o.symbols, o.T.equations.(name)));
                    o.T.equations.(name) = setdiff(o.T.equations.(name), name);
                    o.tags.(name).name = name;

                    % Do we need to populate o.tags with other equation tags?
                    if isfield(equation, 'tags')
                        FieldNames = setdiff(fieldnames(equation.tags), {equationtagname, 'name'});
                        % Equation tag name cannot be used if fourth argument is used.
                        for j=1:numel(FieldNames)
                            o.tags.(name).(FieldNames{j}) = char(equation.tags.(FieldNames{j}));
                        end
                    end
                end

                o.updatesymboltables();
                o.symbols = setdiff(o.symbols, fields(o.T.params));
                o.symbols = setdiff(o.symbols, fields(o.T.varexo));
                o.symbols = setdiff(o.symbols, fields(o.T.var));

                if not(isempty(o.symbols))
                    modBuilder.warn_silent('unknown symbols:%s.', modBuilder.printlist(o.symbols))
                end

                %
                % Set date
                %
                o.date = datetime;
            end
        end % function

        function listofsymbols = getallsymbols(o)
        % Return a cell array with all the symbols in a model.
        %
        % INPUTS:
        %  - o              [modBuilder]
        %
        % OUTPUTS:
        % - listofsymbols   [cell]          n×1, each element is a row character array (name of a symbol).
            o.refresh_tables();
            eqnames = fieldnames(o.T.equations);
            listofsymbols = {};
            for i = 1:numel(eqnames)
                listofsymbols = [listofsymbols, o.T.equations.(eqnames{i})]; %#ok<AGROW>
            end
            listofsymbols = unique(listofsymbols);
        end % function

        function  n = size(o, type)
        % Return the number of parameters, endogenous variables, exogenous variables, or equations
        %
        % INPUTS:
        % - o      [modBuilder]
        % - type   [char]           type of symbol: 'parameters', 'exogenous', 'endogenous', or 'equations'
        %
        % OUTPUTS:
        % - n      [integer]        scalar, number of elements of the specified type
            arguments
                o
                type (1,:) char {mustBeNonempty}
            end

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
        end % function

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
            arguments
                o
                varname  (1,:) char {mustBeNonempty}
                equation (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            number_of_loops = length(varargin);

            if not(number_of_loops)
                o = addeq(o, varname, equation);
            else
                indices = unique(regexp(equation, '\$[0-9]*', 'match'));

                % Check the number of indices (for loops)
                if ~isequal(numel(indices), number_of_loops)
                    error('modBuilder:add:indexMismatch', 'The expected number of indices in the equation is %u but the equation has %u indices.', number_of_loops, numel(indices))
                end

                inames = regexp(varname, '\$[0-9]*', 'match');

                if not(isequal(numel(indices), numel(inames))) || ~isempty(setdiff(indices, inames)) || ~isempty(setdiff(inames, indices))
                    error('modBuilder:add:implicitLoopUnsupported', 'This case of implicit loops is not covered. Indices must be the same in the equation and in varname.')
                end

                expanded = modBuilder.expand_templates({varname, equation}, varargin);
                for i = 1:size(expanded, 1)
                    o.add(expanded{i, 1}, expanded{i, 2});
                end
            end
        end % function

        function o = addeq(o, varname, equation)
        % Add an equation to the model and associate an endogenous variable (internal method)
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         1×n, name of an endogenous variable
        % - equation    [char]         1×m, equation expression
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
            arguments
                o
                varname  (1,:) char {mustBeNonempty}
                equation (1,:) char {mustBeNonempty}
            end

            % Validate equation syntax
            modBuilder.validate_equation_syntax(equation)

            % Validate symbol name (checks the reserved-name list)
            modBuilder.validate_symbol_name(varname, 'add')

            if any(ismember(o.equations(:,modBuilder.EQ_COL_NAME), varname))
                error('modBuilder:addeq:alreadyExists', 'Variable "%s" already has an equation. Use the change method if you really want to redefine the equation for "%s".', varname, varname)
            end

            % Validate that the endogenous variable appears in the equation
            symbols_in_eq = modBuilder.getsymbols(equation);
            if ~ismember(varname, symbols_in_eq)
                error('modBuilder:addeq:notInEquation', 'Endogenous variable "%s" does not appear in its equation:\n\n\t%s\n', varname, equation)
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

            o.T.equations.(varname) = symbols_in_eq;
            o.symbols = horzcat(o.symbols, o.T.equations.(varname));
            o.T.equations.(varname) = setdiff(o.T.equations.(varname), varname);
            o.symbols = setdiff(o.symbols, o.symbols(cellfun(@o.issymbol, o.symbols)));
            o.tags.(varname).name = varname;

            % Mark symbol tables as dirty (need updating)
            o.tables_dirty = true;
        end % function

        function o = tag(o, eqname, tagname, value, varargin)
        % Add or change an equation tag in model o.
        %
        % INPUTS:
        % - o           [modBuilder]
        % - eqname      [char]         1×n array, name of an equation
        % - tagname     [char]         1×m array, name of the tag
        % - value       [char]         1×p array, tag value
        % - ...
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object
        %
        % REMARKS:
        % - This method cannot change the name of an equation, tagname=='name' will raise an error.
        % - If eqname contains indices (e.g. 'Y_$1_$2'), then tags are added for all combinations
        %   of values provided as cell arrays of index values in varargin.
        % - The value argument should contain the same indices as eqname.
        % - The tagname argument is not indexed.
        % - If implicit loops are used (eqname contains indices), the number of index value arrays
        %   must match the number of indices in eqname.
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('Y', 'Y = A*K');
        % m.parameter('A', 1.0);
        % m.exogenous('K', 1.0);
        % m.tag('Y', 'desc', 'Production function');
        %
        % % Implicit loops - tag multiple equations
        % m2 = modBuilder();
        % m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
        % m2.parameter('A_$1', 1.0, {1, 2, 3});
        % m2.exogenous('K_$1', 1.0, {1, 2, 3});
        % m2.tag('Y_$1', 'desc', 'Production function for sector $1', {1, 2, 3});
        %
        % % Multiple indices
        % Countries = {'FR', 'DE'};
        % Sectors = {1, 2};
        % m3 = modBuilder();
        % m3.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
        % m3.parameter('A_$1_$2', 1.0, Countries, Sectors);
        % m3.exogenous('K_$1_$2', 1.0, Countries, Sectors);
        % m3.tag('Y_$1_$2', 'desc', 'Production for $1 in sector $2', Countries, Sectors);
            arguments
                o
                eqname  (1,:) char {mustBeNonempty}
                tagname (1,:) char {mustBeNonempty}
                value   (1,:) char
            end
            arguments (Repeating)
                varargin
            end

            if strcmp(tagname, 'name')
                error('modBuilder:tag:invalidUsage', 'Method tag cannot be used to change the name of an equation. Instead, use the rename method to change the name of an endogenous variable.')
            end

            if ~isempty(modBuilder.placeholders(eqname))
                expanded = modBuilder.expand_templates({eqname, value}, varargin);
                for i = 1:size(expanded, 1)
                    o.tag(expanded{i, 1}, tagname, expanded{i, 2});
                end
                return;
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
            arguments
                o
                pname (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            % Implicit-loop dispatch.
            if ~isempty(modBuilder.placeholders(pname))
                o.handle_implicit_loops(pname, 'parameter', varargin{:});
                return
            end

            % Parse positional value (varargin{1}) and remaining optional pairs.
            if isempty(varargin)
                pvalue = NaN;  opts = {};
            elseif isempty(varargin{1})
                pvalue = NaN;  opts = varargin(2:end);
            else
                pvalue = varargin{1};  opts = varargin(2:end);
            end

            o = o.declare_symbol('parameter', pname, pvalue, opts{:});
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
            arguments
                o
                xname (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            % Implicit-loop dispatch.
            if ~isempty(modBuilder.placeholders(xname))
                o.handle_implicit_loops(xname, 'exogenous', varargin{:});
                return
            end

            % Parse positional value (varargin{1}) and remaining optional pairs.
            if isempty(varargin)
                xvalue = NaN;  opts = {};
            elseif isempty(varargin{1})
                xvalue = NaN;  opts = varargin(2:end);
            else
                xvalue = varargin{1};  opts = varargin(2:end);
            end

            o = o.declare_symbol('exogenous', xname, xvalue, opts{:});
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
            arguments
                o
                ename (1,:) char {mustBeNonempty}
                evalue = []                         % numeric scalar, [], or cell for implicit loops
            end
            arguments (Repeating)
                varargin
            end

            % Implicit-loop dispatch (evalue is a positional arg, not in varargin).
            if ~isempty(modBuilder.placeholders(ename))
                if nargin < 3 || isempty(evalue)
                    o.handle_implicit_loops(ename, 'endogenous', varargin{:});
                else
                    o.handle_implicit_loops(ename, 'endogenous', evalue, varargin{:});
                end
                return
            end

            % "Missing value" preserves the existing one (long-run level set
            % by add/load); falls back to NaN only if no row exists yet.
            % This is the distinguishing default from parameter/exogenous.
            if nargin < 3 || isempty(evalue)
                existing = ismember(o.var(:,modBuilder.COL_NAME), ename);
                if any(existing) && ~isempty(o.var{existing, modBuilder.COL_VALUE})
                    evalue = o.var{existing, modBuilder.COL_VALUE};
                else
                    evalue = NaN;
                end
            end

            o = o.declare_symbol('endogenous', ename, evalue, varargin{:});
        end % function

        function o = steady(o, varname, expression, varargin)
        % Define an analytical steady-state expression for an endogenous variable or parameter.
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         1×n array, name of an endogenous variable or parameter
        % - expression  [char]         1×m array, RHS expression string
        % - ...
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object
        %
        % REMARKS:
        % - The variable must be a known endogenous variable or parameter (error if exogenous or unknown).
        % - If varname already has a steady-state expression, it is replaced in place (preserving row position).
        % - If varname contains indices (e.g. 'Y_$1'), then expressions are defined for all combinations
        %   of values provided as cell arrays of index values at the end of varargin.
        % - No expression content validation is performed here (deferred to checksteady()).
        % - The expressions generate a steady_state_model block in the exported .mod file when
        %   write() is called with steady_state_model=true.
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('y', 'y = k^alpha');
        % m.add('c', 'c = y - delta*k');
        % m.add('k', '1/beta = alpha*y(+1)/k + (1-delta)');
        % m.parameter('alpha', 0.36);
        % m.parameter('beta', 0.99);
        % m.parameter('delta', 0.025);
        %
        % % Define analytical steady-state expressions
        % m.steady('k', '(alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha))');
        % m.steady('y', 'k^alpha');
        % m.steady('c', 'y - delta*k');
        %
        % % Parameter computed from steady-state values
        % m.parameter('labor_share', NaN);
        % m.steady('labor_share', '1 - alpha*y/k');
        %
        % % Implicit loops
        % m2 = modBuilder();
        % m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
        % m2.parameter('A_$1', 1.0, {1, 2, 3});
        % m2.exogenous('K_$1', 1.0, {1, 2, 3});
        % m2.steady('Y_$1', 'A_$1*K_$1', {1, 2, 3});
            arguments
                o
                varname    (1,:) char {mustBeNonempty}
                expression (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            if ~isempty(modBuilder.placeholders(varname))
                expanded = modBuilder.expand_templates({varname, expression}, varargin);
                for i = 1:size(expanded, 1)
                    o.steady(expanded{i, 1}, expanded{i, 2});
                end
                return;
            end

            % Base case: validate that varname is a known endogenous variable or parameter
            if ~(ismember(varname, o.var(:,modBuilder.COL_NAME)) || ismember(varname, o.params(:,modBuilder.COL_NAME)))
                if ismember(varname, o.varexo(:,modBuilder.COL_NAME))
                    error('modBuilder:steady:notEndogenous', 'Cannot define a steady-state expression for exogenous variable "%s".', varname)
                else
                    error('modBuilder:steady:unknownSymbol', 'Symbol "%s" is not a known endogenous variable or parameter.', varname)
                end
            end

            % Check if varname already has a steady-state expression
            idx = strcmp(varname, o.steady_state(:, modBuilder.SS_COL_NAME));

            if any(idx)
                % Replace expression in place (preserving row position)
                o.steady_state{idx, modBuilder.SS_COL_EXPR} = expression;
            else
                % Append new row
                n = size(o.steady_state, 1);
                o.steady_state{n+1, modBuilder.SS_COL_NAME} = varname;
                o.steady_state{n+1, modBuilder.SS_COL_EXPR} = expression;
            end
        end % function

        function o = steady_aux(o, name, expression)
        % Define an auxiliary computed expression in the steady_state_model block.
        %
        % INPUTS:
        % - o            [modBuilder]
        % - name         [char]   1×n array, name of the auxiliary intermediate
        % - expression   [char]   1×m array, RHS expression
        %
        % OUTPUTS:
        % - o            [modBuilder]
        %
        % REMARKS:
        % - Aux variables are local intermediates inside the steady_state_model block.
        %   They are NOT declared as endogenous, exogenous or parameters but can be
        %   referenced by other steady-state assignments. Used by steady_plan to factor
        %   out repeated subexpressions (e.g. the determinant when a simultaneous block
        %   is solved by Bareiss + back-substitution).
        % - The name must not collide with any existing symbol (parameter, exogenous,
        %   endogenous) nor with another aux already defined; both kinds of collision
        %   raise an error.
        % - Aux entries live in o.steady_state alongside variable closed forms; the
        %   topological sort in checksteady orders them correctly via Kahn's algorithm.
            arguments
                o
                name       (1,:) char {mustBeNonempty}
                expression (1,:) char {mustBeNonempty}
            end

            if o.issymbol(name)
                [type, ~] = o.typeof(name);
                error('modBuilder:steady_aux:alreadyExists', 'Auxiliary name "%s" collides with an existing %s.', name, type);
            end
            if ~isempty(o.steady_state) && any(strcmp(name, o.steady_state(:, modBuilder.SS_COL_NAME)))
                error('modBuilder:steady_aux:alreadyExists', 'Auxiliary name "%s" is already defined in the steady-state table.', name);
            end

            n = size(o.steady_state, 1);
            o.steady_state{n+1, modBuilder.SS_COL_NAME} = name;
            o.steady_state{n+1, modBuilder.SS_COL_EXPR} = expression;
        end % function

        function o = calibrate(o, endo_name, target_value, param_name)
        % Declare a calibration role swap: pin an endogenous variable to a target
        % value at the steady state and solve for a parameter whose value is computed
        % to make the swap consistent with the model.
        %
        % INPUTS:
        % - o             [modBuilder]
        % - endo_name     [char]    name of an endogenous variable; will be treated as
        %                           a known constant equal to target_value during
        %                           steady-state analysis.
        % - target_value  [double]  scalar, the steady-state value to pin endo_name to.
        % - param_name    [char]    name of a parameter; will be treated as an unknown
        %                           to be solved during steady-state analysis.
        %
        % OUTPUTS:
        % - o             [modBuilder]
        %
        % REMARKS:
        % - This is a metadata declaration, not a model rewrite: o.var, o.params and
        %   o.varexo are left unchanged. The swap is consumed by steady_plan, which
        %   permutes the unknown set before running the dependency analysis and the
        %   recogniser pipeline.
        % - endo_name must currently be an endogenous variable; param_name must
        %   currently be a parameter; neither may already appear in another
        %   calibration swap. Errors with id 'modBuilder:calibrate' otherwise.
        % - Captures the typical DSGE manoeuvre: pin hours h to 1/3 and solve for the
        %   labour-disutility weight theta; or pin the K/Y ratio and solve for the
        %   depreciation rate. With h fixed, the labour FOC becomes linear in theta —
        %   and the rest of the RBC steady state reduces step-by-step under the
        %   iterated-elimination pipeline.
            arguments
                o
                endo_name    (1,:) char   {mustBeNonempty}
                target_value (1,1) double {mustBeReal}
                param_name   (1,:) char   {mustBeNonempty}
            end

            if ~o.isendogenous(endo_name)
                error('modBuilder:calibrate', '"%s" must be an endogenous variable.', endo_name);
            end
            if ~o.isparameter(param_name)
                error('modBuilder:calibrate', '"%s" must be a parameter.', param_name);
            end
            if ~isempty(o.calibration_swaps)
                if any(strcmp(endo_name, o.calibration_swaps(:, 1)))
                    error('modBuilder:calibrate', 'Endogenous "%s" is already in a calibration swap.', endo_name);
                end
                if any(strcmp(param_name, o.calibration_swaps(:, 3)))
                    error('modBuilder:calibrate', 'Parameter "%s" is already in a calibration swap.', param_name);
                end
            end
            o.refresh_tables();
            if ~isfield(o.T.equations, endo_name) || ~ismember(param_name, o.T.equations.(endo_name))
                error('modBuilder:calibrate', ...
                      ['Parameter "%s" does not appear in the equation paired with "%s"; ' ...
                       'a non-local role swap would require re-running matchequations on the ' ...
                       'swapped unknown set, which is not currently supported.'], param_name, endo_name);
            end

            n = size(o.calibration_swaps, 1);
            o.calibration_swaps{n+1, 1} = endo_name;
            o.calibration_swaps{n+1, 2} = target_value;
            o.calibration_swaps{n+1, 3} = param_name;
        end % function

        function sorted_names = checksteady(o)
        % Validate steady-state expressions and return symbol names in topological order.
        %
        % INPUTS:
        % - o              [modBuilder]
        %
        % OUTPUTS:
        % - sorted_names   [cell]      1×n cell array of symbol names in dependency order
        %
        % REMARKS:
        % - For each expression, all symbols must be known (via issymbol()).
        % - Topological sort uses Kahn's algorithm.
        % - Nodes are symbols in steady_state(:, SS_COL_NAME).
        % - Edge A → B means expression for B references symbol A and A is also a node.
        % - Symbols with only numeric values (not nodes) are treated as leaf constants.
        % - Tie-breaking: when multiple nodes have in-degree 0, the one with the smallest
        %   row index in steady_state is picked first (preserves call order).
        % - Errors on unknown symbols, circular dependencies, or missing values.

            n = size(o.steady_state, 1);

            if n == 0
                sorted_names = {};
                return
            end

            node_names = o.steady_state(:, modBuilder.SS_COL_NAME)';

            % Build adjacency and in-degree
            in_degree = zeros(1, n);
            % adj{i} = list of node indices that depend on node i (i.e. i → j)
            adj = cell(1, n);
            for i = 1:n
                adj{i} = [];
            end

            for i = 1:n
                expr = o.steady_state{i, modBuilder.SS_COL_EXPR};
                syms_in_expr = modBuilder.getsymbols(expr);
                for j = 1:numel(syms_in_expr)
                    sym = syms_in_expr{j};
                    % If sym is itself a node in the steady-state table (a model variable
                    % with a steady-state expression OR an auxiliary intermediate added by
                    % steady_aux), record the dependency edge. Otherwise it must be a
                    % declared model symbol — error if it isn't.
                    node_idx = find(strcmp(sym, node_names));
                    if ~isempty(node_idx)
                        % Edge: node_idx → i (sym must be computed before node i)
                        adj{node_idx}(end+1) = i;
                        in_degree(i) = in_degree(i) + 1;
                    elseif ~o.issymbol(sym)
                        error('modBuilder:checksteady:unknownSymbol', 'Unknown symbol "%s" in steady-state expression for "%s".', sym, node_names{i})
                    end
                end
            end

            % Kahn's algorithm with stable tie-breaking (smallest row index first)
            sorted_names = cell(1, n);
            count = 0;

            for iter = 1:n
                % Find all nodes with in-degree 0
                candidates = find(in_degree == 0);
                if isempty(candidates)
                    % Remaining nodes form a cycle
                    remaining = node_names(in_degree > 0);
                    error('modBuilder:checksteady:circularDep', 'Circular dependency detected among steady-state expressions: %s.', strjoin(remaining, ', '))
                end
                % Tie-breaking: pick the candidate with smallest original row index
                chosen = candidates(1);
                count = count + 1;
                sorted_names{count} = node_names{chosen};
                % Mark as processed (set in-degree to -1 so it won't be picked again)
                in_degree(chosen) = -1;
                % Reduce in-degree for dependents
                for j = adj{chosen}
                    in_degree(j) = in_degree(j) - 1;
                end
            end
        end % function

        function o = remove(o, eqname, varargin)
        % Remove an equation from the model, remove one endogenous variable, remove unecessary parameters and exogenous variables
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqname     [char]            1×n array, name of an equation (or endogenous variable associated to an equation)
        % - ...
        %
        % OUTPUTS:
        % - o          [modBuilder]      updated object
        %
        % REMARKS:
        % - Clears symbol_map to force typeof() to use linear search during removals
        % - This prevents stale index references after deletions
        % - If eqname contains indices (e.g. 'Y_$1_$2'), then equations are removed for all combinations of values provided
        %   as cell arrays of index values in varargin.
        % - If implicit loops are used (eqname contains indices), the number of index value arrays must match the number of indices in eqname.
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = w*h');
        % m.add('y', 'y = c + i');
        % m.parameter('w', 1.5);
        %
        % % Remove the consumption equation
        % m.remove('c');  % Also removes h if it doesn't appear elsewhere
        %
        % % Implicit loops - remove multiple equations
        % m2 = modBuilder();
        % m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
        % m2.parameter('A_$1', 1.0, {1, 2, 3});
        % m2.exogenous('K_$1', 1.0, {1, 2, 3});
        % m2.remove('Y_$1', {1, 3});  % Removes Y_1 and Y_3, keeps Y_2
        %
        % % Multiple indices
        % Countries = {'FR', 'DE'};
        % Sectors = {1, 2};
        % m3 = modBuilder();
        % m3.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
        % m3.parameter('A_$1_$2', 1.0, Countries, Sectors);
        % m3.exogenous('K_$1_$2', 1.0, Countries, Sectors);
        % m3.remove('Y_$1_$2', {'FR'}, {1, 2});  % Removes Y_FR_1 and Y_FR_2
            arguments
                o
                eqname (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

            % Check if equation name contains implicit loop indices (e.g., 'Y_$1_$2')
            if ~isempty(modBuilder.placeholders(eqname))
                expanded = modBuilder.expand_templates({eqname}, varargin);
                for i = 1:size(expanded, 1)
                    o.remove(expanded{i, 1});
                end
                return;
            end

            % Clear symbol_map so typeof() uses linear search (safe during deletions)
            o.symbol_map = [];

            ide = ismember(o.equations(:,modBuilder.EQ_COL_NAME), eqname);

            if not(any(ide))
                error('modBuilder:remove:unknownSymbol', 'Unknown equation "%s".', eqname)
            end

            o.equations(ide,:) = [];
            o.tags = rmfield(o.tags, eqname);

            % Remove steady-state expression for this endogenous variable if present
            ss_idx = strcmp(eqname, o.steady_state(:, modBuilder.SS_COL_NAME));
            if any(ss_idx)
                o.steady_state(ss_idx, :) = [];
            end

            for i=1:length(o.T.equations.(eqname))
                symname = o.T.equations.(eqname){i};

                % Skip unknown symbols (they're in symbols list and will be cleaned up elsewhere)

                if ~o.issymbol(symname)
                    continue
                end

                [type, id] = o.typeof(symname);

                if not(o.appear_in_more_than_one_equation(symname))
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

            % Mark symbol tables as dirty (need updating)
            o.tables_dirty = true;
        end % function

        function o = rm(o, varargin)
        % Remove multiple equations from the model in one call
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqname1    [char]            name of an equation (endogenous variable)
        % - eqname2    [char]            name of another equation (optional)
        % - ...        [char]            additional equation names (optional)
        % - idx1       [numeric/char]    first index values for implicit loops (if equation names contain $)
        % - ...        [numeric/char]    additional index values (if needed)
        %
        % OUTPUTS:
        % - o          [modBuilder]      updated object
        %
        % REMARKS:
        % - This is a convenience method that calls remove() for each equation
        % - Duplicate equation names are handled automatically
        % - Supports implicit loops: if equation names contain $ placeholders (e.g., 'eq$1'),
        %   the last arguments should be index values that will be expanded
        % - When using implicit loops with multiple equations, all equation names must
        %   contain the same index placeholders
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k');
        % m.add('y', 'y = k^alpha');
        %
        % % Remove multiple equations
        % m.rm('c', 'y');
        %
        % % Remove indexed equations with implicit loop
        % m.rm('eq$1', 1:3);  % Removes eq1, eq2, eq3
        %
        % % Remove multiple indexed equations
        % m.rm('eq$1', 'var$1', 1:2);  % Removes eq1, var1, eq2, var2
            arguments
                o
            end
            arguments (Repeating)
                varargin
            end

            if isempty(varargin)
                error('modBuilder:rm:missingArg', 'rm method requires at least one equation name.')
            end
            eqnames = varargin(1); % First equation to be removed.
            if not(ischar(eqnames{1}) && isrow(eqnames{1}))
                error('modBuilder:rm:badType', 'First input argument must be a row char array (equation name).')
            end
            % Is the first equation name indexed?
            inames = modBuilder.placeholders(eqnames{1});
            if not(isempty(inames))
                nindices = numel(inames);
                % Check that the last nindices arguments are index values
                idValues = varargin(end-nindices+1:end);
                try
                    [~, ~] = modBuilder.check_indices_values(idValues);
                catch
                    error('modBuilder:rm:indexMismatch', 'Last %u arguments are not valid indices values.', nindices)
                end
                % Is there more than one indexed equation name?
                if length(varargin) > nindices + 1
                    eqnames = varargin(1:end-nindices);
                end
                if length(eqnames) > 1
                    % Remove duplicates
                    eqnames = unique(eqnames);
                    % Check that all equation names contain the same indices
                    for i=2:length(eqnames)
                        tmp = modBuilder.placeholders(eqnames{i});
                        if not(isempty(setxor(inames, tmp)))
                            error('modBuilder:rm:indexMismatch', 'All indexed equation names must contain the same indices.')
                        end
                    end
                end
                % Call remove method (which will expand the indices internally)
                for i=1:length(eqnames)
                    o.remove(eqnames{i}, idValues{:});
                end
            else
                % No implicit loops, simply call remove for each equation name
                if not(all(cellfun(@(x) ischar(x) && isrow(x), varargin)))
                    error('modBuilder:rm:badType', 'All input arguments must be row char arrays (equation names).')
                end
                % Remove duplicates
                eqnames = unique(varargin);
                for i=1:length(eqnames)
                    o.remove(eqnames{i});
                end
            end
        end % function

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
            arguments
                o
                oldsymbol (1,:) char {mustBeNonempty}
                newsymbol (1,:) char {mustBeNonempty}
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

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

            % Rename in every equation via an AST walk: parse each side of '=',
            % rewrite matching sym / tsym / ss leaves, render back. This avoids
            % the regex word-boundary edge cases of the previous text-based rewrite.
            for i=1:o.size('equations')
                eq_str = o.equations{i,modBuilder.EQ_COL_EXPR};
                LHSRHS = strsplit(eq_str, '=');
                if length(LHSRHS) == 2
                    new_lhs = ast(strtrim(LHSRHS{1})).rename(oldsymbol, newsymbol).string();
                    new_rhs = ast(strtrim(LHSRHS{2})).rename(oldsymbol, newsymbol).string();
                    o.equations{i,modBuilder.EQ_COL_EXPR} = sprintf('%s = %s', new_lhs, new_rhs);
                elseif isscalar(LHSRHS)
                    o.equations{i,modBuilder.EQ_COL_EXPR} = ast(strtrim(LHSRHS{1})).rename(oldsymbol, newsymbol).string();
                else
                    error('modBuilder:rename:multipleEquals', 'rename: equation #%d contains more than one "=" symbol.', i)
                end
                o.T.equations.(o.equations{i,modBuilder.EQ_COL_NAME}) = modBuilder.replaceincell(o.T.equations.(o.equations{i,modBuilder.EQ_COL_NAME}), oldsymbol, newsymbol);
            end

            % Update steady-state expressions (same AST walk; expressions are pure RHS,
            % no '=' to split on).
            for i=1:size(o.steady_state, 1)
                if strcmp(o.steady_state{i, modBuilder.SS_COL_NAME}, oldsymbol)
                    o.steady_state{i, modBuilder.SS_COL_NAME} = newsymbol;
                end
                o.steady_state{i, modBuilder.SS_COL_EXPR} = ast(o.steady_state{i, modBuilder.SS_COL_EXPR}).rename(oldsymbol, newsymbol).string();
            end

            % Mark symbol tables as dirty (need updating)
            o.tables_dirty = true;
        end % function

        function o = write(o, filename, options)
        % Write model to a Dynare .mod file.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - filename  [char]         1×n    name of the output file (with or without .mod extension)
        %
        % OPTIONAL NAME-VALUE ARGUMENTS:
        % - initval              [logical]  Include an initval block with initial values for endogenous variables (default: false)
        % - steady               [logical]  Call steady after the initval block (default: false). A warning is issued if initval is false.
        % - steady_state_model   [logical]  Include a steady_state_model block with analytical expressions (default: false)
        % - steady_options       [cell]     Options for the steady command as key-value pairs, e.g. {'maxit', 100, 'nocheck'} (default: {})
        % - check                [logical]  Call check after steady (default: false). An error is thrown if steady is false.
        % - precision            [integer]  Number of significant digits for numerical values (default: 6 decimal places)
        %
        % OUTPUTS:
        % - o         [modBuilder]   The model object (unchanged)
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = alpha*k');
        % m.parameter('alpha', 0.33);
        %
        % % Write to file 'mymodel.mod'
        % m.write('mymodel.mod');
        %
        % % Write with higher precision (15 significant digits)
        % m.write('mymodel.mod', precision=15);
        %
        % % Write with initval block
        % m.write('mymodel.mod', initval=true);
        %
        % % Write with initval, steady, and check
        % m.write('mymodel.mod', initval=true, steady=true, check=true);
        %
        % % Write with steady options
        % m.write('mymodel.mod', initval=true, steady=true, steady_options={'maxit', 100, 'nocheck'});
        %
        % % Combine options
        % m.write('mymodel.mod', initval=true, precision=10);

            arguments
                o modBuilder
                filename (1,:) char
                options.initval (1,1) logical = false
                options.steady (1,1) logical = false
                options.steady_state_model (1,1) logical = false
                options.steady_options (1,:) cell = {}
                options.check (1,1) logical = false
                options.precision (1,1) {mustBeNonnegative, mustBeInteger} = 0
            end

            if options.check && ~options.steady
                error('modBuilder:write:incompatibleOptions', 'Option ''check'' requires option ''steady'' to be true.');
            end
            if ~isempty(options.steady_options) && ~options.steady
                error('modBuilder:write:incompatibleOptions', 'Option ''steady_options'' requires option ''steady'' to be true.');
            end
            if options.steady_state_model && isempty(o.steady_state)
                error('modBuilder:write:missingValue', 'Option ''steady_state_model'' requires at least one steady-state expression (use the steady() method).');
            end
            if options.steady && ~options.initval && ~options.steady_state_model
                warning('modBuilder:steadyWithoutInitval', ...
                        'Option ''steady'' is used without ''initval''. The steady command may fail without initial values.');
            end

            % Handle file extension: append .mod if not present
            % (.dyn is also a valid Dynare extension)
            if ~endsWith(filename, '.mod') && ~endsWith(filename, '.dyn')
                filename = [filename, '.mod'];
            end

            % Set number format
            % Default (precision=0): use %f (6 decimal places) for backward compatibility
            % When specified: use %.Ng (N significant digits)
            if options.precision > 0
                numFormat = sprintf('%%.%dg', options.precision);
            else
                numFormat = '%f';
            end

            fid = fopen(filename, 'w');
            cleanup = onCleanup(@() fclose(fid));

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
            paramFormat = ['%s = ', numFormat, ';\n'];
            for i=1:size(calibrated_params, 1)
                fprintf(fid, paramFormat, ...
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
                    extra_tags = setdiff(tagnames, 'name');
                    for j = 1:numel(extra_tags)
                        fprintf(fid, ', %s = ''%s''', extra_tags{j}, Tags.(extra_tags{j}));
                    end

                    fprintf(fid, ']\n');
                end

                fprintf(fid, '%s;\n\n', o.equations{i,modBuilder.EQ_COL_EXPR});
            end

            fprintf(fid, 'end;\n');

            if options.steady_state_model
                %
                % Print steady_state_model block
                %
                sorted_names = o.checksteady();
                fprintf(fid, '\nsteady_state_model;\n\n');
                for i=1:numel(sorted_names)
                    ss_idx = strcmp(sorted_names{i}, o.steady_state(:, modBuilder.SS_COL_NAME));
                    fprintf(fid, '\t%s = %s;\n', sorted_names{i}, o.steady_state{ss_idx, modBuilder.SS_COL_EXPR});
                end
                fprintf(fid, '\nend;\n');
            end

            if options.initval
                %
                % Print initial values if any
                %
                if ~all(isnan([o.var{:, modBuilder.COL_VALUE}]))
                    fprintf(fid, '\ninitval;\n\n');
                    initvalFormat = ['\t%s = ', numFormat, ';\n'];
                    for i=1:o.size('endogenous')
                        if ~isnan(o.var{i, modBuilder.COL_VALUE})
                            fprintf(fid, initvalFormat, o.var{i, modBuilder.COL_NAME}, o.var{i, modBuilder.COL_VALUE});
                        end
                    end
                    fprintf(fid, '\nend; // initval block\n');
                end
            end

            if options.steady
                fprintf(fid, '\nsteady%s;\n', modBuilder.format_dynare_options(options.steady_options, modBuilder.STEADY_STANDALONE_FLAGS));
            end

            if options.check
                fprintf(fid, '\ncheck;\n');
            end

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
            s.steady_state = o.steady_state;
            s.T = o.T;
            s.date = o.date;
            s.calibration_swaps = o.calibration_swaps;
        end % function

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
        % - Uses dictionary for O(1) symbol type lookups
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
            o.update_symbol_map();

            % Single pass through equations (O(n_equations × avg_symbols))
            for j=1:size(o.equations, 1)
                eqname = o.equations{j, modBuilder.EQ_COL_NAME};
                Symbols = o.T.equations.(eqname);

                % For each symbol in equation, determine its type and add equation reference
                for k=1:length(Symbols)
                    sym = Symbols{k};

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

            % Mark tables as clean (up-to-date)
            o.tables_dirty = false;
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
            arguments
                o
                name (1,:) char {mustBeNonempty}
            end
            [found, type, ~] = o.lookup_symbol(name);
            b = found && strcmp(type, 'parameter');
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
            arguments
                o
                name (1,:) char {mustBeNonempty}
            end
            [found, type, ~] = o.lookup_symbol(name);
            b = found && strcmp(type, 'exogenous');
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
            arguments
                o
                name (1,:) char {mustBeNonempty}
            end
            [found, type, ~] = o.lookup_symbol(name);
            b = found && strcmp(type, 'endogenous');
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
            arguments
                o
                name (1,:) char {mustBeNonempty}
            end
            b = o.lookup_symbol(name);
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
        % - id       [integer]         scalar, row position of the symbol in the corresponding table
        %
        % REMARKS:
        % - Uses O(1) hash map lookup when symbol_map is available
        % - Falls back to O(n) linear search if symbol_map is not initialized
        % - Significantly faster for repeated lookups in large models
        % - Each symbol name is unique within its type, so id is always a scalar.
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
            arguments
                o
                name (1,:) char {mustBeNonempty}
            end
            [found, type, id] = o.lookup_symbol(name);
            if ~found
                error('modBuilder:typeof:unknownType', 'Unknown type for symbol "%s".', name)
            end
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

            % Auto-update symbol tables if needed
            o.refresh_tables();

            if o.isparameter(name)
                b = length(o.T.params.(name))>1;
            elseif o.isexogenous(name)
                b = length(o.T.varexo.(name))>1;
            elseif o.isendogenous(name)
                b = length(o.T.var.(name))>1;
            else
                error('modBuilder:appear_in_more_than_one_equation:badType', 'Unknown symbol type.')
            end
        end % function

        function o = lookfor(o, name)
        % Print equations where symbol 'name' appears.
        %
        % Supports both exact symbol names and regular expression patterns.
        % Regex patterns are auto-detected by the presence of special characters.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - name      [char]         1×n    name of a symbol or regex pattern
        %
        % OUTPUTS:
        % - o         [modBuilder]
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('c', 'c = w*h');
        % m.add('y', 'y = c + i');
        % m.add('i', 'i = delta*k');
        % m.parameter('w', 1.5);
        % m.parameter('delta', 0.1);
        % m.parameter('beta_1', 0.5);
        % m.parameter('beta_2', 0.3);
        %
        % % Find all equations containing 'c' (exact match)
        % m.lookfor('c');
        % % Output: Endogenous variable c appears in 2 equations:
        % %         [c]  c = w*h
        % %         [y]  y = c + i
        %
        % % Find all symbols matching regex pattern
        % m.lookfor('beta_.*');
        % % Output: Found 2 symbols matching pattern 'beta_.*':
        % %         Parameter beta_1 appears in ...
        % %         Parameter beta_2 appears in ...
            arguments
                o
                name (1,:) char {mustBeNonempty}
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

            % Auto-detect regex usage
            if modBuilder.isregexp(name)
                % Regex mode: find all matching symbols and recursively call lookfor
                matches = o.findsymbol(name);

                modBuilder.skipline()

                if isempty(matches)
                    modBuilder.dprintf('No symbols matching pattern ''%s'' found.', name);
                    modBuilder.skipline()
                else
                    if isscalar(matches)
                        modBuilder.dprintf('Found 1 symbol matching pattern ''%s'':', name);
                    else
                        modBuilder.dprintf('Found %u symbols matching pattern ''%s'':', length(matches), name);
                    end
                    modBuilder.skipline()

                    % Recursively call lookfor for each matching symbol
                    % This reuses the exact match display logic
                    for i = 1:length(matches)
                        o.lookfor(matches(i).name);
                        if i < length(matches)
                            modBuilder.skipline()
                        end
                    end
                end
            else
                % Exact match mode (original behaviour)
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
                    modBuilder.dprintf('Symbol %s does not appear in any of the equations.', name);
                    modBuilder.skipline()
                else
                    n = length(eqnames);

                    if n>1
                        modBuilder.dprintf('%s %s appears in %u equations:', symboltype, name, n);
                    else
                        modBuilder.dprintf('%s %s appears in one equation:', symboltype, name);
                    end

                    for i=1:n
                        equation = o.equations(strcmp(eqnames{i}, o.equations(:,modBuilder.EQ_COL_NAME)),2);
                        modBuilder.skipline()
                        modBuilder.dprintf('[%s]\t\t%s', o.tags.(eqnames{i}).name, equation{1});
                    end

                    modBuilder.skipline()
                end
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

            modBuilder.dprintf('\nModel Summary');
            modBuilder.dprintf('=============');
            modBuilder.dprintf('Created: %s\n', char(o.date));

            % Count calibrated and uncalibrated parameters
            n_params = o.size('parameters');

            if n_params > 0
                n_params_calibrated = sum(~cellfun(@isnan, o.params(:, modBuilder.COL_VALUE)));
                n_params_uncalibrated = n_params - n_params_calibrated;
                modBuilder.dprintf('Parameters: %d (%d calibrated, %d uncalibrated)', ...
                        n_params, n_params_calibrated, n_params_uncalibrated);
            else
                modBuilder.dprintf('Parameters: 0');
            end

            modBuilder.dprintf('Endogenous: %d', o.size('endogenous'));
            modBuilder.dprintf('Exogenous: %d', o.size('exogenous'));
            modBuilder.dprintf('Equations: %d', o.size('equations'));

            if ~isempty(o.symbols)
                modBuilder.dprintf('\nWarning: %d untyped symbol(s)', length(o.symbols));
            end

            modBuilder.skipline();
        end % function


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
            arguments
                o
                type (1,:) char {mustBeNonempty}
            end

            % Validate type
            switch type
                case 'parameters'
                    data = o.params;
                case 'exogenous'
                    data = o.varexo;
                case 'endogenous'
                    data = o.var;
                otherwise
                    error('modBuilder:table:unknownType', 'Unknown type: %s. Valid types are: parameters, exogenous, endogenous', type);
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
        end % function


        function varargout = equationmap(o)
        % Display or return the mapping between endogenous variables and equations.
        %
        % INPUTS:
        % - o    [modBuilder]
        %
        % OUTPUTS:
        % - tbl  [table]    columns: Endogenous, Equation. Returned only when nargout > 0.
        %
        % EXAMPLES:
        % m.equationmap();           % print the mapping to the console
        % t = m.equationmap();       % return the mapping as a MATLAB table
            n = size(o.equations, 1);
            if n == 0
                tbl = table(categorical([]), categorical([]), 'VariableNames', {'Endogenous', 'Equation'});
            else
                names = categorical(o.equations(:, modBuilder.EQ_COL_NAME));
                exprs = categorical(o.equations(:, modBuilder.EQ_COL_EXPR));
                tbl = table(names, exprs, 'VariableNames', {'Endogenous', 'Equation'});
            end
            if nargout > 0
                varargout{1} = tbl;
            else
                disp(tbl);
            end
        end % function


        function o = flip(o, varname, varexoname, varargin)
        % Flip types of varname (initially an endogenous variable)
        % and varexoname (initially an exogenous variable). After the
        % change, the number of endogenous variables is the same, we
        % do not change the equations.
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]          1×n array, name of the variable to be exogenized
        % - varexoname  [char]          1×m array, name of the variable to be endogenized
        % - idx1        [cell/numeric]  index values for implicit loops (optional)
        % - idx2        [cell/numeric]  additional index values (optional)
        % - ...
        %
        % OUTPUTS:
        % - o           [modBuilder]    updated object
        %
        % REMARKS:
        % - If varname and varexoname contain $ placeholders (e.g., 'Y_$1', 'X_$1'),
        %   the method will flip all matching pairs using implicit loop expansion
        % - Both variable names must contain the same index placeholders
        % - The number of index value arrays must match the number of indices
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('y', 'y = a*k');
        % m.parameter('a', 0.33);
        % m.exogenous('k', 1.0);
        %
        % % Simple flip
        % m.flip('y', 'k');  % k becomes endogenous, y becomes exogenous
        %
        % % Implicit loop - flip multiple pairs
        % m2 = modBuilder();
        % m2.add('Y_$1', 'Y_$1 = A_$1*K_$1', {1, 2, 3});
        % m2.parameter('A_$1', 1.0, {1, 2, 3});
        % m2.exogenous('K_$1', 1.0, {1, 2, 3});
        % m2.flip('Y_$1', 'K_$1', {1, 3});  % Flips Y_1↔K_1 and Y_3↔K_3
        %
        % % Multiple indices
        % m3 = modBuilder();
        % Countries = {'FR', 'DE'};
        % Sectors = {1, 2};
        % m3.add('Y_$1_$2', 'Y_$1_$2 = A_$1_$2*K_$1_$2', Countries, Sectors);
        % m3.parameter('A_$1_$2', 1.0, Countries, Sectors);
        % m3.exogenous('K_$1_$2', 1.0, Countries, Sectors);
        % m3.flip('Y_$1_$2', 'K_$1_$2', {'FR'}, {1, 2});  % Flips Y_FR_1↔K_FR_1 and Y_FR_2↔K_FR_2
            arguments
                o
                varname    (1,:) char {mustBeNonempty}
                varexoname (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

            % Check if variable names contain implicit loop indices
            inames_var = modBuilder.placeholders(varname);
            inames_varexo = modBuilder.placeholders(varexoname);

            if not(isempty(inames_var)) || not(isempty(inames_varexo))
                % Implicit loop mode

                % Validate that both names have the same indices

                if not(isempty(setxor(inames_var, inames_varexo)))
                    error('modBuilder:flip:indexMismatch', 'Both variable names must contain the same index placeholders. Found %s in varname and %s in varexoname.', ...
                          strjoin(inames_var, ', '), strjoin(inames_varexo, ', '))
                end

                nindices = numel(inames_var);

                % Validate number of index arrays

                if not(isequal(numel(varargin), nindices))
                    error('modBuilder:flip:indexMismatch', 'The number of indices in the variable names is %u, but values for %u indices are provided.', ...
                          nindices, numel(varargin))
                end

                % Check that indices are uniform
                [allint, ~] = modBuilder.check_indices_values(varargin);

                % Compute Cartesian product of index values
                mIndex = table2cell(combinations(varargin{:}));

                % Prepare templates for sprintf
                tmp_varname = varname;
                tmp_varexoname = varexoname;

                for i=nindices:-1:1

                    if allint(i)
                        tmp_varname = strrep(tmp_varname, sprintf('$%u',i), '%u');
                        tmp_varexoname = strrep(tmp_varexoname, sprintf('$%u',i), '%u');
                    else
                        tmp_varname = strrep(tmp_varname, sprintf('$%u',i), '%s');
                        tmp_varexoname = strrep(tmp_varexoname, sprintf('$%u',i), '%s');
                    end
                end

                % Flip all matching pairs using recursion

                for i=1:size(mIndex,1)
                    current_varname = sprintf(tmp_varname, mIndex{i,:});
                    current_varexoname = sprintf(tmp_varexoname, mIndex{i,:});
                    o.flip(current_varname, current_varexoname);
                end
            else
                % Simple flip (no implicit loops) - base case
                ie = ismember(o.var(:,modBuilder.COL_NAME), varname);

                if not(any(ie))
                    error('modBuilder:flip:notEndogenous', '"%s" is not a known endogenous variable.', varname)
                end

                ix = ismember(o.varexo(:,modBuilder.COL_NAME), varexoname);

                if not(any(ix))
                    error('modBuilder:flip:notExogenous', '"%s" is not a known exogenous variable.', varexoname)
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

                % Remove steady-state expression for the exogenised variable
                ss_idx = strcmp(varname, o.steady_state(:, modBuilder.SS_COL_NAME));
                if any(ss_idx)
                    o.steady_state(ss_idx, :) = [];
                end
            end

            % Mark symbol tables as dirty (need updating)
            o.tables_dirty = true;
        end % function

        function o = reassign(o, varargin)
        % Cycle the associations between equations and endogenous variables.
        %
        % Uses cycle notation: with two arguments, swaps the equation
        % associations. With three or more, performs a circular permutation
        % where v1's equation moves to v2, v2's to v3, ..., and the last
        % variable's equation moves to v1.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - varargin   [char]        two or more endogenous variable names
        %
        % OUTPUTS:
        % - o          [modBuilder]  updated object
        %
        % REMARKS:
        % - All arguments must be names of endogenous variables
        % - All arguments must be distinct
        % - Tags follow the equation (not the variable)
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('y', 'y = alpha*k');
        % m.add('k', 'k = (1-delta)*k(-1) + i');
        % m.parameter('alpha', 0.33);
        % m.parameter('delta', 0.025);
        % m.exogenous('i', 0);
        %
        % % Swap: y's equation goes to k, k's equation goes to y
        % m.reassign('y', 'k');
        %
        % % Three-way cycle: v1's eq → v2, v2's eq → v3, v3's eq → v1
        % m2 = modBuilder();
        % m2.add('a', 'a = x + y');
        % m2.add('b', 'b = y + z');
        % m2.add('c', 'c = z + x');
        % m2.exogenous('x', 0);
        % m2.exogenous('y', 0);
        % m2.exogenous('z', 0);
        % m2.reassign('a', 'b', 'c');
            arguments
                o
            end
            arguments (Repeating)
                varargin (1,:) char {mustBeNonempty}
            end

            names = varargin;
            n = numel(names);

            % Validate: at least two names required
            if n < 2
                error('modBuilder:reassign:missingArg', 'reassign requires at least two endogenous variable names.');
            end

            % Validate: no duplicates
            if numel(unique(names)) ~= n
                error('modBuilder:reassign:notDistinct', 'All variable names passed to reassign must be distinct.');
            end

            % Validate: all names must be endogenous
            for i = 1:n
                if ~o.isendogenous(names{i})
                    error('modBuilder:reassign:notEndogenous', 'Variable ''%s'' is not endogenous.', names{i});
                end
            end

            % Find equation row indices
            rows = zeros(1, n);
            for i = 1:n
                rows(i) = find(strcmp(names{i}, o.equations(:, modBuilder.EQ_COL_NAME)));
            end

            % Save original expressions and tags
            old_exprs = o.equations(rows, modBuilder.EQ_COL_EXPR);
            old_tags = cell(1, n);
            for i = 1:n
                old_tags{i} = o.tags.(names{i});
            end

            % Cycle: expression of names{i} goes to names{i+1} (wrapping)
            for i = 1:n
                target = mod(i, n) + 1;
                o.equations{rows(target), modBuilder.EQ_COL_EXPR} = old_exprs{i};
                o.tags.(names{target}) = old_tags{i};
            end

            % Mark symbol tables as dirty
            o.tables_dirty = true;
        end % function

        function o = rmflip(o, eqname, newexo, varargin)
        % Remove an equation and exogenise a different variable instead
        %
        % Removes equation eqname, keeps its associated variable endogenous
        % (by flipping it back), and makes newexo exogenous instead.
        %
        % INPUTS:
        % - o       [modBuilder]
        % - eqname  [char]          name of the equation to remove
        % - newexo  [char]          endogenous variable to make exogenous
        % - idx1    [cell/numeric]  index values for implicit loops (optional)
        % - ...
        %
        % OUTPUTS:
        % - o       [modBuilder]    updated object
        %
        % REMARKS:
        % - eqname must be a known equation
        % - newexo must be a known endogenous variable
        % - The variable associated with eqname must appear in newexo's equation,
        %   otherwise the reassigned equation would not determine eqname's variable
        % - Supports implicit loops with $ placeholders (same as flip)
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('y', 'y = a*k');
        % m.add('k', 'k = (1-delta)*k(-1) + i + y');
        % m.parameter('a', 0.33);
        % m.parameter('delta', 0.025);
        % m.exogenous('i', 0);
        %
        % % Remove y's equation, make k exogenous instead
        % m.rmflip('y', 'k');
        % % y stays endogenous (determined by k's former equation), k becomes exogenous
            arguments
                o
                eqname (1,:) char {mustBeNonempty}
                newexo (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

            % Check if names contain implicit loop indices
            inames_eq = modBuilder.placeholders(eqname);
            inames_newexo = modBuilder.placeholders(newexo);

            if ~isempty(inames_eq) || ~isempty(inames_newexo)
                % Implicit loop mode

                % Validate that both names have the same indices
                if ~isempty(setxor(inames_eq, inames_newexo))
                    error('modBuilder:rmflip:indexMismatch', 'Both names must contain the same index placeholders. Found %s in eqname and %s in newexo.', ...
                          strjoin(inames_eq, ', '), strjoin(inames_newexo, ', '))
                end

                nindices = numel(inames_eq);

                % Validate number of index arrays
                if ~isequal(numel(varargin), nindices)
                    error('modBuilder:rmflip:indexMismatch', 'The number of indices in the names is %u, but values for %u indices are provided.', ...
                          nindices, numel(varargin))
                end

                % Check that indices are uniform
                [allint, ~] = modBuilder.check_indices_values(varargin);

                % Compute Cartesian product of index values
                mIndex = table2cell(combinations(varargin{:}));

                % Prepare templates for sprintf
                tmp_eqname = eqname;
                tmp_newexo = newexo;

                for i = nindices:-1:1
                    if allint(i)
                        tmp_eqname = strrep(tmp_eqname, sprintf('$%u', i), '%u');
                        tmp_newexo = strrep(tmp_newexo, sprintf('$%u', i), '%u');
                    else
                        tmp_eqname = strrep(tmp_eqname, sprintf('$%u', i), '%s');
                        tmp_newexo = strrep(tmp_newexo, sprintf('$%u', i), '%s');
                    end
                end

                % Recurse for each combination
                for i = 1:size(mIndex, 1)
                    current_eqname = sprintf(tmp_eqname, mIndex{i,:});
                    current_newexo = sprintf(tmp_newexo, mIndex{i,:});
                    o.rmflip(current_eqname, current_newexo);
                end
            else
                % Base case (no implicit loops)

                % Validate eqname is a known equation
                if ~any(strcmp(eqname, o.equations(:, modBuilder.EQ_COL_NAME)))
                    error('modBuilder:rmflip:unknownSymbol', 'Unknown equation "%s".', eqname)
                end

                % Validate newexo is a known endogenous variable
                if ~o.isendogenous(newexo)
                    error('modBuilder:rmflip:notEndogenous', '"%s" is not a known endogenous variable.', newexo)
                end

                % Critical check: eqname's variable must appear in newexo's equation
                if ~any(strcmp(eqname, o.T.equations.(newexo)))
                    error('modBuilder:rmflip:notInEquation', 'Variable "%s" does not appear in equation "%s". The reassigned equation would not determine "%s".', ...
                          eqname, newexo, eqname)
                end

                % remove(eqname) drops the equation and converts eqname to exogenous
                o.remove(eqname);

                % flip(newexo, eqname) swaps newexo (endo→exo) and eqname (exo→endo)
                o.flip(newexo, eqname);
            end
        end % function

        function o = exogenise(o, varname, eqname, varargin)
        % Make an endogenous variable exogenous by dropping an equation
        %
        % Variable-centric interface to rmflip: makes varname exogenous
        % by removing equation eqname. The variable associated with eqname
        % stays endogenous (determined by varname's former equation).
        %
        % INPUTS:
        % - o        [modBuilder]
        % - varname  [char]          endogenous variable to make exogenous
        % - eqname   [char]          equation to remove
        % - idx1     [cell/numeric]  index values for implicit loops (optional)
        % - ...
        %
        % OUTPUTS:
        % - o        [modBuilder]    updated object
        %
        % REMARKS:
        % - Delegates to rmflip(eqname, varname, ...)
        % - varname must be a known endogenous variable
        % - eqname must be a known equation
        % - eqname's variable must appear in varname's equation
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('y', 'y = a*k');
        % m.add('k', 'k = (1-delta)*k(-1) + i + y');
        % m.parameter('a', 0.33);
        % m.parameter('delta', 0.025);
        % m.exogenous('i', 0);
        %
        % % Make k exogenous by dropping y's equation
        % m.exogenise('k', 'y');
        % % Equivalent to m.rmflip('y', 'k')
            arguments
                o
                varname (1,:) char {mustBeNonempty}
                eqname  (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            o.rmflip(eqname, varname, varargin{:});
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
            p.steady_state = o.steady_state;
            p.calibration_swaps = o.calibration_swaps;
            p.T = o.T;
            p.tags = o.tags;
            p.tables_dirty = o.tables_dirty;
            p.symbol_map = o.symbol_map;
        end % function

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
        % - Compares names, values, symbols, equations, tags, and symbol tables
        % - Order of elements does not matter for cell arrays (treated as sets)
        % - long_name and tex_name attributes are NOT compared (two models differing
        %   only in metadata are considered equal)
            if ~isa(o, 'modBuilder') || ~isa(p, 'modBuilder')
                error('modBuilder:eq:badType', 'Cannot compare modBuilder object with an object from another class.')
            end

            % Auto-update symbol tables if needed for both objects
            o.refresh_tables();
            p.refresh_tables();

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

            if not(modBuilder.isequalcell(o.steady_state, p.steady_state))
                b = false;
                return
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
        end % function

        function o = change(o, varname, equation)
        % Replace an existing equation in the model
        %
        % INPUTS:
        % - o           [modBuilder]
        % - varname     [char]         1×n, name of the endogenous variable (equation name)
        % - equation    [char]         1×m, new equation expression
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
            arguments
                o
                varname  (1,:) char {mustBeNonempty}
                equation (1,:) char {mustBeNonempty}
            end

            % Validate equation syntax
            modBuilder.validate_equation_syntax(equation)

            ide = ismember(o.equations(:,modBuilder.EQ_COL_NAME), varname);

            if not(any(ide))
                error('modBuilder:change:unknownSymbol', 'There is no equation for "%s".', varname)
            end

            % Validate that the endogenous variable appears in the new equation
            allsymbols = modBuilder.getsymbols(equation);
            if ~ismember(varname, allsymbols)
                error('modBuilder:change:notInEquation', 'Endogenous variable "%s" does not appear in its equation:\n\n\t%s\n', varname, equation)
            end

            o.equations{ide,modBuilder.EQ_COL_EXPR} = equation;
            otokens = o.T.equations.(varname);
            ntokens = setdiff(allsymbols, varname);
            o.symbols = [o.symbols, ntokens];

            % Remove symbols that are already known. If o.symbols is empty, it indicates that the updated equation introduces no
            % new symbols. Otherwise, a warning is issued, and the user is expected to provide types for the new symbols.
            o.symbols = setdiff(o.symbols, [o.params(:,modBuilder.COL_NAME); o.varexo(:,modBuilder.COL_NAME); o.var(:,modBuilder.COL_NAME)]);

            if not(isempty(o.symbols))
                % TODO: should remaining symbols be declared as exogenous variables by default?
                modBuilder.warn_silent('Untyped symbol(s):%s.', sprintf(' %s', o.symbols{:}))
            end

            % Do we need to remove some symbols (parameters or exogenous variables)?
            list_of_symbols_potentially_to_be_removed = setdiff(otokens, ntokens);

            % Clear symbol_map so typeof() uses linear search (safe during deletions)
            o.symbol_map = [];

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

            % Mark symbol tables as dirty (need updating)
            o.tables_dirty = true;
        end % function

        function o = subs(o, expr1, expr2, varargin)
        % Replace one expression by another in one or all equations, using AST-based
        % substitution. Both expr1 and expr2 are arbitrary expressions; either can reduce
        % to a single symbol.
        %
        % INPUTS:
        % - o            [modBuilder]
        % - expr1        [char]              1×n array, expression to replace. Either a
        %                                    single symbol (a, beta, mc, ...), in which
        %                                    case the lag-aware ast.substitute primitive
        %                                    is used (matches every lead/lag of the
        %                                    symbol and shifts the replacement accordingly),
        %                                    or any expression (alpha + beta, x*y, mc(-1),
        %                                    STEADY_STATE(K), ...), in which case the
        %                                    structural ast.replace_subtree primitive is
        %                                    used (matches the parsed expression as a
        %                                    whole subtree, after canonicalisation so
        %                                    commutative reorderings still match).
        %                                    May contain $ placeholders for implicit loops.
        % - expr2        [char | ast]        replacement expression (a char is auto-parsed
        %                                    via ast(expr2); only chars may carry
        %                                    $ placeholders).
        % - eqname       [char]              (optional) name of the equation to target
        %                                    (may contain $ placeholders). When omitted,
        %                                    the substitution is applied to every equation.
        % - idx1, ...    [cell/numeric]      index value arrays for the $ placeholders,
        %                                    one per unique placeholder across expr1,
        %                                    expr2, and eqname.
        %
        % OUTPUTS:
        % - o            [modBuilder]        updated object
        %
        % REMARKS:
        % - When expr1 is a single symbol, the substitution is lag-aware: every
        %   occurrence of expr1(±k) becomes the replacement shifted by ±k. Names
        %   declared as parameters in the model are kept time-invariant.
        % - When expr1 is a more complex expression, the match is structural: expr1 is
        %   parsed and canonicalised, then any subtree of the equation that is
        %   structurally equal (modulo commutative reorderings) is replaced by expr2 as
        %   written — no lag-shift.
        % - If expr1 reduces to a single variable that has its own defining equation
        %   and that equation is in scope, the defining equation is rewritten too —
        %   typically into a tautology of the form expr2 = expr2. Call remove(expr1)
        %   afterwards to fully eliminate the variable.
        % - Parameters and exogenous variables that no longer appear in any equation
        %   after the substitution are removed automatically. New symbols introduced by
        %   expr2 enter the untyped pool with the usual warning.
        % - Implicit loops: expr1 and expr2 must contain the same set of $ placeholders;
        %   eqname may share placeholders with them or introduce new ones; index value
        %   arrays are matched to the union of placeholders by position.
        % - Regular-expression patterns on the equation text are not supported here —
        %   use the substitute method instead when a true text-level regex is needed.
        %
        % EXAMPLES:
        % % Replace a defining variable everywhere, then drop the now-tautological equation
        % m = modBuilder();
        % m.add('Y', 'Y = mc * X');
        % m.add('mc', 'mc = w / mpl');
        % m.exogenous('X', 1); m.exogenous('w', 1); m.exogenous('mpl', 1);
        % m.subs('mc', 'w / mpl');
        % m.remove('mc');
        %
        % % Replace only into a specific equation, with a parameter in the replacement
        % m = modBuilder();
        % m.add('Y', 'Y = mc * X');
        % m.add('mc', 'mc = w / mpl');
        % m.exogenous('X', 1); m.exogenous('w', 1); m.exogenous('mpl', 1);
        % m.subs('mc', '(theta-1)/theta * w / mpl', 'Y');
        % m.parameter('theta', 6);
        %
        % % Replace an expression by another expression
        % m.subs('alpha + beta', 'sigma');
        %
        % % Implicit loop: replace alpha_i by a constant in every equation
        % m.subs('alpha_$1', '0.33', {1, 2, 3});
        %
        % % Implicit loop with eqname placeholder reuse
        % m.subs('alpha_$1', 'beta_$1', 'Y_$1', {1, 2, 3});
            arguments
                o
                expr1 (1,:) char {mustBeNonempty}
                expr2                                     % char or ast — runtime-checked below
            end
            arguments (Repeating)
                varargin
            end

            % Parse varargin: at most one char (eqname) followed by index value arrays.
            eqname = '';
            char_count = 0;
            for k = 1:length(varargin)
                if ischar(varargin{k}) && isrow(varargin{k})
                    char_count = char_count + 1;
                    if char_count == 1
                        eqname = varargin{k};
                    else
                        error('modBuilder:subs:multipleArgs', 'subs: only one equation name (char argument) allowed.')
                    end
                else
                    break
                end
            end
            index_values = varargin(char_count+1:end);

            % Detect $ placeholders in each char argument.
            inames_var = modBuilder.placeholders(expr1);
            is_expr2_char = ischar(expr2) || isstring(expr2);
            if is_expr2_char
                expr2_str = char(expr2);
                inames_rep = modBuilder.placeholders(expr2_str);
            else
                expr2_str = '';
                inames_rep = {};
            end
            inames_eq = {};
            if ~isempty(eqname)
                inames_eq = modBuilder.placeholders(eqname);
            end
            has_placeholders = ~isempty(inames_var) || ~isempty(inames_rep) || ~isempty(inames_eq);

            if has_placeholders
                % --- Implicit-loop mode: expand and recurse via the shared helper ---
                if ~is_expr2_char
                    error('modBuilder:subs:badType', 'subs: $ placeholders are only supported when expr2 is a char array.')
                end
                modBuilder.expand_implicit_loops(@(varargin) o.subs(varargin{:}), expr1, expr2_str, eqname, index_values, 'subs', false);
                return
            end

            % --- Base case: no placeholders ---
            if ~isempty(index_values)
                error('modBuilder:subs:placeholderMissing', 'subs: no $ placeholders in arguments, but %d index value array(s) provided.', length(index_values))
            end

            % Parse expr2 (accept either a string or an ast).
            if ischar(expr2) || isstring(expr2)
                expr2_ast = ast(char(expr2));
            elseif isa(expr2, 'ast')
                expr2_ast = expr2;
            else
                error('modBuilder:subs:badType', 'subs: expr2 must be a char array or an ast object.')
            end

            % Determine the equations to operate on.
            if isempty(eqname)
                eqnames = o.equations(:, modBuilder.EQ_COL_NAME);
            else
                ide = strcmp(eqname, o.equations(:, modBuilder.EQ_COL_NAME));
                if not(any(ide))
                    error('modBuilder:subs:unknownSymbol', 'subs: no equation named "%s".', eqname)
                end
                eqnames = {eqname};
            end

            % Parameter names: opaque "do not lag-shift" set passed to ast.substitute.
            if isempty(o.params)
                parameter_names = {};
            else
                parameter_names = o.params(:, modBuilder.COL_NAME)';
            end

            % Detect whether the target is a single symbol (use the lag-aware
            % ast.substitute primitive) or an arbitrary expression (use the
            % structural ast.replace_subtree primitive). A 'tsym' target is treated
            % as a literal subtree so that, e.g., inlining x(-1) does not also
            % rewrite x or x(+1).
            target_ast = ast(expr1);
            target_is_symbol = strcmp(target_ast.type, 'sym');

            % Apply the substitution per equation, splitting on '=' so that LHS and RHS
            % parse as independent ast trees. The dispatch on target_is_symbol picks
            % between lag-aware symbol substitution and structural subtree matching.
            for i = 1:numel(eqnames)
                nm = eqnames{i};
                ide = strcmp(nm, o.equations(:, modBuilder.EQ_COL_NAME));
                eq_str = o.equations{ide, modBuilder.EQ_COL_EXPR};
                LHSRHS = strsplit(eq_str, '=');
                if length(LHSRHS) == 2
                    if target_is_symbol
                        new_lhs = ast(strtrim(LHSRHS{1})).substitute(expr1, expr2_ast, parameter_names).string();
                        new_rhs = ast(strtrim(LHSRHS{2})).substitute(expr1, expr2_ast, parameter_names).string();
                    else
                        new_lhs = ast(strtrim(LHSRHS{1})).replace_subtree(target_ast, expr2_ast).string();
                        new_rhs = ast(strtrim(LHSRHS{2})).replace_subtree(target_ast, expr2_ast).string();
                    end
                    new_eq = sprintf('%s = %s', new_lhs, new_rhs);
                elseif isscalar(LHSRHS)
                    if target_is_symbol
                        new_eq = ast(strtrim(LHSRHS{1})).substitute(expr1, expr2_ast, parameter_names).string();
                    else
                        new_eq = ast(strtrim(LHSRHS{1})).replace_subtree(target_ast, expr2_ast).string();
                    end
                else
                    error('modBuilder:subs:multipleEquals', 'subs: equation "%s" has more than one "=" symbol.', nm)
                end
                o.equations{ide, modBuilder.EQ_COL_EXPR} = new_eq;

                % Refresh T.equations.<eqname> with the new symbol set; track new symbols.
                new_tokens = modBuilder.getsymbols(new_eq);
                new_tokens = setdiff(new_tokens, nm);
                o.T.equations.(nm) = new_tokens;
                o.symbols = [o.symbols, new_tokens];
            end

            % Remove already-typed names from the untyped pool (and warn on the rest).
            o.symbols = setdiff(o.symbols, [o.params(:, modBuilder.COL_NAME); o.varexo(:, modBuilder.COL_NAME); o.var(:, modBuilder.COL_NAME)]);
            if not(isempty(o.symbols))
                modBuilder.warn_silent('Untyped symbol(s):%s.', sprintf(' %s', o.symbols{:}))
            end

            % Rebuild T.params / T.varexo / T.var from the updated equations and drop
            % parameters / exogenous that no longer appear anywhere.
            o.symbol_map = [];
            o.tables_dirty = true;
            o.updatesymboltables();
            for j = size(o.params, 1):-1:1
                pn = o.params{j, modBuilder.COL_NAME};
                if ~isfield(o.T.params, pn) || isempty(o.T.params.(pn))
                    o.params(j, :) = [];
                    if isfield(o.T.params, pn)
                        o.T.params = rmfield(o.T.params, pn);
                    end
                end
            end
            for j = size(o.varexo, 1):-1:1
                xn = o.varexo{j, modBuilder.COL_NAME};
                if ~isfield(o.T.varexo, xn) || isempty(o.T.varexo.(xn))
                    o.varexo(j, :) = [];
                    if isfield(o.T.varexo, xn)
                        o.T.varexo = rmfield(o.T.varexo, xn);
                    end
                end
            end

            % The pruning above shrank o.params / o.varexo after symbol_map
            % was rebuilt by updatesymboltables(), so the map now references
            % dropped symbols. Mark dirty so the next reader rebuilds it.
            o.tables_dirty = true;
        end % function

        function o = substitute(o, expr1, expr2, varargin)
        % Substitute expr1 by expr2 in equation eqname (use regexprep).
        %
        % INPUTS:
        % - o           [modBuilder]
        % - expr1       [char]         1×n array, expression (may contain $ placeholders)
        % - expr2       [char]         1×m array, expression (may contain $ placeholders)
        % - eqname      [char]         equation name (optional, may contain $ placeholders)
        % - idx1        [cell/numeric] index values for placeholders (required if $ present)
        % - idx2        [cell/numeric] additional index values
        % - ...
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object
        %
        % REMARKS:
        % - Same as subs() but uses regex pattern matching (regexprep) instead of literal (strrep)
        % - All char arguments come first, then all index value arrays
            arguments
                o
                expr1 (1,:) char {mustBeNonempty}
                expr2 (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            % Parse arguments: extract char args first, then index values
            eqname = [];
            char_count = 0;

            for i = 1:length(varargin)

                if ischar(varargin{i}) && isrow(varargin{i})
                    char_count = char_count + 1;

                    if char_count == 1
                        eqname = varargin{i};
                    else
                        error('modBuilder:substitute:multipleArgs', 'Only one equation name (char argument) allowed after expr1 and expr2.')
                    end
                else
                    break;
                end
            end

            index_values = varargin(char_count+1:end);

            % Check for implicit loop indices in expr1 only
            % Note: expr2 may contain $ for regex backreferences (e.g., $1), which is allowed
            % We only check expr1 to determine if this is an implicit loop
            inames_expr1 = modBuilder.placeholders(expr1);

            if isempty(inames_expr1)
                % Base case: no implicit loops in expr1
                % Any $ in expr2 is treated as regex syntax (backreferences)

                if ~isempty(index_values)
                    error('modBuilder:substitute:placeholderMissing', 'No $ placeholders in expr1, but index values provided.')
                end

                o.substitution(expr1, expr2, eqname);
                return
            end

            % Implicit-loop mode: expand placeholders and recurse via the shared helper.
            % Variadic closure so the helper can call with 2 or 3 args depending on
            % whether a constant eqname target was supplied.
            modBuilder.expand_implicit_loops(@(varargin) o.substitute(varargin{:}), expr1, expr2, eqname, index_values, 'substitute', true);
        end % function

        function o = substitution(o, expr1, expr2, eqname)
        % Internal method for regex-based substitution: replace expr1 with expr2 in equations.
        %
        % INPUTS:
        % - o           [modBuilder]
        % - expr1       [char]         regex pattern to find
        % - expr2       [char]         replacement expression (may use regex backreferences)
        % - eqname      [char or cell] equation name(s) or [] for all equations
        %
        % OUTPUTS:
        % - o           [modBuilder]   updated object
        %
        % REMARKS:
        % - If eqname is empty, substitution applies to all equations.
        % - Validates that the regex matches exactly one expression.
        % - Automatically uses rename() if substitution affects a symbol across all equations.
        % - Updates symbol tables after substitution.
        % - Warns about new unknown symbols introduced by substitution.
            arguments
                o
                expr1  (1,:) char {mustBeNonempty}
                expr2  (1,:) char
                eqname                          % char, cell of char, or [] (means all equations)
            end

            % Recommend the AST-based subs when the target is syntactically a user symbol
            % identifier: subs performs a tree-based, precedence-safe, lag-aware substitution
            % that the text-based substitute cannot match. Skip the recommendation for Dynare
            % reserved names (log, exp, STEADY_STATE, ...) since subs does not target
            % function / operator names.
            if ~isempty(regexp(expr1, '^[a-zA-Z_]\w*$', 'once')) && ~ismember(expr1, modBuilder.DYNARE_RESERVED_NAMES)
                warning('modBuilder:preferSubs', 'The substitution target "%s" is a single symbol; consider using m.subs("%s", ...) instead, which performs a tree-based, precedence-safe, lag-aware substitution.', expr1, expr1)
            end

            % Test if expr1 is a valid regular expression.
            try
                regexp('', expr1);
            catch
                error('modBuilder:substitution:badRegex', 'You did not provide a valid regular expression.')
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
                        error('modBuilder:substitution:badType', 'Unexpected input type. Last input must be a row character array (designating an equation) or a univariate cell array of row char arrays.')
                    end
                end
            end

            % Test that the regular expression matches only one expression in all the selected equations.
            matches = o.collect_matches(eqnames, expr1);

            if isempty(matches)
                % No match found - issue warning and return without modification
                modBuilder.warn_silent('Pattern "%s" not found in equation(s): %s', expr1, strjoin(eqnames, ', '));
                return
            elseif length(matches)>1
                error('modBuilder:substitution:ambiguousMatch', 'The provided regular expression matches more than one expression in the equation(s).')
            else
                expr0 = matches{1};
            end

            % Can we use the rename method (is the substitution for a symbol in all the equations where it appears)?
            userename = false;

            if o.issymbol(expr0)

                if isequal(numel(eqnames), o.size('equations'))
                    userename = true;
                else
                    % Does the matched symbol appear in other equations?
                    eqnames_ = setdiff(o.equations(:,modBuilder.EQ_COL_NAME), eqnames);
                    matches = o.collect_matches(eqnames_, expr1);

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

            % Resolve eqnames to row indices once, instead of strcmp'ing the
            % whole COL_NAME column on every iteration.
            [~, eqrows] = ismember(eqnames, o.equations(:, modBuilder.EQ_COL_NAME));

            for i=1:numel(eqnames)
                eqname = eqnames{i};
                row = eqrows(i);
                original_eq = o.equations{row, modBuilder.EQ_COL_EXPR};
                new_eq = regexprep(original_eq, expr1, expr2);
                o.equations{row, modBuilder.EQ_COL_EXPR} = new_eq;

                % Check if any change was made
                if strcmp(original_eq, new_eq)
                    % No substitution occurred - pattern not found
                    modBuilder.warn_silent('Pattern "%s" not found in equation "%s"', expr1, eqname);
                    continue; % Skip to next equation
                end

                % Validate the modified equation syntax
                modBuilder.validate_equation_syntax(new_eq)

                Symbols = modBuilder.getsymbols(new_eq);
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
                    % Clear symbol_map so typeof() uses linear search (safe during deletions)
                    o.symbol_map = [];

                    for j=1:length(delsyms)
                        [type, id] = o.typeof(delsyms{j});

                        if ~o.appear_in_more_than_one_equation(delsyms{j})

                            switch type
                              case 'parameter'
                                modBuilder.dprintf('Parameter %s will be removed.', delsyms{j})
                                o.params(id,:) = [];
                              case 'exogenous'
                                modBuilder.dprintf('Exogenous variable %s will be removed.', delsyms{j})
                                o.varexo(id,:) = [];
                              case 'endogenous'
                                modBuilder.dprintf('Endogenous variable %s will be removed.', delsyms{j})
                                o.var(id,:) = [];
                            end
                        else
                            %
                        end
                    end
                end

                o.T.equations.(eqname) = Symbols;
            end

            % Add unknown symbols to symbols list
            if unknown_count > 0
                o.symbols = unique([o.symbols, list_of_unknown_symbols(1:unknown_count)]);
            end

            % Mark symbol tables as dirty (need updating)
            o.tables_dirty = true;
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
            arguments
                o
            end
            arguments (Repeating)
                varargin
            end

            p = copy(o);

            if not(all(ismember(varargin, p.equations(:,modBuilder.EQ_COL_NAME))))
                error('modBuilder:extract:missingValue', 'Equation(s) missing for:%s.', modBuilder.printlist(varargin(~ismember(varargin, p.equations(:,modBuilder.EQ_COL_NAME)))))
            end

            eqnames = setdiff(p.equations(:,modBuilder.EQ_COL_NAME), varargin);

            if ~isempty(eqnames)
                p.rm(eqnames{:});
            end
        end % function

        function eqs = listeqbytag(o, varargin)
        % Return a list of equation names matching tag criteria.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - varargin   name-value pairs: tagname1, tagvalue1, tagname2, tagvalue2, ...
        %              Tag values are interpreted as regular expressions.
        %
        % OUTPUTS:
        % - eqs        [cell]          1×n cell array of equation names (char)
        %
        % REMARKS:
        % - All criteria must be satisfied (AND logic).
        % - Tag values are matched as regular expressions (anchored with ^ and $).
        % - For exact matching, simply pass the literal value (no regex metacharacters).
        % - Returns a unique list (no duplicate equation names).
        % - Raises an error if no equation matches.
        %
        % EXAMPLES:
        % m = modBuilder();
        % m.add('Y_m', 'Y_m = A_m*K_m'); m.add('Y_s', 'Y_s = A_s*K_s');
        % m.parameter('A_m', 1); m.parameter('A_s', 1);
        % m.exogenous('K_m', 1); m.exogenous('K_s', 1);
        % m.tag('Y_m', 'sector', 'manufacturing');
        % m.tag('Y_s', 'sector', 'services');
        %
        % eqs = m.listeqbytag('sector', 'manufacturing');
        % % Returns {'Y_m'}
        %
        % eqs = m.listeqbytag('sector', 'manuf.*');
        % % Returns {'Y_m'}
            arguments
                o
            end
            arguments (Repeating)
                varargin (1,:) char {mustBeNonempty}
            end

            if mod(numel(varargin), 2) ~= 0
                error('modBuilder:listeqbytag:badPair', 'Arguments must be name-value pairs.')
            end

            tagnames  = varargin(1:2:end);
            tagvalues = varargin(2:2:end);

            eqs = {};

            for i = 1:o.size('equations')
                eqname = o.equations{i, modBuilder.EQ_COL_NAME};
                eqtags = o.tags.(eqname);
                match = true;

                for j = 1:numel(tagnames)
                    if ~isfield(eqtags, tagnames{j})
                        match = false;
                        break
                    end

                    if isempty(regexp(eqtags.(tagnames{j}), ['^' tagvalues{j} '$'], 'once'))
                        match = false;
                        break
                    end
                end

                if match
                    eqs{end+1} = eqname; %#ok<AGROW>
                end
            end

            eqs = unique(eqs, 'stable');

            if isempty(eqs)
                error('modBuilder:listeqbytag:noMatch', 'No equation matches the given tag criteria.')
            end
        end % function

        function p = select(o, varargin)
        % Select a submodel based on tag criteria.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - varargin   name-value pairs: tagname1, tagvalue1, tagname2, tagvalue2, ...
        %              Tag values are interpreted as regular expressions.
        %
        % OUTPUTS:
        % - p          [modBuilder]    submodel with matching equations
        %
        % REMARKS:
        % - Combines listeqbytag and extract: first finds matching equation names,
        %   then extracts them into a new modBuilder object.
        % - All criteria must be satisfied (AND logic).
        % - Can also be called via curly brace indexing with a bytag selector:
        %   m{bytag('sector', 'manufacturing')} is equivalent to
        %   m.select('sector', 'manufacturing')
        %
        % EXAMPLES:
        % submodel = m.select('sector', 'manufacturing');
        % submodel = m.select('sector', 'manuf.*', 'type', 'production');
            arguments
                o
            end
            arguments (Repeating)
                varargin
            end

            eqs = o.listeqbytag(varargin{:});
            p = o.extract(eqs{:});
        end % function

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
            arguments
                o
                p (1,1) modBuilder
            end

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

            % Merge steady-state expressions
            q.steady_state = [o.steady_state; p.steady_state];

            % Merge symbol tables
            q = o.merge_symbol_tables(p, q);

            % Update symbol tables for the merged model
            q.updatesymboltables();
        end % function

        function evaleq = evaluate(o, eqname, printflag)
        % Evaluate an equation.
        %
        % INPUTS:
        % - o            [modBuilder]
        % - eqname       [char]         1×n array, name of an equation (endogenous variable)
        % - printflag    [logical]      scalar, print results if true (default is false)
        %
        % OUTPUTS:
        % - evaleq       [struct]       scalar struct with fields:
        %                                 .lhs   [double] evaluation of the LHS member of the equation
        %                                 .rhs   [double] evaluation of the RHS member of the equation
        %                                 .resid [double] evaluation of LHS-RHS
        %
        % REMARKS:
        % If the equation does not contain an '=' symbol — and thus no LHS or RHS — the expression is evaluated as the left-hand
        % side (evaleq.lhs) and its residual (evaleq.resid), while the right-hand side (evaleq.rhs) is set to 0.
            arguments
                o
                eqname    (1,:) char    {mustBeNonempty}
                printflag (1,1) logical = false
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

            %
            % Initialise outputs
            %
            evaleq.lhs = NaN;
            evaleq.rhs = NaN;
            evaleq.resid = NaN;

            %
            % Parse the equation into AST trees (LHS, RHS)
            %
            eqID = strcmp(eqname, o.equations(:,modBuilder.EQ_COL_NAME));
            eq_str = o.equations{eqID, modBuilder.EQ_COL_EXPR};
            LHSRHS = strsplit(eq_str, '=');

            if isscalar(LHSRHS)
                LHS_tree = ast(strtrim(LHSRHS{1}));
                RHS_tree = ast('num', 0, {});
            elseif length(LHSRHS)==2
                LHS_tree = ast(strtrim(LHSRHS{1}));
                RHS_tree = ast(strtrim(LHSRHS{2}));
            else
                error('modBuilder:evaluate:multipleEquals', 'An equation cannot have more than one equal (=) symbol.')
            end

            %
            % Build the value map for every symbol referenced by the equation, including the LHS
            % endogenous itself (which is not listed in T.equations.(eqname))
            %
            Symbols = [o.T.equations.(eqname), {eqname}];
            values = struct();
            for i=1:length(Symbols)
                symbol = Symbols{i};
                values.(symbol) = o.get_value(symbol);
            end

            evaleq.lhs = LHS_tree.eval(values);
            evaleq.rhs = RHS_tree.eval(values);
            evaleq.resid = evaleq.lhs - evaleq.rhs;

            if printflag
                if length(LHSRHS)==2
                    static_eq = sprintf('%s = %s', LHS_tree.staticise().string(), RHS_tree.staticise().string());
                else
                    static_eq = LHS_tree.staticise().string();
                end
                modBuilder.skipline()
                modBuilder.dprintf('Static equation: %s', static_eq);
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
        end % function

        function blocks = steady_plan(o)
        % Compute the structural steady-state plan: SCC decomposition of the dependency graph
        % induced by the variable↔equation pairing.
        %
        % OUTPUT:
        % - blocks    [struct array]   one entry per SCC, in topological order:
        %               .vars         [cell]    endogenous variable names in the block
        %               .eqs          [cell]    equation names paired to those vars (= .vars in this codebase)
        %               .kind         [char]    'trivial' | 'self-recursive' | 'simultaneous'
        %               .deps         [cell]    already-solved endogenous names referenced from this block
        %               .extdeps      [cell]    parameter / exogenous names referenced from this block
        %               .closed_form  [struct array]  one entry per resolved variable, each with
        %                                             fields .var (char) and .expr (char, the RHS).
        %                                             Length 0 if no closed form was found, length 1
        %                                             for singleton blocks closed by ast.isolate,
        %                                             length n for size-n simultaneous blocks closed
        %                                             by Bareiss + back-substitution. Entries are in
        %                                             evaluation order; later assignments may
        %                                             reference earlier-assigned variables by name.
        %
        % REMARKS:
        % - 'trivial':         single equation, the paired variable does not appear in its own equation
        %                      (no self-reference at any lag). Solvable in one step in the recursive order.
        % - 'self-recursive':  single equation, the paired variable appears in its own equation (typically
        %                      via a lag, so the equation staticises to an equation in the variable itself).
        % - 'simultaneous':    SCC of size > 1; the variables are jointly determined by the equations and
        %                      require either further symbolic reduction or a numerical solver.
        % - The dependency analysis collects symbol names from each equation via the AST, regardless of
        %   lag. The static dependency graph and its SCC structure are identical to what one obtains by
        %   first staticising every equation, since name equality is unchanged by staticise.
        % - For singleton blocks (trivial / self-recursive), ast.isolate is invoked on the static residual
        %   to derive a closed form. For simultaneous blocks of size 2..4, ast.linearise_system attempts
        %   to extract a coefficient matrix; if the system is jointly linear and the matrix is non-singular,
        %   ast.solve_linear_system returns the closed forms via Cramer's rule.

            o.refresh_tables();

            n = size(o.equations, 1);
            blocks = struct('vars', {}, 'eqs', {}, 'kind', {}, 'deps', {}, 'extdeps', {}, 'closed_form', {});
            if n == 0
                return
            end

            % Default pairing: equation i is pinned to its LHS endogenous (the name
            % stored in o.equations(:, EQ_COL_NAME)). Calibration role swaps re-pair
            % the anchor equation of each calibrated endogenous to its swapped parameter.
            var_names = o.equations(:, modBuilder.EQ_COL_NAME);
            calibrated_endos = {};
            if ~isempty(o.calibration_swaps)
                calibrated_endos = o.calibration_swaps(:, 1)';
                for s = 1:size(o.calibration_swaps, 1)
                    endo = o.calibration_swaps{s, 1};
                    param = o.calibration_swaps{s, 3};
                    eq_idx = find(strcmp(endo, var_names));
                    if isempty(eq_idx)
                        error('modBuilder:steady_plan', ...
                              'Calibrated endogenous "%s" is not paired with any equation.', endo);
                    end
                    if ~ismember(param, o.T.equations.(endo))
                        error('modBuilder:steady_plan', ...
                              ['Parameter "%s" does not appear in the equation paired with "%s"; ' ...
                               'a non-local role swap would require re-running matchequations on the ' ...
                               'swapped unknown set, which is not currently supported.'], param, endo);
                    end
                    var_names{eq_idx} = param;
                end
            end
            var_idx = dictionary(string(var_names(:)), (1:n)');

            % Collect the symbol names referenced by each equation (via AST) and partition into
            % endogenous deps vs external constants (parameters / exogenous / calibrated endos).
            % LHS-as-bare-paired-variable (the standard "y = expr" form) does not count as a
            % self-reference: the LHS occurrence is the equation's pairing target, not a use.
            endo_deps = cell(n, 1);
            ext_deps = cell(n, 1);
            for i = 1:n
                eqname_i = var_names{i};
                eq_str = o.equations{i, modBuilder.EQ_COL_EXPR};
                LHSRHS = strsplit(eq_str, '=');
                names = {};
                if isscalar(LHSRHS)
                    names = ast(strtrim(LHSRHS{1})).symbol_names();
                elseif length(LHSRHS) == 2
                    lhs_tree = ast(strtrim(LHSRHS{1}));
                    rhs_tree = ast(strtrim(LHSRHS{2}));
                    if strcmp(lhs_tree.type, 'sym') && strcmp(lhs_tree.value, eqname_i)
                        % "y = expr" form: skip the bare LHS use of y.
                        names = rhs_tree.symbol_names();
                    else
                        names = unique([lhs_tree.symbol_names(), rhs_tree.symbol_names()], 'stable');
                    end
                end
                names = unique(names, 'stable');
                en = {}; ex = {};
                for k = 1:numel(names)
                    s = names{k};
                    if isKey(var_idx, s)
                        en{end+1} = s; %#ok<AGROW>
                    elseif o.isparameter(s) || o.isexogenous(s) || ismember(s, calibrated_endos)
                        ex{end+1} = s; %#ok<AGROW>
                    end
                end
                endo_deps{i} = en;
                ext_deps{i} = ex;
            end

            % Build the directed dependency graph: edge j -> i if x_j ∈ endo_deps(i) and j ≠ i.
            src = []; tgt = [];
            for i = 1:n
                for k = 1:numel(endo_deps{i})
                    j_name = endo_deps{i}{k};
                    j = var_idx(j_name);
                    if j ~= i
                        src(end+1) = j; %#ok<AGROW>
                        tgt(end+1) = i; %#ok<AGROW>
                    end
                end
            end
            G = digraph(src, tgt, [], n);

            % Strongly connected components and their topological ordering.
            bins = conncomp(G, 'Type', 'strong');
            n_scc = max(bins);

            csrc = []; ctgt = [];
            for e = 1:numedges(G)
                [s, t] = findedge(G, e);
                if bins(s) ~= bins(t)
                    csrc(end+1) = bins(s); %#ok<AGROW>
                    ctgt(end+1) = bins(t); %#ok<AGROW>
                end
            end
            if isempty(csrc)
                ord = 1:n_scc;
            else
                Gc = simplify(digraph(csrc, ctgt, [], n_scc));
                ord = toposort(Gc);
            end

            % Group equation indices by SCC, in topological order.
            for k = 1:numel(ord)
                members = find(bins == ord(k));
                vs = var_names(members)';
                if isrow(vs)
                    vars_block = vs;
                else
                    vars_block = vs';
                end

                if numel(members) > 1
                    kind = 'simultaneous';
                else
                    i = members(1);
                    if ismember(var_names{i}, endo_deps{i})
                        kind = 'self-recursive';
                    else
                        kind = 'trivial';
                    end
                end

                already_solved = {};
                consts = {};
                for ii = members(:)'
                    for s_cell = endo_deps{ii}
                        s = s_cell{1};
                        if ~ismember(s, vars_block) && ~ismember(s, already_solved)
                            already_solved{end+1} = s; %#ok<AGROW>
                        end
                    end
                    for s_cell = ext_deps{ii}
                        s = s_cell{1};
                        if ~ismember(s, consts)
                            consts{end+1} = s; %#ok<AGROW>
                        end
                    end
                end

                % Closed-form isolation: singleton blocks → ast.isolate (linear / monomial /
                % invertible-call); small simultaneous blocks (size 2..8) → Bareiss
                % triangulation + back-substitution, with each x_i referencing the
                % already-solved x_j (j > i) by name so the generated assignments stay
                % compact in the steady_state_model block.
                cf = struct('var', {}, 'expr', {});
                if numel(members) == 1
                    f = modBuilder.static_residual(o, members(1));
                    if ~isempty(f)
                        rhs_tree = f.isolate(vars_block{1});
                        if ~isempty(rhs_tree)
                            cf(1).var = vars_block{1};
                            cf(1).expr = rhs_tree.string();
                        end
                    end
                elseif numel(members) >= 2 && numel(members) <= 8
                    % The size cap is set by the readability of the generated assignments,
                    % not by an algorithmic limit: Bareiss runs in O(n^3) work and produces
                    % polynomial intermediate entries.
                    residuals = cell(1, numel(members));
                    for jj = 1:numel(members)
                        residuals{jj} = modBuilder.static_residual(o, members(jj));
                    end
                    if all(~cellfun(@isempty, residuals))
                        % First attempt: jointly linear → Bareiss + back-substitution.
                        [ok_lin, A_mat, b_vec] = ast.linearise_system(residuals, vars_block);
                        if ok_lin
                            n_var = numel(vars_block);
                            M = [A_mat, cell(n_var, 1)];
                            for jj = 1:n_var
                                M{jj, n_var + 1} = ast.negate(b_vec{jj});
                            end
                            [U, ~, singular] = ast.bareiss_triangulate(M);
                            if ~singular
                                var_refs = cell(1, n_var);
                                rhs_in_order = cell(1, n_var);
                                for jj = n_var:-1:1
                                    rhs_jj = U{jj, n_var + 1};
                                    for kk = jj+1:n_var
                                        term = ast('binop', '*', {U{jj, kk}, var_refs{kk}});
                                        rhs_jj = ast('binop', '-', {rhs_jj, term});
                                    end
                                    rhs_jj = ast('binop', '/', {rhs_jj, U{jj, jj}}).simplify();
                                    rhs_in_order{jj} = rhs_jj;
                                    var_refs{jj} = ast('sym', vars_block{jj}, {});
                                end
                                for jj = n_var:-1:1
                                    cf(end+1).var = vars_block{jj}; %#ok<AGROW>
                                    cf(end).expr = rhs_in_order{jj}.string();
                                end
                            end
                        end
                        % Fallback: iterated symbolic elimination via the per-equation
                        % recognisers. Substitution between equations may turn a
                        % non-linear residual into a linear / monomial / call-wrapped
                        % one that the recognisers then handle.
                        if isempty(cf)
                            param_names = {};
                            if ~isempty(o.params)
                                param_names = o.params(:, modBuilder.COL_NAME)';
                            end
                            elim_cf = ast.iterated_elimination(residuals, vars_block, param_names);
                            for jj = 1:numel(elim_cf)
                                cf(end+1).var = elim_cf(jj).var; %#ok<AGROW>
                                cf(end).expr = elim_cf(jj).expr.string();
                            end
                        end
                    end
                end

                blocks(end+1).vars = vars_block; %#ok<AGROW>
                blocks(end).eqs = vars_block;
                blocks(end).kind = kind;
                blocks(end).deps = already_solved;
                blocks(end).extdeps = consts;
                blocks(end).closed_form = cf;
            end
        end % function

        function suggestions = suggest_calibrations(o, blocks)
        % Scan candidate calibration role swaps that would close a residual sub-block.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - blocks   [struct array]   optional; if omitted, computed by o.steady_plan().
        %
        % OUTPUTS:
        % - suggestions  [struct array]  one entry per candidate that strictly shrinks
        %                                the total residual, with fields:
        %                                  .endo       [char]   endogenous to pin
        %                                  .param      [char]   parameter to elevate
        %                                  .residual   [int]    total #variables left
        %                                                       open across the plan
        %                                                       after virtually applying
        %                                                       this swap (0 = full
        %                                                       closure)
        %                                Sorted by ascending .residual (full closures
        %                                first).
        %
        % REMARKS:
        % - For each residual variable, scan parameters that appear in its anchor
        %   equation. Each (endo, param) pair is virtually applied (m.copy +
        %   m.calibrate, then steady_plan re-runs) and the new total residual is
        %   recorded.
        % - Cost: one steady_plan re-run per candidate. Bounded by
        %   #residual_vars × max_params_per_residual_eq, which is small in practice
        %   for DSGE blocks.
        % - Without economic intuition, some suggestions may be algebraically sound but
        %   meaningless (calibrating output to identify the discount factor). The user
        %   reads the menu critically; the framework only exposes the algebraic options.
            arguments
                o
                blocks = []
            end
            if isempty(blocks)
                blocks = o.steady_plan();
            end
            suggestions = struct('endo', {}, 'param', {}, 'residual', {});
            if ~isempty(o.calibration_swaps)
                % If swaps are already declared, the plan reflects the user's intent —
                % don't propose more on top.
                return
            end
            old_total = modBuilder.total_residual_count(blocks);
            if old_total == 0
                return
            end

            seen = dictionary(string.empty, logical.empty);
            for k = 1:numel(blocks)
                b = blocks(k);
                if ~strcmp(b.kind, 'simultaneous'), continue, end
                resolved = {b.closed_form.var};
                residual = setdiff(b.vars, resolved);
                if isempty(residual), continue, end

                for r = 1:numel(residual)
                    endo = residual{r};
                    if ~isfield(o.T.equations, endo), continue, end
                    eq_symbols = o.T.equations.(endo);
                    for p_idx = 1:numel(eq_symbols)
                        p = eq_symbols{p_idx};
                        if ~o.isparameter(p), continue, end
                        key = sprintf('%s|%s', endo, p);
                        if isKey(seen, key), continue, end
                        seen(key) = true;

                        m_copy = o.copy();
                        target = o.get_value(endo);
                        if isnan(target), target = 0; end
                        try
                            m_copy.calibrate(endo, target, p);
                            new_blocks = m_copy.steady_plan();
                        catch
                            continue
                        end
                        new_total = modBuilder.total_residual_count(new_blocks);
                        if new_total < old_total
                            suggestions(end+1).endo = endo; %#ok<AGROW>
                            suggestions(end).param = p;
                            suggestions(end).residual = new_total;
                        end
                    end
                end
            end

            if ~isempty(suggestions)
                [~, order] = sort([suggestions.residual]);
                suggestions = suggestions(order);
            end
        end % function

        function print_steady_plan(o, blocks)
        % Render the structural steady-state plan as a human-readable summary.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - blocks   [struct array]   optional; if omitted, computed by o.steady_plan().
        %
        % REMARKS:
        % - Each block is shown with its kind, its variable(s), the already-solved endogenous
        %   variables it depends on, and its external constants (parameters / exogenous).
        % - When ast.isolate produced a closed form for a singleton block, it is rendered as
        %   "x = expr". Otherwise, simultaneous blocks are flagged "needs solver".
            arguments
                o
                blocks = []
            end
            if isempty(blocks)
                blocks = o.steady_plan();
            end

            modBuilder.dprintf('Steady-state plan: %d block(s)', numel(blocks));
            modBuilder.skipline();

            for k = 1:numel(blocks)
                b = blocks(k);
                if strcmp(b.kind, 'simultaneous')
                    label = sprintf('[simultaneous, %d vars]', numel(b.vars));
                else
                    label = sprintf('[%s]', b.kind);
                end
                modBuilder.dprintf('  Block %d %s', k, label);
                modBuilder.dprintf('    vars: %s', strjoin(b.vars, ', '));
                if ~isempty(b.deps)
                    modBuilder.dprintf('    depends on (already solved): %s', strjoin(b.deps, ', '));
                end
                if ~isempty(b.extdeps)
                    modBuilder.dprintf('    external constants: %s', strjoin(b.extdeps, ', '));
                end
                if ~isempty(b.closed_form)
                    for jj = 1:numel(b.closed_form)
                        modBuilder.dprintf('    closed form: %s = %s', b.closed_form(jj).var, b.closed_form(jj).expr);
                    end
                    % Flag any residual sub-block that the recognisers did not close.
                    resolved_vars = {b.closed_form.var};
                    residual_vars = setdiff(b.vars, resolved_vars);
                    if ~isempty(residual_vars)
                        modBuilder.dprintf('    residual (still open): %s', strjoin(residual_vars, ', '));
                        modBuilder.dprintf('    -- numerical solver required for the residual --');
                    end
                elseif strcmp(b.kind, 'simultaneous')
                    modBuilder.dprintf('    -- numerical solver required --');
                end
                modBuilder.skipline();
            end

            % If the plan has any residual and the user has not yet declared a
            % calibration swap, scan candidate (endo, param) pairs and surface them
            % as a ranked menu. Full-closure candidates appear first.
            if isempty(o.calibration_swaps) && modBuilder.total_residual_count(blocks) > 0
                suggestions = o.suggest_calibrations(blocks);
                if ~isempty(suggestions)
                    modBuilder.dprintf('Suggested calibration swaps:');
                    for s = 1:numel(suggestions)
                        if suggestions(s).residual == 0
                            tag = 'closes fully';
                        else
                            tag = sprintf('shrinks residual to %d', suggestions(s).residual);
                        end
                        modBuilder.dprintf('  m.calibrate(''%s'', <target>, ''%s'')   [%s]', ...
                            suggestions(s).endo, suggestions(s).param, tag);
                    end
                    modBuilder.skipline();
                end
            end
        end % function

        function o = apply_steady_plan(o, blocks)
        % Write the closed-form assignments produced by steady_plan into o.steady_state.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - blocks   [struct array]   optional; if omitted, computed by o.steady_plan().
        %
        % OUTPUTS:
        % - o        [modBuilder]     updated object with steady_state populated for each block
        %                             that has a closed form.
        %
        % REMARKS:
        % - Iterates over the plan in topological order and calls m.steady(var, expr) for
        %   every block whose closed_form is non-empty (singleton blocks where ast.isolate
        %   could derive a closed form).
        % - Simultaneous blocks are skipped; the user must provide steady-state values
        %   manually (m.steady) or call m.solve_system.
        % - m.steady replaces an existing entry in place, so calling apply_steady_plan twice
        %   is idempotent for the closed-form blocks.
            arguments
                o
                blocks = []
            end
            if isempty(blocks)
                blocks = o.steady_plan();
            end
            % Calibration role swaps: pin each calibrated endogenous to its target value
            % before writing the block closed forms. The closed forms for elevated
            % parameters reference the calibrated names symbolically; the toposort in
            % checksteady places the calibration anchors before the dependent expressions.
            if ~isempty(o.calibration_swaps)
                for s = 1:size(o.calibration_swaps, 1)
                    o.steady(o.calibration_swaps{s, 1}, num2str(o.calibration_swaps{s, 2}, 15));
                end
            end
            for k = 1:numel(blocks)
                cf = blocks(k).closed_form;
                for jj = 1:numel(cf)
                    o.steady(cf(jj).var, cf(jj).expr);
                end
            end
        end % function

        function o = solve(o, eqname, sname, sinit, tol, maxit)
        % Numerically solve an equation for a symbol (parameter, endogenous, or exogenous)
        %
        % INPUTS:
        % - o            [modBuilder]
        % - eqname       [char]         equation name to solve
        % - sname        [char]         symbol to solve for
        % - sinit        [double]       initial guess for the solution
        % - tol          [double]       convergence tolerance (default 1e-10)
        % - maxit        [integer]      maximum Newton iterations (default 100)
        %
        % OUTPUTS:
        % - o            [modBuilder]   updated object with calibrated symbol value
        %
        % REMARKS:
        % - Converts equation to static form (removes time subscripts)
        % - Uses Newton's method via solvers.newton
        % - All other symbols must have known values
        % - Updates the calibration value of sname in o.params, o.varexo, or o.var
        % - The default tol is 1e-10, tighter than the test threshold typical
        %   downstream uses (1e-8). It can be loosened explicitly if needed.
            arguments
                o
                eqname (1,:) char {mustBeNonempty}
                sname  (1,:) char {mustBeNonempty}
                sinit  (1,1) double {mustBeFinite, mustBeReal}
                tol    (1,1) double {mustBePositive}                = 1e-10
                maxit  (1,1) double {mustBePositive, mustBeInteger} = 100
            end

            % Auto-update symbol tables if needed
            o.refresh_tables();

            if not(ismember(sname, o.T.equations.(eqname)))

                if o.isendogenous(sname)

                    if not(ismember(eqname, o.T.var.(sname)))
                        error('modBuilder:solve:unknownSymbol', 'Symbol "%s" does not appear in equation "%s".', sname, eqname)
                    end
                else
                    error('modBuilder:solve:unknownSymbol', 'Symbol "%s" does not appear in equation "%s".', sname, eqname)
                end
            end

            %
            % Get static version of the equation
            %
            eqID = strcmp(eqname, o.equations(:,modBuilder.EQ_COL_NAME));
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
                equation = regexprep(equation, ['\<', symbol, '\>'], num2str(o.get_value(symbol), 15));
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
                error('modBuilder:solve:multipleEquals', 'An equation cannot have more than one equal (=) symbol.')
            end

            f = str2func(equation);

            %
            % Set initial guess for the unknown symbol (tol and maxit have
            % their defaults handled by the arguments block above).
            %
            [x, ~, ~] = solvers.newton(f, sinit, tol, maxit);
            o.set_value(sname, x);
        end % function

        function o = solve_system(o, eqnames, snames, options)
        % Solve a system of equations for multiple symbols using Newton's method.
        %
        % INPUTS:
        % - o              [modBuilder]
        % - eqnames        [cell]         1×m cell array of equation names
        % - snames         [cell]         1×n cell array of symbol names to solve for
        % - options.tol    [double]       convergence tolerance (default 1e-6)
        % - options.maxit  [double]       maximum iterations (default 100)
        %
        % OUTPUTS:
        % - o              [modBuilder]   updated object with solved symbol values
        %
        % REMARKS:
        % - The system must be square (m equations, m unknowns).
        % - Symbols to solve for can be any mix of parameters, exogenous,
        %   and endogenous variables.
        % - Current symbol values are used as the initial guess.
        % - The Jacobian is computed via automatic differentiation using
        %   the sparsity pattern from the symbol table.
        %
        % EXAMPLES:
        % % Solve for the RBC steady state
        % m = modBuilder();
        % m.add('k', '1/beta = alpha*y/k + (1-delta)');
        % m.add('y', 'y = k^alpha');
        % m.add('c', 'c = y - delta*k');
        % m.parameter('alpha', 0.36);
        % m.parameter('beta', 0.99);
        % m.parameter('delta', 0.025);
        % m.endogenous('k', 5);
        % m.endogenous('y', 1.5);
        % m.endogenous('c', 1);
        % m.solve_system({'k', 'y', 'c'}, {'k', 'y', 'c'});
        %
        % % Solve for a parameter and an endogenous variable
        % m.solve_system({'y', 'c'}, {'alpha', 'c'});

            arguments
                o modBuilder
                eqnames cell
                snames cell
                options.tol (1,1) double = 1e-6
                options.maxit (1,1) double = 100
            end

            m = length(eqnames);
            n = length(snames);

            if m ~= n
                error('modBuilder:solve_system:nonSquare', 'System must be square: number of equations (%d) must equal number of variables (%d).', m, n)
            end

            for j = 1:n
                if ~o.issymbol(snames{j})
                    error('modBuilder:solve_system:unknownSymbol', 'Unknown symbol "%s".', snames{j})
                end
                if isnan(o.get_value(snames{j}))
                    error('modBuilder:solve_system:missingValue', 'Symbol "%s" has no initial value. Set a value before calling solve_system.', snames{j})
                end
            end

            [fhandles, incidence] = o.compile_equations(eqnames, snames);

            % Build initial guess from current values
            x0 = zeros(n, 1);
            for j = 1:n
                x0(j) = o.get_value(snames{j});
            end

            % Build closures for the solver
            residual_fn = @(x) eval_residuals(fhandles, x, m);
            jacobian_fn = @(x) eval_jacobian(fhandles, incidence, x, n);

            [xsol, ~, ~] = solvers.newton_system(residual_fn, jacobian_fn, x0, options.tol, options.maxit);

            % Write solution back
            for j = 1:n
                o.set_value(snames{j}, xsol(j));
            end
        end % function

        function varargout = subsref(o, S)
        % Overload subsref: o{'eq'} extracts equation, o.x returns parameter/variable value
        %
        % INPUTS:
        % - o    [modBuilder]
        % - S    [struct]         subscript structure from MATLAB
        %
        % OUTPUTS:
        % - varargout  [varies]   extracted submodel, property value, parameter/variable value, or method result
        %
        % REMARKS:
        % - o{'eq1'} or o{'eq1', 'eq2', ...} extracts equations by name using curly braces
        % - o.x returns the value of parameter or variable x (or calls method x)
        % - o('eq1', 'eq2', ...) also extracts equations for backward compatibility

            % Auto-update symbol tables if accessing T property
            if isequal(S(1).type, '.') && isequal(S(1).subs, 'T') && o.tables_dirty
                o.updatesymboltables();
            end

            nout = nargout;
            method_call = false;

            if isequal(S(1).type, '{}')
                if isa(S(1).subs{1}, 'bytag')
                    % o{bytag('tagname', 'tagvalue')} - select equations by tag
                    args = S(1).subs{1}.toargs();
                    p = o.select(args{:});
                else
                    % o{'eq1', 'eq2', ...} - extract equations using curly braces
                    p = o.extract(S(1).subs{:});
                end
                S = modBuilder.shiftS(S, 1);
            elseif isequal(S(1).type, '()')
                % o('eq1', 'eq2', ...) - extract equations using parentheses (backward compatibility)
                p = o.extract(S(1).subs{:});
                S = modBuilder.shiftS(S, 1);
            elseif isequal(S(1).type, '.')
                % o.x - access property, get parameter/variable value, or call method.
                % Route via explicit metaclass / symbol checks rather than try/catch on
                % get_value: a try/catch swallows the get_value error and ALSO any
                % unrelated error inside the catch's feval probe, conflating "no such
                % name" with "method exists and threw".
                name = S(1).subs;
                mc = metaclass(o);
                if ismember(name, {mc.PropertyList.Name})
                    p = o.(name);
                    S = modBuilder.shiftS(S, 1);
                elseif o.issymbol(name)
                    p = o.get_value(name);
                    S = modBuilder.shiftS(S, 1);
                elseif ismember(name, {mc.MethodList.Name})
                    method_call = true;
                    if isscalar(S)
                        [varargout{1:nout}] = feval(name, o);
                        S = modBuilder.shiftS(S, 1);
                    elseif isequal(S(2).type, '()')
                        [varargout{1:nout}] = feval(name, o, S(2).subs{:});
                        S = modBuilder.shiftS(S, 2);
                    else
                        error('modBuilder:subsref:unknownSymbol', 'Reference to non-existent field or method ''%s''.', name);
                    end
                else
                    error('modBuilder:subsref:unknownSymbol', 'Reference to non-existent field or method ''%s''.', name);
                end
            end

            if method_call
                if ~isempty(S)
                    % Chain remaining indexing on first output only
                    varargout{1} = builtin('subsref', varargout{1}, S);
                end
                return
            end

            if ~isempty(S)
                % Handle remaining indexing operations
                % If result is a modBuilder, call subsref recursively
                % Otherwise, use builtin subsref for cell arrays, structs, etc.
                if isa(p, 'modBuilder')
                    p = subsref(p, S);
                elseif isa(p, 'cell') && strcmp(S(1).type, '{}')
                    % Extract subcell preserving shape
                    subcell = p(S(1).subs{:});
                    if isscalar(subcell)
                        % Single element: return content directly (original {} behaviour)
                        p = subcell{1};
                    elseif all(cellfun(@(x) isnumeric(x) && isscalar(x), subcell(:)))
                        % Multiple numeric scalars: convert to numeric array
                        p = cell2mat(subcell);
                    else
                        % Keep as cell array (strings, mixed content, etc.)
                        p = subcell;
                    end
                    S = modBuilder.shiftS(S, 1);
                    if ~isempty(S)
                        p = builtin('subsref', p, S);
                    end
                else
                    p = builtin('subsref', p, S);
                end
            end

            varargout{1} = p;
        end % function

        function n = numArgumentsFromSubscript(o, s, indexingContext)
        % Determine number of output arguments expected from subscripted reference
        %
        % INPUTS:
        % - o               [modBuilder]
        % - s               [struct]            subscript structure from MATLAB
        % - indexingContext  [IndexingContext]   Statement or Expression context
        %
        % OUTPUTS:
        % - n                [integer]           number of expected outputs
        %
        % REMARKS:
        % For method calls with multiple outputs (e.g. [J,r] = o.jacobian(...)),
        % we need to return the actual nargout of the method. For other indexing
        % operations, we return 1.

            if indexingContext == matlab.mixin.util.IndexingContext.Statement ...
                    && isequal(s(1).type, '.') ...
                    && ~ismember(s(1).subs, {metaclass(o).PropertyList.Name})
                % Dot reference that is not a property — could be a method or symbol.
                % Check if it is a method with multiple outputs.
                mc = metaclass(o);
                mlist = mc.MethodList;
                idx = strcmp(s(1).subs, {mlist.Name});
                if any(idx)
                    mdef = mlist(idx);
                    nouts = numel(mdef.OutputNames);
                    if nouts > 1
                        n = nouts;
                        return
                    end
                end
            end
            n = 1;
        end % function

        function o = subsasgn(o,S,B)
        % Overload subsasgn: o.symbol = value (set values) or o('var') = 'eq' (change equations)
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
        % - o.param = 0.5 sets parameter value
        % - o.exovar = 1.0 sets exogenous variable value
        % - o.endovar = 2.0 sets endogenous variable steady state value
        % - o('endovar') = 'new_equation' changes equation (only for endogenous variables)

            if length(S)>1
                error('modBuilder:subsasgn:badAssignment', 'Wrong assignment.')
            end

            if isequal(S(1).type, '.')
                % Dot notation: o.symbol = value
                % Only numeric assignments allowed with dot notation
                if ~(isnumeric(B) && isscalar(B) && isreal(B))
                    error('modBuilder:subsasgn:badType', 'Can only assign a real scalar number using dot notation. Use o(''var'') = ''equation'' to change equations.')
                end

                try
                    o.set_value(S(1).subs, B);
                catch
                    error('modBuilder:subsasgn:unknownSymbol', 'Unknown symbol ''%s''. Cannot assign to non-existent symbol.', S(1).subs);
                end

            elseif isequal(S(1).type, '()')
                % Parentheses notation: o('endovar') = 'equation'
                % Only for changing equations (endogenous variables only)
                if ~ischar(S(1).subs{1})
                    error('modBuilder:subsasgn:badIndex', 'Wrong assignment (index must be a character array, a variable name).')
                end

                try
                    [type, ~] = typeof(o, S(1).subs{1});
                catch
                    error('modBuilder:subsasgn:unknownSymbol', 'Wrong index (unknown symbol).')
                end

                if ~strcmp(type, 'endogenous')
                    error('modBuilder:subsasgn:notEndogenous', 'Can only change equations for endogenous variables. Use o.%s = value to set parameter/exogenous values.', S(1).subs{1});
                end

                if ~ischar(B)
                    error('modBuilder:subsasgn:badType', 'Can only assign equation strings with parentheses. Use o.%s = value to set steady state values.', S(1).subs{1});
                end

                % Change equation
                o.change(S(1).subs{1}, B);

            else
                error('modBuilder:subsasgn:badIndex', 'Wrong assignment (cannot index with {}).')
            end
        end % function

    end % methods

end % classdef

function r = eval_residuals(fhandles, x, m)
    v = num2cell(x(:));
    r = zeros(m, 1);
    for i = 1:m
        r(i) = fhandles{i}(v);
    end
end

function J = eval_jacobian(fhandles, incidence, x, n)
    m = size(incidence, 1);
    x = x(:);
    nnzJ = nnz(incidence);
    II = zeros(nnzJ, 1);
    JJ = zeros(nnzJ, 1);
    VV = zeros(nnzJ, 1);
    idx = 0;
    for j = 1:n
        affected = find(incidence(:, j));
        if isempty(affected), continue; end
        v_ad = cell(n, 1);
        for k = 1:n
            if k == j
                v_ad{k} = autoDiff1(x(k), 1.0);
            else
                v_ad{k} = autoDiff1(x(k), 0.0);
            end
        end
        for i = affected'
            r = fhandles{i}(v_ad);
            idx = idx + 1;
            II(idx) = i;
            JJ(idx) = j;
            VV(idx) = r.dx;
        end
    end
    J = sparse(II, JJ, VV, m, n);
end
