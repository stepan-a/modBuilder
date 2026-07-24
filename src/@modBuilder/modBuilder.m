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

        % Valid *collection names* for the dimension/display API (size(), table(),
        % printlist2()), validated by validate_type(). This is the plural vocabulary
        % and is DISTINCT from the singular symbol-type vocabulary
        % ('parameter'/'exogenous'/'endogenous') returned by typeof()/lookup_symbol()
        % and used by the classification internals — the two share 'exogenous' and
        % 'endogenous' but are not interchangeable (note 'parameters' vs 'parameter',
        % and 'equations' which is a collection only). table()/printlist2() accept a
        % subset and validate it locally rather than via VALID_TYPES.
        VALID_TYPES = {'parameters', 'exogenous', 'endogenous', 'equations'}

        % Cost constants for the matchequations bipartite matcher.
        % Invariant: MATCH_FORBID > MATCH_UNMATCHED > any real edge cost (~1.x).
        % MATCH_FORBID  fills non-edges; matchpairs will never select one.
        % MATCH_UNMATCHED is the cost of leaving a row unmatched; sitting between
        % the real edge costs and MATCH_FORBID, it forces matchpairs to maximise
        % the matching size while still preferring real edges.
        MATCH_FORBID    = 1e6
        MATCH_UNMATCHED = 1e3

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

    properties (Constant)
        % On-disk schema version stamped into the struct returned by saveobj
        % and checked by loadobj. Bump this whenever the persisted field set
        % changes, and add the corresponding migration branch to
        % migrate_saved_struct(). Files written before versioning carry no
        % 'version' field and are treated as version 0. Public so external
        % tooling can check the format a given modBuilder understands.
        %   1  current: params, varexo, var, tags, symbols, equations,
        %      steady_state, T, date, calibration_swaps
        SCHEMA_VERSION = 1
    end

    properties (Access = private)
        % Symbol lookup map for O(1) type checking: symbol_name -> struct(type, idx)
        % Updated automatically by update_symbol_map() after structural changes
        % Provides significant performance improvement over linear search
        symbol_map = []

        % Dirty flag for symbol_map (name -> type/idx). Independent of tables_dirty
        % so that a structural change (which makes both stale) can trigger a quick
        % map-only rebuild on the next read without paying the expensive
        % updatesymboltables() rebuild until something actually needs T.
        symbol_map_dirty = false

        % Flag indicating if symbol tables (T) need updating
        % true = tables are stale and need updating
        % false = tables are up-to-date
        % Automatically managed by modification and read methods
        tables_dirty = false

        % Lazy cache of STATIC (steady-state) Jacobian partials, keyed by equation name.
        %   static_jacobian_cache(eqname) = struct( ...
        %     eqstr,    [char]       equation expression the partials were derived from — the
        %                            validity guard; a mismatch with o.equations means stale;
        %     fallback, [logical]    true if the equation has no analytical Jacobian (an operator
        %                            with no differentiation rule) and must use AD;
        %     partials, [dictionary] symbol_name -> struct(ast): the simplified static partial
        %                            ∂(staticised residual)/∂symbol (lags aggregated into the
        %                            bare-name partial). )
        % Populated on demand by the Method='analytical'/'auto' path and evaluated against
        % current symbol values, so it survives parameter-value changes (the eqstr guard
        % catches equation-text changes). Pure derived state: not serialized (see saveobj),
        % rebuilt lazily — same lifecycle as symbol_map.
        static_jacobian_cache = configureDictionary("string", "struct")
    end


    methods (Access = private)

        function mark_dirty(o)
        % Flag both the symbol tables (o.T) and the symbol map as needing a rebuild.
        %
        % REMARKS:
        % - Most mutators invalidate both at once; calling this keeps the pair in sync so a new modification path cannot set one and forget the other.
        % - Deletion loops that must force linear lookups mid-mutation set o.symbol_map_dirty on its own and do not use this helper.
            o.tables_dirty = true;
            o.symbol_map_dirty = true;
        end % function

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

            % Build a fresh, type-configured dictionary. configureDictionary fixes the
            % key/value types up-front so isKey(...) is callable even when the model has
            % no declared symbols yet — an unconfigured dictionary() errors on isKey
            % until the first insertion sets the types.
            o.symbol_map = configureDictionary("string", "struct");

            % Map every declared symbol (parameter, exogenous, endogenous) to its type and row index.
            kinds = modBuilder.symbol_kinds();
            for k=1:numel(kinds)
                tbl = o.(kinds(k).prop);
                type = kinds(k).type;
                for i=1:size(tbl, 1)
                    o.symbol_map(tbl{i, modBuilder.COL_NAME}) = struct('type', type, 'idx', i);
                end
            end

            o.symbol_map_dirty = false;
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
        % - Shared backend for typeof, isparameter, isexogenous, isendogenous
        %   and issymbol so the lookup logic lives in one place.
        % - The map is rebuilt on demand when symbol_map_dirty is set or the
        %   map is missing. The rebuild is O(n) in the small dimension
        %   (declared symbols), so the cost is amortised across the lookups
        %   that follow — N reads after a mutator pay one rebuild, not N.
            if o.symbol_map_dirty || isempty(o.symbol_map) || ~isa(o.symbol_map, 'dictionary')
                o.update_symbol_map();
            end
            if o.symbol_map.isKey(name)
                sym_info = o.symbol_map(name);
                found = true;
                type  = sym_info.type;
                id    = sym_info.idx;
            else
                found = false;
                type  = '';
                id    = [];
            end
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

            % Validate that long_name and texname use the same placeholders as symbol_name
            if ~isempty(long_name)
                inames_long = modBuilder.placeholders(long_name);
                if ~isempty(setxor(inames_long, inames))
                    error('modBuilder:handle_implicit_loops:indexMismatch', 'long_name has placeholders {%s} but the %s name has {%s}.', ...
                          strjoin(inames_long, ', '), symbol_type, strjoin(inames, ', '));
                end
            end
            if ~isempty(texname)
                inames_tex = modBuilder.placeholders(texname);
                if ~isempty(setxor(inames_tex, inames))
                    error('modBuilder:handle_implicit_loops:indexMismatch', 'texname has placeholders {%s} but the %s name has {%s}.', ...
                          strjoin(inames_tex, ', '), symbol_type, strjoin(inames, ', '));
                end
            end

            % Expand the name (and optional long_name/texname) over the Cartesian
            % product of the index values.
            templates = {symbol_name};
            if ~isempty(long_name)
                templates{end+1} = long_name;
            end
            if ~isempty(texname)
                templates{end+1} = texname;
            end
            expanded = modBuilder.expand_templates(templates, index_args);

            % Create symbols for all combinations
            for i=1:size(expanded, 1)
                % Build arguments for recursive call
                call_args = {expanded{i,1}, value};
                col = 1;

                % Add expanded long_name if provided
                if ~isempty(long_name)
                    col = col + 1;
                    call_args = [call_args, {'long_name', expanded{i,col}}];
                end

                % Add expanded texname if provided
                if ~isempty(texname)
                    col = col + 1;
                    call_args = [call_args, {'texname', expanded{i,col}}];
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
                o.mark_dirty();
            end

            o.symbols = setdiff(o.symbols, name);
        end % function

        function o = declare_typed(o, kind, name, varargin)
        % Shared body for parameter() and exogenous(): implicit-loop dispatch,
        % positional-value parsing, then forward to declare_symbol.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - kind      [char]    'parameter' or 'exogenous'
        % - name      [char]    symbol name (may contain $N placeholders)
        % - varargin  [cell]    optional value, then optional key/value pairs;
        %                       when name carries placeholders, varargin also
        %                       ends with the index-value arrays consumed by
        %                       handle_implicit_loops.
        %
        % OUTPUTS:
        % - o         [modBuilder]
        %
        % REMARKS:
        % - endogenous() stays separate: its "preserve existing value on missing
        %   arg" semantics differs from the parameter/exogenous "NaN default"
        %   path implemented here.
            arguments
                o
                kind (1,:) char {mustBeMember(kind, {'parameter', 'exogenous'})}
                name (1,:) char {mustBeNonempty}
            end
            arguments (Repeating)
                varargin
            end

            if ~isempty(modBuilder.placeholders(name))
                o.handle_implicit_loops(name, kind, varargin{:});
                return
            end

            if isempty(varargin)
                value = NaN;  opts = {};
            elseif isempty(varargin{1})
                value = NaN;  opts = varargin(2:end);
            else
                value = varargin{1};  opts = varargin(2:end);
            end

            o = o.declare_symbol(kind, name, value, opts{:});
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
                q_params(i,:) = modBuilder.symbol_row(o_only_params_list{j}, o.params, o_param_idx(j));
                i = i+1;
            end
            % Handle common parameters (p takes precedence if calibrated)
            for j=1:length(common_params)
                p_idx = p_param_idx_common(j);
                if not(isnan(p.params{p_idx,modBuilder.COL_VALUE}))
                    q_params(i,:) = modBuilder.symbol_row(common_params{j}, p.params, p_idx);
                else
                    q_params(i,:) = modBuilder.symbol_row(common_params{j}, o.params, o_param_idx_common(j));
                end
                i = i+1;
            end
            % Copy p-only parameters
            for j=1:length(p_only_params_list)
                q_params(i,:) = modBuilder.symbol_row(p_only_params_list{j}, p.params, p_param_idx(j));
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
                    q_varexo(i,:) = modBuilder.symbol_row(varname, p.varexo, p_varexo_map(varname));
                elseif in_o
                    % o is the only source (o-only variables)
                    q_varexo(i,:) = modBuilder.symbol_row(varname, o.varexo, o_varexo_map(varname));
                end
            end
        end % function

        function q = merge_symbol_tables(o, p, q)
        % Merge the symbol-table state that survives the rebuild
        %
        % INPUTS:
        % - o   [modBuilder]   First model
        % - p   [modBuilder]   Second model
        % - q   [modBuilder]   Target merged model
        %
        % OUTPUTS:
        % - q   [modBuilder]   Updated model with merged T.equations and tags
        %
        % REMARKS:
        % - Only T.equations (the per-equation symbol lists) and the tags need
        %   merging: merge() calls updatesymboltables() right after, which rebuilds
        %   T.params / T.varexo / T.var from scratch out of T.equations and the
        %   declaration tables, so merging those three here would be dead work
        %   (this method used to do it, exogenous-to-endogenous cleanup included,
        %   only for the rebuild to discard the result).
            arguments
                o
                p (1,1) modBuilder
                q (1,1) modBuilder
            end

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

            % Search parameters, exogenous and endogenous variables.
            kinds = modBuilder.symbol_kinds();
            for k = 1:numel(kinds)
                tbl = o.(kinds(k).prop);
                Tf = o.T.(kinds(k).prop);
                label = kinds(k).label;
                for i = 1:size(tbl, 1)
                    name = tbl{i, modBuilder.COL_NAME};
                    if ~isempty(regexp(name, pattern, 'once'))
                        count = count + 1;
                        matches(count).name = name;
                        matches(count).type = label;
                        matches(count).equations = Tf.(name);
                    end
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
                equation = modBuilder.staticise_equation_string(o.equations{eqID, modBuilder.EQ_COL_EXPR});

                % Split on = and form LHS-(RHS)
                LHSRHS = strsplit(equation, '=');
                if length(LHSRHS) == 2
                    expr = sprintf('%s-(%s)', LHSRHS{1}, LHSRHS{2});
                elseif isscalar(LHSRHS)
                    expr = LHSRHS{1};
                else
                    error('modBuilder:compile_equations:multipleEquals', 'An equation cannot have more than one equal (=) symbol.')
                end

                % Get all symbols in this equation (including the equation's own endogenous).
                symbols = unique([o.T.equations.(eqnames{i}), eqnames{i}]);

                % Build the replacement table: solve-vars → v{k} (and record incidence),
                % everything else → numeric value. One regex pass instead of one per symbol.
                replacements = struct();
                for s = 1:length(symbols)
                    symbol = symbols{s};
                    if varmap.isKey(symbol)
                        k = varmap(symbol);
                        replacements.(symbol) = sprintf('v{%d}', k);
                        incidence(i, k) = true;
                    else
                        replacements.(symbol) = num2str(o.get_value(symbol), 15);
                    end
                end
                expr = modBuilder.substitute_symbols(expr, replacements);

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

            % Compute Jacobian column by column using AD (COO → sparse). The
            % zero-seed dual vector is built once; each column only swaps its own
            % seeded entry in and out (O(n) constructions instead of O(n^2)).
            nnzJ = nnz(incidence);
            II = zeros(nnzJ, 1);
            JJ = zeros(nnzJ, 1);
            VV = zeros(nnzJ, 1);
            idx = 0;
            v_ad = cell(n, 1);
            for k = 1:n
                v_ad{k} = autoDiff1(x0(k), 0.0);
            end
            for j = 1:n
                affected = find(incidence(:, j));
                if isempty(affected), continue; end
                v_ad{j} = autoDiff1(x0(j), 1.0);
                for ii = affected'
                    r = fhandles{ii}(v_ad);
                    idx = idx + 1;
                    II(idx) = ii;
                    JJ(idx) = j;
                    VV(idx) = r.dx;
                end
                v_ad{j} = autoDiff1(x0(j), 0.0);
            end
            J = sparse(II, JJ, VV, m, n);
        end % function

        function g = partial(o, eqname, varname, options)
        % Symbolic partial derivative of an equation's residual w.r.t. a symbol.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - eqname   [char]         1×n array, name of an equation (its endogenous variable)
        % - varname  [char]         1×n array, name of the symbol to differentiate w.r.t.
        % - Lag      [integer]      (name-value) period of the target. Omitted (the default) gives
        %                           the STATIC partial; an explicit value gives the dynamic,
        %                           period-specific partial (see REMARKS).
        %
        % OUTPUTS:
        % - g        [ast]          simplified ∂(LHS−RHS)/∂varname
        %
        % REMARKS:
        % - Default (no Lag): the residual is staticised first (every lead/lag collapses to the
        %   current period), so the derivative aggregates all occurrences of varname across time —
        %   the same semantics as the AD jacobian, which compile_equations also staticises. This is
        %   the steady-state partial the analytical Jacobian for solve_system needs.
        % - With Lag = k: the residual is NOT staticised and the derivative is taken w.r.t. the
        %   variable at that period — varname (the bare current-period symbol) when k = 0, or the
        %   lead/lag varname(k) when k ≠ 0. So Lag = 0 is the contemporaneous block and
        %   Lag = -1 the one-lag block; the static default instead sums these.
        % - varname need not appear in the equation; the partial is then a numeric 0 ast.
        % - Raises modBuilder:partial:unknownEquation if eqname is not an equation, and
        %   modBuilder:partial:unparsableEquation if the equation cannot be parsed.
        % - Differentiating a function without a rule raises ast:diff_ast:noRule (see ast.diff_ast).
            arguments
                o
                eqname  (1,:) char {mustBeNonempty}
                varname (1,:) char {mustBeNonempty}
                options.Lag double {mustBeScalarOrEmpty, mustBeInteger} = []
            end
            if isempty(options.Lag)
                f = o.resolve_residual(eqname, 'partial', true);
                g = f.diff_ast(varname);
            else
                f = o.resolve_residual(eqname, 'partial', false);
                g = f.diff_ast(varname, options.Lag);
            end
        end % function

        function J = symbolic_jacobian(o, eqnames, varnames, options)
        % Matrix of symbolic partial derivatives of the equation residuals.
        %
        % INPUTS:
        % - o          [modBuilder]
        % - eqnames    [cell]        1×m cell array of equation names
        % - varnames   [cell]        1×n cell array of symbol names to differentiate w.r.t.
        % - Lag        [integer]     (name-value) period of the targets. Omitted (the default)
        %                            gives the STATIC Jacobian; an explicit value gives the dynamic
        %                            Jacobian block for that period (one call per lead/lag).
        %
        % OUTPUTS:
        % - J          [cell]        m×n cell of ast objects; entry (i,j) is ∂(residual_i)/∂var_j.
        %                            Structural zeros are stored as [] (the matrix is sparse), so
        %                            isempty(J{i,j}) tests whether var_j is absent from equation i.
        %
        % REMARKS:
        % - Same static-vs-dynamic semantics as partial (see its Lag remarks). A dynamic Jacobian
        %   over several periods is obtained with one call per lag (e.g. Lag=-1, Lag=0, Lag=1),
        %   each returning the m×n block for that period.
        % - Each equation's residual is built once and differentiated w.r.t. every variable
        %   (cheaper than m·n independent partial() calls).
        % - Recomputed on demand (no caching, per the AST-cache decision in the roadmap).
        % - Raises modBuilder:symbolic_jacobian:unknownEquation / :unparsableEquation as partial does.
            arguments
                o
                eqnames  cell
                varnames cell
                options.Lag double {mustBeScalarOrEmpty, mustBeInteger} = []
            end
            make_static = isempty(options.Lag);
            m = numel(eqnames);
            n = numel(varnames);
            J = cell(m, n);
            for i = 1:m
                f = o.resolve_residual(eqnames{i}, 'symbolic_jacobian', make_static);
                for j = 1:n
                    if make_static
                        g = f.diff_ast(varnames{j});
                    else
                        g = f.diff_ast(varnames{j}, options.Lag);
                    end
                    if strcmp(g.type, 'num') && g.value == 0
                        J{i, j} = [];   % structural zero
                    else
                        J{i, j} = g;
                    end
                end
            end
        end % function

        function f = resolve_residual(o, eqname, caller, make_static)
        % Look up an equation by name and return its LHS−RHS residual AST, staticised when
        % make_static is true (else the dynamic residual). Shared by partial and
        % symbolic_jacobian; caller names the error id namespace.
            eq_idx = find(strcmp(eqname, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
            if isempty(eq_idx)
                error(['modBuilder:' caller ':unknownEquation'], 'No equation named "%s".', eqname);
            end
            if make_static
                f = modBuilder.static_residual(o, eq_idx);
            else
                f = modBuilder.dynamic_residual(o, eq_idx);
            end
            if isempty(f)
                error(['modBuilder:' caller ':unparsableEquation'], 'Equation "%s" cannot be parsed.', eqname);
            end
        end % function

        function result = lagrangian_foc(o, value_eqname, constraint_eqnames, control_vars, options)
        % Derive the first-order conditions of a recursive (Bellman) optimisation problem.
        %
        % INPUTS:
        % - o                  [modBuilder]
        % - value_eqname       [char]   name of the value equation, written recursively as
        %                               W = u(controls, states) + beta*W(+1) (more generally
        %                               W = u + <continuation in W(+1)>). Its LHS variable is W.
        % - constraint_eqnames [cell]   equation names of the constraints (law of motion of the
        %                               states, other equilibrium conditions). Each gets a fresh
        %                               Lagrange multiplier, named mult_1, mult_2, ... in
        %                               constraint order (override with MultiplierPrefix/MultiplierNames).
        % - control_vars       [cell]   the controls/states to take FOCs with respect to.
        %
        % OPTIONS (name-value):
        % - MultiplierPrefix   [char]   prefix for the auto-generated multiplier names; the i-th
        %                               multiplier is named <prefix>_<i> (default 'mult').
        % - MultiplierNames    [cell]   explicit multiplier names, one per constraint, overriding
        %                               the positional default (default {}).
        %
        % OUTPUTS:
        % - result   [struct]   with fields:
        %                         .multipliers  [cell] the multiplier names introduced (one per
        %                                              constraint), positional unless overridden;
        %                         .controls     [cell] = control_vars;
        %                         .foc          [cell] the FOC equation strings ("<expr> = 0"),
        %                                              parallel to .controls;
        %                         .constraints  [cell] = constraint_eqnames (echoed for augment);
        %                         .value_eqname [char] = value_eqname (echoed for augment).
        %
        % REMARKS:
        % - The value function is eliminated by the envelope theorem: the density is
        %   ell = u + Σ_c mult_c·g_c (multipliers on the CONSTRAINTS, not on the Bellman
        %   equation), and the FOC for a control v is
        %     Σ_k  weight(k)·shift_lag( ∂ell/∂v(k), −k )  =  0
        %   over the periods k at which v appears, with the one-period weight given by the
        %   marginal continuation value M = ∂(value rhs)/∂W(+1) (the discount; M = beta in the
        %   time-additive case, a state-dependent expression for recursive preferences). A pure
        %   control has only the k=0 term (a static FOC); a state appears as a lead in the law
        %   of motion and picks up the discounted forward term (the Euler equation).
        % - This derives and RETURNS the FOCs (and the multipliers introduced); it does not yet
        %   add them to the model.
            arguments
                o
                value_eqname              (1,:) char {mustBeNonempty}
                constraint_eqnames        cell
                control_vars              cell
                options.MultiplierPrefix  (1,:) char = 'mult'
                options.MultiplierNames   cell = {}
            end
            if ~isempty(options.MultiplierNames) && numel(options.MultiplierNames) ~= numel(constraint_eqnames)
                error('modBuilder:lagrangian_foc:multiplierCount', 'MultiplierNames must have one name per constraint (%u given, %u expected).', numel(options.MultiplierNames), numel(constraint_eqnames));
            end
            paramnames = o.params(:, modBuilder.COL_NAME);

            % Value equation: split LHS = RHS; extract the per-period return u (rhs with the
            % continuation W(+1) zeroed) and the discount M = ∂rhs/∂W(+1).
            vidx = find(strcmp(value_eqname, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
            if isempty(vidx)
                error('modBuilder:lagrangian_foc:unknownEquation', 'No equation named "%s".', value_eqname);
            end
            LHSRHS = strsplit(o.equations{vidx, modBuilder.EQ_COL_EXPR}, '=');
            if numel(LHSRHS) ~= 2
                error('modBuilder:lagrangian_foc:badValueEquation', ...
                      'The value equation "%s" must have the form W = u + ... .', value_eqname);
            end
            vrhs = ast(strtrim(LHSRHS{2}));
            M = vrhs.diff_ast(value_eqname, 1);
            u = vrhs.replace_subtree(ast([value_eqname '(+1)']), ast('num', 0, {})).simplify();

            % Lagrangian density: u + Σ_c mult_c · g_c, with a fresh multiplier per constraint.
            ell = u;
            mults = cell(1, numel(constraint_eqnames));
            for ci = 1:numel(constraint_eqnames)
                cidx = find(strcmp(constraint_eqnames{ci}, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
                if isempty(cidx)
                    error('modBuilder:lagrangian_foc:unknownEquation', 'No equation named "%s".', constraint_eqnames{ci});
                end
                g = modBuilder.dynamic_residual(o, cidx);
                if isempty(options.MultiplierNames)
                    mults{ci} = sprintf('%s_%u', options.MultiplierPrefix, ci);
                else
                    mults{ci} = options.MultiplierNames{ci};
                end
                ell = ast('binop', '+', {ell, ast('binop', '*', {ast('sym', mults{ci}, {}), g})});
            end

            % FOC per control: sum over the periods where the control appears.
            focs = cell(1, numel(control_vars));
            for vi = 1:numel(control_vars)
                v = control_vars{vi};
                ks = ell.lags_of(v);
                foc = ast('num', 0, {});
                for kk = 1:numel(ks)
                    k = ks(kk);
                    d = ell.diff_ast(v, k);
                    s = d.shift_lag(-k, paramnames);
                    w = modBuilder.foc_weight(M, k, paramnames);
                    foc = ast('binop', '+', {foc, ast('binop', '*', {w, s})});
                end
                focs{vi} = [foc.simplify().string() ' = 0'];
            end

            result.multipliers = mults;
            result.controls = control_vars;
            result.foc = focs;
            result.constraints = reshape(constraint_eqnames, 1, []);
            result.value_eqname = value_eqname;
        end % function

        function result = ramsey_foc(o, value_eqname, instrument_vars, options)
        % Derive the Ramsey (optimal-policy) first-order conditions: a specialisation of
        % lagrangian_foc where every model equation other than the value equation is a
        % constraint, and the planner optimises over all endogenous variables plus the policy
        % instruments.
        %
        % INPUTS:
        % - o               [modBuilder]
        % - value_eqname    [char]   name of the recursive welfare equation (W = u + beta*W(+1)).
        % - instrument_vars [cell]   the policy instruments. Their own equations (e.g. a policy
        %                            rule), if any, are removed from the constraint set, since
        %                            under Ramsey the planner sets policy optimally; the
        %                            instruments are still controls.
        %
        % OPTIONS (name-value):
        % - MultiplierPrefix / MultiplierNames: forwarded to lagrangian_foc (see there).
        %
        % OUTPUTS:
        % - result   [struct]   as lagrangian_foc: .multipliers, .controls, .foc, .constraints,
        %                       .value_eqname.
        %
        % REMARKS:
        % - Constraints = all equations except the value equation and any instrument's rule.
        % - Controls = the endogenous variables plus the instruments, minus the value variable.
        %   The FOC of an instrument that appears in only one constraint pins that constraint's
        %   multiplier (often to zero), reproducing the textbook result.
            arguments
                o
                value_eqname              (1,:) char {mustBeNonempty}
                instrument_vars           cell
                options.MultiplierPrefix  (1,:) char = 'mult'
                options.MultiplierNames   cell = {}
            end
            alleq = o.equations(:, modBuilder.EQ_COL_NAME);
            excluded = [{value_eqname}, reshape(instrument_vars, 1, [])];
            constraint_eqnames = reshape(alleq(~ismember(alleq, excluded)), 1, []);
            controls = unique([reshape(o.var(:, modBuilder.COL_NAME), 1, []), reshape(instrument_vars, 1, [])], 'stable');
            controls = controls(~strcmp(controls, value_eqname));
            result = o.lagrangian_foc(value_eqname, constraint_eqnames, controls, 'MultiplierPrefix', options.MultiplierPrefix, 'MultiplierNames', options.MultiplierNames);
        end % function

        function o = augment(o, result, options)
        % Augment the model in place with the first-order conditions returned by lagrangian_foc
        % or ramsey_foc: add the Lagrange multipliers as endogenous variables and the FOCs as
        % equations, so the model becomes the (square) optimal-policy / planner problem ready for
        % write() and the LaTeX reporting methods.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - result   [struct]   the struct returned by lagrangian_foc / ramsey_foc, with fields
        %                       .multipliers, .controls, .foc, .constraints, .value_eqname.
        %
        % OPTIONS (name-value):
        % - MultiplierTexnames [cell]  one LaTeX name per multiplier (default {}: the i-th
        %                              multiplier gets '\mu_{i}').
        %
        % REMARKS:
        % - The value equation and the constraints are kept; an instrument's own rule (an equation
        %   keyed to a control that is not a constraint and not the value equation) is removed, since
        %   under the optimum the planner sets it via the FOCs.
        % - Each control that is currently exogenous (a policy instrument) or untyped is promoted to
        %   endogenous when its FOC is added; the multipliers are added as fresh endogenous variables.
        % - Equation keying: because a FOC need not contain the variable it is keyed to (e.g. an
        %   instrument that appears in no FOC), the FOCs are matched to the "needy" variables (the
        %   multipliers plus the controls that have no equation) preferring a variable that appears
        %   in the FOC, then arbitrarily. The key is only an internal label; it has no bearing on the
        %   .mod output, where equations and variable declarations are listed separately.
        % - Errors if a multiplier name already exists (pass MultiplierPrefix/MultiplierNames to
        %   lagrangian_foc/ramsey_foc to avoid the clash) or if the FOC count does not match the
        %   number of variables to determine (an ill-posed optimisation problem).
            arguments
                o
                result struct
                options.MultiplierTexnames cell = {}
            end
            mults = result.multipliers;
            controls = result.controls;
            focs = result.foc;
            constraints = result.constraints;
            value_eqname = result.value_eqname;
            if ~isempty(options.MultiplierTexnames) && numel(options.MultiplierTexnames) ~= numel(mults)
                error('modBuilder:augment:texnameCount', 'MultiplierTexnames must have one name per multiplier (%u given, %u expected).', numel(options.MultiplierTexnames), numel(mults));
            end

            % A multiplier name must be free: it is about to become a new endogenous variable.
            for i = 1:numel(mults)
                [found, type, ~] = o.lookup_symbol(mults{i});
                if found
                    error('modBuilder:augment:multiplierExists', 'Multiplier name "%s" is already a %s. Pass MultiplierPrefix= or MultiplierNames= to lagrangian_foc/ramsey_foc to choose free names.', mults{i}, type);
                end
            end

            % Drop instrument rules: an equation keyed to a control that is neither a constraint nor
            % the value equation. remove() demotes the variable to exogenous when it still appears
            % elsewhere, so the FOC add below re-promotes it to endogenous.
            eqnames = o.equations(:, modBuilder.EQ_COL_NAME);
            keep = [reshape(constraints, 1, []), {value_eqname}];
            drop = eqnames(ismember(eqnames, controls) & ~ismember(eqnames, keep));
            for i = 1:numel(drop)
                o = o.remove(drop{i});
            end

            % Needy variables (those that must receive a FOC equation): the multipliers plus the
            % controls that currently have no equation of their own.
            eqnames = o.equations(:, modBuilder.EQ_COL_NAME);
            controls_wo_eq = controls(~ismember(controls, reshape(eqnames, 1, [])));
            needy = [reshape(mults, 1, []), reshape(controls_wo_eq, 1, [])];
            if numel(needy) ~= numel(focs)
                error('modBuilder:augment:notWellPosed', 'Cannot augment: %u first-order conditions but %u variables to determine (%u multipliers + %u controls without an equation). The optimisation problem is not square.', numel(focs), numel(needy), numel(mults), numel(controls_wo_eq));
            end

            % Match each FOC to a needy variable, preferring a variable that appears in the FOC so the
            % key is meaningful where possible, then assigning the remainder arbitrarily.
            focsyms = cellfun(@(e) modBuilder.getsymbols(e), focs, 'UniformOutput', false);
            assigned = false(1, numel(focs));
            pair = zeros(1, numel(needy));
            for j = 1:numel(needy)
                for f = 1:numel(focs)
                    if ~assigned(f) && ismember(needy{j}, focsyms{f})
                        pair(j) = f;
                        assigned(f) = true;
                        break
                    end
                end
            end
            leftovers = find(~assigned);
            unfilled = find(pair == 0);
            for t = 1:numel(unfilled)
                pair(unfilled(t)) = leftovers(t);
            end
            for j = 1:numel(needy)
                o = o.addeq(needy{j}, focs{pair(j)}, false);
            end

            % Attach LaTeX names to the multipliers (\mu_{i} by default), warning on a clash with an
            % already-declared texname (ambiguous rendering, harmless to the model).
            existing_tex = struct2cell(o.texname_map());
            for i = 1:numel(mults)
                if isempty(options.MultiplierTexnames)
                    tn = sprintf('\\mu_{%u}', i);
                else
                    tn = options.MultiplierTexnames{i};
                end
                if ismember(tn, existing_tex)
                    warning('modBuilder:augment:texnameClash', 'Multiplier texname "%s" is already used by another symbol; the two will render identically.', tn);
                end
                o = o.endogenous(mults{i}, [], 'texname', tn);
            end
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
        % Validate that a type string is one of the allowed collection names
        %
        % INPUTS:
        % - type   [char]   Collection name to validate ('parameters', 'exogenous', 'endogenous' or 'equations')
        %
        % OUTPUTS:
        % None (throws error if invalid)
        %
        % REMARKS:
        % - Validates against modBuilder.VALID_TYPES, the plural collection-name vocabulary of the dimension/display API
        % - This is NOT the singular symbol-type vocabulary ('parameter'/'exogenous'/'endogenous') returned by typeof(); do not feed typeof()'s result here
        % - Provides helpful error message listing valid options
        % - Used internally by size(); table()/printlist2() validate their own (smaller) subset
        % - Can be called by users to validate collection names before use
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
                warning('modBuilder:validate_equation_syntax:suspiciousOperator', 'Equation contains "++". This may be unintended. Equation: "%s"', equation)
            end
            if contains(equation, '--')
                warning('modBuilder:validate_equation_syntax:suspiciousOperator', 'Equation contains "--". This may be unintended. Equation: "%s"', equation)
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

        function [props, meths, mlist] = class_name_lists()
        % Cached property / method name lists (and the method metadata array) of
        % the class. The class definition is fixed for the MATLAB session, so the
        % metaclass enumeration -- which subsref and numArgumentsFromSubscript
        % would otherwise repay on every dotted access, the most executed path in
        % interactive use -- is done once per session.
            persistent p m ml
            if isempty(p)
                mc = ?modBuilder;
                p = {mc.PropertyList.Name};
                ml = mc.MethodList;
                m = {ml.Name};
            end
            props = p;
            meths = m;
            mlist = ml;
        end % function

        function kinds = symbol_kinds()
        % Descriptor for the three symbol tables so code that treats parameters, exogenous and endogenous variables uniformly loops over one list instead of repeating three near-identical blocks.
        %
        % OUTPUTS:
        % - kinds  [struct]  1×3 struct array with fields:
        %                    .prop   - property name; o.<prop> is the n×4 table and o.T.<prop> the symbol→equations map (the two share the name)
        %                    .type   - canonical type string ('parameter' / 'exogenous' / 'endogenous')
        %                    .label  - display label used by findsymbol
            kinds = struct('prop', {'params', 'varexo', 'var'}, 'type', {'parameter', 'exogenous', 'endogenous'}, 'label', {'Parameter', 'Exogenous variable', 'Endogenous variable'});
        end % function

        function row = symbol_row(name, src, idx)
        % Assemble one symbol-table row [name, value, long_name, tex_name] by taking the value and metadata from row idx of source table src under a (possibly new) name.
        %
        % INPUTS:
        % - name  [char]   symbol name to store in the new row
        % - src   [cell]   n×4 source symbol table (params / varexo / var)
        % - idx   [integer] row of src to copy the value and metadata from
        %
        % OUTPUTS:
        % - row   [cell]   1×4 row suitable for assignment into a merged table
            row = cell(1, 4);
            row{modBuilder.COL_NAME}      = name;
            row{modBuilder.COL_VALUE}     = src{idx, modBuilder.COL_VALUE};
            row{modBuilder.COL_LONG_NAME} = src{idx, modBuilder.COL_LONG_NAME};
            row{modBuilder.COL_TEX_NAME}  = src{idx, modBuilder.COL_TEX_NAME};
        end % function

        function names = placeholders(s)
        % Return the sorted unique set of implicit-loop placeholders ($0, $1, ...) in s.
        %
        % INPUTS:
        % - s      [char]   1×n expression / equation name / template
        %
        % OUTPUTS:
        % - names  [cell]   1×k cell of placeholder tokens, sorted by index number
        %                   (numeric order, so $2 comes before $10).
            names = unique(regexp(s, '\$\d+', 'match'));
            if ~isempty(names)
                [~, k] = sort(cellfun(@(t) sscanf(t(2:end), '%u'), names));
                names = names(k);
            end
        end % function

        function s = fill_placeholders(s, tokens, values)
        % Replace each implicit-loop placeholder token in s by its value.
        %
        % INPUTS:
        % - s       [char]   template string containing placeholder tokens
        % - tokens  [cell]   1×k placeholder tokens (e.g. {'$1', '$2'})
        % - values  [cell]   1×k values aligned with tokens (integers or char)
        %
        % OUTPUTS:
        % - s       [char]   template with every token replaced by its value
        %
        % REMARKS:
        % - strrep is literal, so a token may appear several times in s or not at all
        %   (useful when an expression uses a subset of the caller's placeholders),
        %   and values containing sprintf-special characters (\, %) need no escaping.
        % - Tokens are rewritten longest-first so a shorter token ($1) cannot corrupt a longer one that shares its prefix ($10).
            [~, order] = sort(cellfun(@strlength, tokens), 'descend');
            for j = order(:)'
                v = values{j};
                if ~ischar(v)
                    v = num2str(v);
                end
                s = strrep(s, tokens{j}, v);
            end
        end % function

        function static = staticise_equation_string(eq_str)
        % Strip time subscripts from an equation string: x(-1), y(+2), z(0) → x, y, z.
        %
        % INPUTS:
        % - eq_str  [char]   equation expression as stored in o.equations.
        %
        % OUTPUTS:
        % - static  [char]   the same expression with every "(\w+)([+-]?\d+)" call collapsed
        %                    to its first capture group (the symbol name).
            static = regexprep(eq_str, '(\w+)\([+-]?\d+\)', '$1');
        end % function

        function expr_out = substitute_symbols(expr_in, replacements)
        % Replace identifier tokens in expr_in according to `replacements` (a struct
        % with one field per symbol to substitute).
        %
        % INPUTS:
        % - expr_in       [char]   expression text.
        % - replacements  [struct] field name = symbol, field value = char replacement.
        %
        % OUTPUTS:
        % - expr_out      [char]   expr_in with every identifier token that has a
        %                          matching field replaced. Tokens absent from the
        %                          struct (function names, untracked symbols) are kept
        %                          verbatim.
        %
        % REMARKS:
        % - Single regex scan over expr_in (O(L)), not one pass per declared symbol
        %   (the previous shape was O(N·L) where N is the symbol count).
        % - The identifier pattern matches the one used by getsymbols: the negative
        %   lookbehind (?<![.\d]) rejects matches preceded by a digit or dot, so
        %   scientific notation (1e5) and decimals (0.33) are left intact.
            [starts, ends, tokens] = regexp(expr_in, '(?<![.\d])[a-zA-Z_]\w*', 'start', 'end', 'match');
            if isempty(tokens)
                expr_out = expr_in;
                return
            end
            parts = cell(1, 2 * numel(tokens) + 1);
            cursor = 1;
            for k = 1:numel(tokens)
                parts{2*k - 1} = expr_in(cursor : starts(k) - 1);
                if isfield(replacements, tokens{k})
                    parts{2*k} = replacements.(tokens{k});
                else
                    parts{2*k} = tokens{k};
                end
                cursor = ends(k) + 1;
            end
            parts{end} = expr_in(cursor : end);
            expr_out = [parts{:}];
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

            modBuilder.check_indices_values(index_values);
            index_map = dictionary(string(all_indices(:)), index_values(:));

            % Expression-side Cartesian product (degenerate single iteration if expr1 has
            % no placeholders). expr2 is filled with expr1's token list: tokens absent
            % from expr2 (the allowed-subset case) are simply no-ops for strrep.
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
                    ce1 = modBuilder.fill_placeholders(expr1, inames_expr1, mIndex_expr(i,:));
                    ce2 = modBuilder.fill_placeholders(expr2, inames_expr1, mIndex_expr(i,:));
                    if isempty(eqname)
                        leaf_fn(ce1, ce2);
                    else
                        leaf_fn(ce1, ce2, eqname);
                    end
                end
            else
                % eqname has its own (possibly disjoint) placeholders.
                eq_values = cellfun(@(x) index_map{x}, inames_eq, 'UniformOutput', false);
                mIndex_eq = table2cell(combinations(eq_values{:}));
                for j = 1:size(mIndex_eq, 1)
                    current_eqname = modBuilder.fill_placeholders(eqname, inames_eq, mIndex_eq(j,:));
                    for i = 1:size(mIndex_expr, 1)
                        ce1 = modBuilder.fill_placeholders(expr1, inames_expr1, mIndex_expr(i,:));
                        ce2 = modBuilder.fill_placeholders(expr2, inames_expr1, mIndex_expr(i,:));
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

        function rethrow_unless(err, prefixes)
        % Rethrow err unless its identifier starts with one of the given prefixes.
        %
        % INPUTS:
        % - err       [MException]   exception caught by the caller
        % - prefixes  [cell]         identifier prefixes marking expected failures
        %
        % REMARKS:
        % - Guard for the try/catch fences around the symbolic-closure machinery
        %   and the calibration/anchor trial loops: deliberate refusals carry
        %   structured identifiers (ast:* from the recognisers and the evaluator,
        %   modBuilder:* from the trial validation) and are ordinary control flow
        %   for those callers. Anything else is a programming error: swallowing it
        %   would silently degrade steady-state plans to "no closed form" and hide
        %   regressions from the test suite.
            if ~any(cellfun(@(p) strncmp(err.identifier, p, numel(p)), prefixes))
                rethrow(err)
            end
        end % function

        function check_knife_edge(coefs, values, eqname, vname)
        % Warn when one of the pinning coefficients collected by ast.isolate
        % evaluates to a numerical zero at the calibration: the closed form is
        % symbolically valid but divides by zero at the calibrated point -- a
        % unit root the symbolic recognisers cannot see (e.g. 1 - beta*R once
        % beta*R = 1, or 1 - R on an accumulation equation with R = 1).
        %
        % INPUTS:
        % - coefs    [cell]    pinning divisor asts, from the coefs field of
        %                      ast.isolate's diagnostic output
        % - values   [struct]  numeric shadow of the plan (calibrated parameters,
        %                      exogenous levels, closed forms evaluated so far)
        % - eqname   [char]    equation name, for the message
        % - vname    [char]    pinned variable name, for the message
        %
        % REMARKS:
        % - The tolerance is relative to the summed magnitude of the coefficient's
        %   additive terms, so 1 - beta*R is caught at beta*R = 1 without flagging
        %   genuinely small coefficients on badly scaled models.
        % - A coefficient referencing an unavailable value is skipped: nothing can
        %   be concluded here, and that gap surfaces loudly at evaluation time.
            for k = 1:numel(coefs)
                c = coefs{k};
                try
                    v = c.eval(values);
                catch err
                    modBuilder.rethrow_unless(err, {'ast:'});
                    continue
                end
                if ~(isnumeric(v) && isscalar(v) && isfinite(v) && isreal(v))
                    continue
                end
                scale = 1;
                try
                    terms = ast.flatten(c.canonicalise().simplify(), '+');
                    s = 0;
                    for tt = 1:numel(terms)
                        s = s + abs(terms{tt}.eval(values));
                    end
                    scale = max(1, s);
                catch err
                    modBuilder.rethrow_unless(err, {'ast:'});
                end
                if abs(v) <= 1e-9 * scale
                    modBuilder.warn_silent('modBuilder:steady_plan:calibrationUnitRoot', 'Equation "%s" pins %s only on a knife edge: the coefficient %s evaluates to %.3g at the calibration, so its closed form divides by a numerical zero -- a unit root at this calibration. Fix the level of %s by other means or move the calibration off the knife edge.', eqname, vname, c.string(), v, vname);
                    return
                end
            end
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

        function is_exo = exogenous_processes(keys, rawsyms, isexo_fn)
        % Identify variables that belong to an exogenous driving process (AR/ARMA/VAR).
        %
        % INPUTS:
        % - keys      [cell]   n×1 variable name keyed to each equation (equation i pins keys{i})
        % - rawsyms   [cell]   n×1, each a cell of the symbol names referenced by equation i
        %                      (endogenous, exogenous and parameter names; STEADY_STATE(y)
        %                      counts as a reference to y)
        % - isexo_fn  [handle] predicate isexo_fn(name) -> true iff name is an exogenous variable
        %
        % OUTPUTS:
        % - is_exo    [logical] n×1; is_exo(i) true iff keys{i} is economically exogenous
        %
        % METHOD:
        % Build the dependency graph over variables (edge x -> y iff the equation keyed to
        % x references endogenous y). A variable is exogenous iff its strongly-connected
        % block is a sink (its equations reference no endogenous variable outside the
        % block: an AR/ARMA references only its own lags, a VAR only its block members)
        % AND the block is driven by at least one exogenous innovation. Sink blocks with
        % no innovation are ordinary constants/definitions, not exogenous processes.
            n = numel(keys);
            is_exo = false(n, 1);
            if n == 0
                return
            end
            keypos = dictionary(string(keys(:)), (1:n)');
            endorefs = cell(n, 1);
            has_exo = false(n, 1);
            src = []; tgt = [];
            for i = 1:n
                er = {};
                for c = 1:numel(rawsyms{i})
                    nm = rawsyms{i}{c};
                    if isKey(keypos, nm)
                        if ~strcmp(nm, keys{i})
                            er{end+1} = nm; %#ok<AGROW>
                        end
                    elseif isexo_fn(nm)
                        has_exo(i) = true;
                    end
                end
                endorefs{i} = er;
                for c = 1:numel(er)
                    src(end+1) = i; %#ok<AGROW>
                    tgt(end+1) = keypos(er{c}); %#ok<AGROW>
                end
            end
            scc = conncomp(digraph(src, tgt, [], n), 'Type', 'strong');
            is_sink = true(1, max(scc));
            blk_exo = false(1, max(scc));
            for i = 1:n
                blk_exo(scc(i)) = blk_exo(scc(i)) || has_exo(i);
                for c = 1:numel(endorefs{i})
                    if scc(keypos(endorefs{i}{c})) ~= scc(i)
                        is_sink(scc(i)) = false;
                    end
                end
            end
            for i = 1:n
                is_exo(i) = is_sink(scc(i)) && blk_exo(scc(i));
            end
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
                C{s} = newword;
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

            % The expansion below maps index_values{j} onto $j, so the placeholder
            % set must be exactly $1..$n: a gap (e.g. $1, $3) would leave the odd
            % token unexpanded while silently shifting the value/index pairing.
            if nindices > 0 && ~isequal(cellfun(@(t) sscanf(t(2:end), '%u'), inames(:)'), 1:nindices)
                error('modBuilder:expand_templates:indexMismatch', 'Implicit-loop placeholders must be $1..$%u with no gaps; found %s.', nindices, strjoin(inames, ', '))
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
        % Count the total number of unresolved variables across the non-anchor blocks
        % of a steady-state plan. Used by suggest_calibrations to score candidate
        % swaps. Anchor blocks are excluded: their levels are user-supplied by
        % convention, an open one is not a residual a swap should chase. Open
        % SINGLETONS do count -- with every (equation, unknown) pair probed, an
        % unresolved variable often survives alone (a transcendental FOC) rather than
        % inside a simultaneous block.
            n = 0;
            for k = 1:numel(blocks)
                b = blocks(k);
                if ~strcmp(b.kind, 'anchor')
                    resolved = {b.closed_form.var};
                    n = n + numel(setdiff(b.vars, resolved));
                end
            end
        end % function

        function [nres, open] = anchor_residual(o, anchors, dropvalues, propagate)
        % Run steady_plan(Match, Anchors) on a copy of o with the steady-state values
        % of dropvalues removed, and count the open variables. The value removal
        % matters: a dropped candidate must not keep feeding the known-value
        % propagation, otherwise the trial would understate its contribution. Used by
        % suggest_anchors to score candidate drops.
            oc = o.copy();
            if ~isempty(dropvalues) && ~isempty(oc.steady_state)
                oc.steady_state = oc.steady_state(~ismember(oc.steady_state(:, modBuilder.SS_COL_NAME), dropvalues), :);
            end
            blocks = oc.steady_plan(Match=true, Anchors=anchors, PropagateKnown=propagate);
            open = {};
            for k = 1:numel(blocks)
                if strcmp(blocks(k).kind, 'anchor'), continue, end
                solved = {};
                if ~isempty(blocks(k).closed_form), solved = {blocks(k).closed_form.var}; end
                open = [open, setdiff(blocks(k).vars, solved)]; %#ok<AGROW>
            end
            nres = numel(open);
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

        function cf = ratio_reduce(residuals, vars_block, param_names)
        % Close a block that is homogeneous in its variables by a RATIO change of
        % variables. Some block equation involves the block variables only through
        % their ratio (it is homogeneous of degree 0 -- e.g. a factor-demand ratio
        % w*L/(r*K) = const); writing each variable as ratio*gauge makes the gauge
        % cancel there, pinning the ratio, and reduces the block to a triangular system
        % in {ratios, gauge}. This is the hand technique (solve the ratio, back out the
        % level) that single-variable elimination -- which reports the block as an
        % irreducible cycle -- cannot reach.
        %
        % Returns the closed forms for the ORIGINAL variables (gauge, then each other
        % variable as ratio*gauge with the auxiliary ratio names inlined), or an empty
        % struct if no gauge choice triangularises the block.
            cf = struct('var', {}, 'expr', {});
            nb = numel(vars_block);
            if nb < 2
                return
            end
            % The change of variables bites when some block equation involves the
            % block variables through their ratios alone (homogeneous of degree 0):
            % the gauge then cancels there and pins the ratios. On a LARGE block with
            % no such equation, the nb attempts below -- each paying expand/simplify
            % on every residual plus a full elimination -- are almost surely waste
            % (they dominated a whole steady_plan profile at 90 of 93 seconds), so
            % they are skipped. Small blocks keep the attempt regardless: it is cheap,
            % and the internal re-matching of the transformed equations can rescue a
            % block whose declaration pairing starves the elimination of the right
            % probes (an anchor block never re-paired by matchequations). Degree-0
            % homogeneity is probed numerically at deterministic positive points; a
            % residual that cannot be evaluated there keeps the benefit of the doubt.
            has_ratio_eq = nb <= 4;
            for e = 1:numel(residuals)
                if has_ratio_eq
                    break
                end
                syms = residuals{e}.symbol_names();
                if ~any(ismember(vars_block, syms))
                    continue
                end
                try
                    vals = struct();
                    for si = 1:numel(syms)
                        vals.(syms{si}) = 1 + 0.05 * si;
                    end
                    r0 = residuals{e}.eval(vals);
                    okhom = isfinite(r0) && isreal(r0);
                    for lambda = [2, 3]
                        vals2 = vals;
                        for vi = 1:numel(vars_block)
                            if isfield(vals2, vars_block{vi})
                                vals2.(vars_block{vi}) = lambda * vals2.(vars_block{vi});
                            end
                        end
                        r1 = residuals{e}.eval(vals2);
                        if ~(isfinite(r1) && isreal(r1) && abs(r1 - r0) <= 1e-9 * max(1, abs(r0)))
                            okhom = false;
                            break
                        end
                    end
                catch err
                    modBuilder.rethrow_unless(err, {'ast:'});
                    okhom = true;
                end
                if okhom
                    has_ratio_eq = true;
                    break
                end
            end
            if ~has_ratio_eq
                return
            end
            for g = 1:nb
                gauge = vars_block{g};
                others = vars_block([1:g-1, g+1:nb]);
                rnames = cell(1, numel(others));
                for i = 1:numel(others)
                    rnames{i} = [others{i} '_ratio'];
                end
                subres = cell(size(residuals));
                for e = 1:numel(residuals)
                    r = residuals{e};
                    for i = 1:numel(others)
                        r = r.substitute(others{i}, ast(sprintf('%s*%s', rnames{i}, gauge)), param_names);
                    end
                    % expand so the gauge, now appearing in several factors, collects into
                    % one power -- exposing the ratio (gauge cancels) and the level monomial.
                    subres{e} = r.expand().simplify();
                end
                new_vars = [rnames, {gauge}];
                % Align the transformed residuals to the new variables.
                lhs = cell(size(subres));
                [e2v, ~, ~] = modBuilder.matchequations(subres, lhs, new_vars);
                aligned = cell(1, numel(new_vars));
                ok = true;
                for vi = 1:numel(new_vars)
                    pos = find(strcmp(e2v, new_vars{vi}), 1);
                    if isempty(pos), ok = false; break; end
                    aligned{vi} = subres{pos};
                end
                if ~ok, continue; end
                elim = ast.iterated_elimination(aligned, new_vars, param_names, true);
                if numel(elim) ~= nb, continue; end
                % Translate back: inline the auxiliary ratio names, emit the gauge, then
                % each original variable as ratio*gauge.
                names = {elim.var}; exprs = {elim.expr};
                % Hoist the loop-invariant name -> position lookups, guard each
                % substitution on membership (refreshed after a hit, since inlining a
                % ratio expression can introduce other ratio names the unconditional
                % loop would have substituted later), and stop after an identity pass.
                ridx = zeros(1, numel(rnames));
                for i = 1:numel(rnames)
                    pos = find(strcmp(names, rnames{i}), 1);
                    if ~isempty(pos), ridx(i) = pos; end
                end
                for pass = 1:nb
                    any_hit = false;
                    for a = 1:numel(exprs)
                        syms_a = exprs{a}.symbol_names();
                        for i = 1:numel(rnames)
                            if ridx(i) && ismember(rnames{i}, syms_a)
                                exprs{a} = exprs{a}.substitute(rnames{i}, exprs{ridx(i)}, param_names);
                                syms_a = exprs{a}.symbol_names();
                                any_hit = true;
                            end
                        end
                    end
                    if ~any_hit, break, end
                end
                gi = find(strcmp(names, gauge), 1);
                cf(1).var = gauge; cf(1).expr = exprs{gi}.simplify().string();
                for i = 1:numel(others)
                    cf(end+1).var = others{i}; %#ok<AGROW>
                    cf(end).expr = sprintf('(%s)*%s', exprs{ridx(i)}.simplify().string(), gauge);
                end
                return
            end
            cf = struct('var', {}, 'expr', {});
        end % function

        function cf = ratio_parametrise(residuals, vars_block, param_names, gauge, values)
        % Parametrise a scale-free block in a gauge variable: solve the RATIOS var/gauge
        % in closed form and return each non-gauge variable as (ratio)*gauge, the gauge
        % itself staying free. The partial counterpart of ratio_reduce, for blocks whose
        % scale is pinned OUTSIDE the block: when every block equation is homogeneous in
        % the block variables (a normalisation anchor freed a degree-0 equation into the
        % block), the equations determine the ratios but not the level, so ratio_reduce
        % -- which requires the gauge to close internally -- returns empty. The gauge
        % backout in steady_plan then recovers the level from a consistency equation.
        %
        % After the substitution v -> ratio_v*gauge each residual must be HOMOGENEOUS in
        % the gauge (checked with ast.scaling_degree; values supplies the calibration for
        % numeric exponents): r(ratios, gauge) = gauge^d * r(ratios, 1), so solving on
        % the unit-gauge slice gauge := 1 pins the ratios exactly. A residual that is not
        % homogeneous in the gauge invalidates this gauge choice (empty result).
        %
        % Returns one closed form per non-gauge variable, in evaluation order. Each is
        % the product (ratio)*gauge simplified as an AST; an auxiliary ratio referenced
        % by a later one is rewritten as var/gauge, so the emitted expressions reference
        % the already-assigned block variables instead of inlining the whole chain
        % (Z3 = c*Z2 rather than the c*(chain for Z2) monomial). Empty struct if some
        % ratio cannot be closed or the gauge does not cancel from the ratio chain.
            cf = struct('var', {}, 'expr', {});
            others = vars_block(~strcmp(vars_block, gauge));
            if isempty(others) || numel(others) + 1 ~= numel(vars_block)
                return
            end
            rnames = cell(1, numel(others));
            for i = 1:numel(others)
                rnames{i} = [others{i} '_ratio'];
            end
            gdict = dictionary(string(gauge), 1);
            subres = cell(size(residuals));
            for e = 1:numel(residuals)
                r = residuals{e};
                for i = 1:numel(others)
                    r = r.substitute(others{i}, ast(sprintf('%s*%s', rnames{i}, gauge)), param_names);
                end
                % expand so the gauge, spread over several factors, collects into one
                % power per monomial; then check homogeneity in the gauge and restrict
                % to the unit-gauge slice.
                r = r.expand();
                [~, cons, okh] = r.scaling_degree(gdict, 1, values);
                if ~okh
                    return
                end
                for k = 1:numel(cons)
                    if abs(cons{k}) > 1e-9
                        return
                    end
                end
                subres{e} = r.substitute(gauge, ast('1'), param_names).simplify();
            end
            % The unit-gauge slice must pin the ratios uniquely: if the ratio system
            % is itself scale-free, the block carries MORE than one scale and a single
            % gauge cannot parametrise it (elimination on the slice would close the
            % leftover freedom on the trivial zero ray). The multi-gauge backout
            % handles that case instead.
            if modBuilder.block_scale_freedom(subres, rnames, values)
                return
            end
            % Align the transformed residuals to the ratio unknowns; the surplus
            % equation (redundant within a scale-free block) stays unmatched.
            lhs = cell(size(subres));
            [e2v, ~, ~] = modBuilder.matchequations(subres, lhs, rnames);
            aligned = cell(1, numel(rnames));
            for vi = 1:numel(rnames)
                pos = find(strcmp(e2v, rnames{vi}), 1);
                if isempty(pos)
                    return
                end
                aligned{vi} = subres{pos};
            end
            elim = ast.iterated_elimination(aligned, rnames, param_names, true);
            if numel(elim) ~= numel(rnames)
                return
            end
            names = {elim.var}; exprs = {elim.expr};
            % Validation on the fully inlined chain: every ratio must close and be
            % free of the gauge (otherwise the block is not scale-free in this gauge).
            % Loop-invariant name -> position lookups hoisted; each substitution is
            % guarded on membership (refreshed after a hit, since inlining can
            % introduce other ratio names) and the pass loop stops once a full pass
            % changes nothing.
            ridx = zeros(1, numel(rnames));
            for i = 1:numel(rnames)
                pos = find(strcmp(names, rnames{i}), 1);
                if ~isempty(pos), ridx(i) = pos; end
            end
            inlined = exprs;
            for pass = 1:numel(rnames)
                any_hit = false;
                for a = 1:numel(inlined)
                    syms_a = inlined{a}.symbol_names();
                    for i = 1:numel(rnames)
                        if ridx(i) && ismember(rnames{i}, syms_a)
                            inlined{a} = inlined{a}.substitute(rnames{i}, inlined{ridx(i)}, param_names);
                            syms_a = inlined{a}.symbol_names();
                            any_hit = true;
                        end
                    end
                end
                if ~any_hit, break, end
            end
            for i = 1:numel(others)
                if ~ridx(i) || ismember(gauge, inlined{ridx(i)}.simplify().symbol_names())
                    cf = struct('var', {}, 'expr', {});
                    return
                end
            end
            % Emission in elimination order: an auxiliary ratio referenced by a later
            % one is rewritten as its block variable over the gauge, and the product
            % with the gauge is simplified as an AST (var/gauge*gauge collapses).
            gauge_ref = ast(gauge);
            for a = 1:numel(names)
                oi = find(strcmp(rnames, names{a}), 1);
                e = exprs{a};
                syms_e = e.symbol_names();
                for i = 1:numel(rnames)
                    if ismember(rnames{i}, syms_e)
                        e = e.substitute(rnames{i}, ast(sprintf('%s/%s', others{i}, gauge)), param_names);
                        syms_e = e.symbol_names();
                    end
                end
                full = ast('binop', '*', {e, gauge_ref}).simplify();
                cf(end+1).var = others{oi}; %#ok<AGROW>
                cf(end).expr = full.string();
            end
        end % function

        function tf = block_scale_freedom(residuals, vars_block, values)
        % True when the block equations are jointly HOMOGENEOUS in the block variables:
        % assigning each variable v an exponent s_v, every residual scales consistently
        % (all monomials of an equation share a degree, nonlinear-call arguments have
        % degree 0, per ast.scaling_degree) for some non-zero choice of the s_v. Such a
        % block pins the ratios of its variables only: the solution set contains a scale
        % ray -- including the all-zero point -- so single-variable elimination must not
        % be trusted for the level (it "closes" the block on the trivial ray). An
        % unanalysable residual makes the test return false (treated as pinned), which
        % preserves the ordinary elimination path.
            tf = false;
            nb = numel(vars_block);
            vi = dictionary(string(vars_block(:)), (1:nb)');
            C = zeros(0, nb);
            for e = 1:numel(residuals)
                [~, cons, ok] = residuals{e}.expand().scaling_degree(vi, nb, values);
                if ~ok
                    return
                end
                for k = 1:numel(cons)
                    C(end+1, :) = cons{k}; %#ok<AGROW>
                end
            end
            if isempty(C)
                tf = true;
                return
            end
            tf = size(null(C, 'r'), 2) > 0;
        end % function

        function [cf, closed_all] = rematch_eliminate(residuals, unknowns, param_names)
        % Iterated re-matching + elimination to a fixed point: pair the equations to
        % the unknowns by bipartite matching, run the paired iterated_elimination,
        % substitute whatever closed into ALL the equations (a consumed equation then
        % reduces to 0 = 0 and drops out of the next matching), and re-match the
        % shrunken unknown set. The re-match is the point: the pairing a large system
        % forces on a subset can be unsolvable -- the wage recursions orient the net
        % wage as f(gross wage), a shape no recogniser inverts -- while the pairing
        % chosen on the subset alone is linear (the labour FOC pins the net wage once
        % consumption is known). Used by the multi-gauge backout.
        %
        % Returns the closed forms in evaluation order and closed_all = true when
        % every unknown was resolved (cf may be partial otherwise).
        %
        % Each round starts with FORCED propagation: an equation whose unknown set
        % has shrunk to a single variable pins that variable with no pairing choice,
        % and closing it can make further equations single-unknown (eq(GDP) then
        % eq(Z2|GDP known) then ...). Matching only arbitrates the genuinely
        % simultaneous rest. Without this pass the matcher can pair a variable away
        % from its dedicated equation (GDP to the production identity instead of its
        % own consistency equation), and the greedy elimination then expresses the
        % recursion levels parametrically in a variable it never closes.
            cf = struct('var', {}, 'expr', {});
            closed_all = false;
            remaining = unknowns;
            for round = 1:numel(unknowns)
                % forced-singleton propagation to a fixed point
                forced = true;
                while forced && ~isempty(remaining)
                    forced = false;
                    for e = 1:numel(residuals)
                        hit = remaining(ismember(remaining, residuals{e}.symbol_names()));
                        if ~isscalar(hit), continue, end
                        v = hit{1};
                        rhs = residuals{e}.isolate(v);
                        if isempty(rhs) || (strcmp(rhs.type, 'num') && rhs.value == 0)
                            continue
                        end
                        cf(end+1).var = v; %#ok<AGROW>
                        cf(end).expr = rhs.string();
                        remaining = remaining(~strcmp(remaining, v));
                        for e2 = 1:numel(residuals)
                            if ast.count_occurrences(residuals{e2}, v) > 0
                                residuals{e2} = residuals{e2}.substitute(v, rhs, param_names).simplify();
                            end
                        end
                        forced = true;
                        break
                    end
                end
                if isempty(remaining)
                    closed_all = true;
                    return
                end
                lhs = cell(size(residuals));
                [e2v, ~, ~] = modBuilder.matchequations(residuals, lhs, remaining);
                aligned = cell(1, numel(remaining));
                for vi = 1:numel(remaining)
                    pos = find(strcmp(e2v, remaining{vi}), 1);
                    if isempty(pos), return, end
                    aligned{vi} = residuals{pos};
                end
                elim = ast.iterated_elimination(aligned, remaining, param_names, true);
                if isempty(elim), return, end
                for jj = 1:numel(elim)
                    cf(end+1).var = elim(jj).var; %#ok<AGROW>
                    cf(end).expr = elim(jj).expr.string();
                end
                remaining = remaining(~ismember(remaining, {elim.var}));
                if isempty(remaining)
                    closed_all = true;
                    return
                end
                % inline the newly closed forms everywhere before the next round
                for e = 1:numel(residuals)
                    r = residuals{e};
                    for pass = 1:numel(elim) + 1
                        syms_r = r.symbol_names();
                        hitany = false;
                        for jj = 1:numel(elim)
                            if ismember(elim(jj).var, syms_r)
                                r = r.substitute(elim(jj).var, elim(jj).expr, param_names);
                                hitany = true;
                            end
                        end
                        if ~hitany, break, end
                    end
                    residuals{e} = r.simplify();
                end
            end
        end % function

        function tf = homogeneous_in(r, vars, values)
        % True when r is a homogeneous function of vars with a non-zero degree: its
        % zero set is then a scale ray through the origin, so a zero root extracted
        % from it is the trivial-ray artefact, not a level. Used by the gauge backout
        % to reject spurious zero solutions.
            vi = dictionary(string(vars(:)), (1:numel(vars))');
            [deg, cons, ok] = r.expand().scaling_degree(vi, numel(vars), values);
            tf = false;
            if ~ok
                return
            end
            for k = 1:numel(cons)
                if any(abs(cons{k}) > 1e-9)
                    return
                end
            end
            tf = any(abs(deg) > 1e-9);
        end % function

        function reach = reach_closure(seeds, cf_names, syms_cf)
        % Transitive-reachability fixed point over the emitted closed forms: reach(j)
        % is true when cf_names{j}'s expression references a seed name directly, or
        % references another closed form that (transitively) does. Used by the gauge
        % backout to decide which chains must be inlined into a consistency equation
        % (they reach the gauge) and which defer the backout to a later round (they
        % reach another still-open variable).
        %
        % INPUTS:
        % - seeds     [cell]     seed symbol names
        % - cf_names  [cell]     1×m closed-form variable names
        % - syms_cf   [cell]     1×m symbol-name sets, syms_cf{j} for cf_names{j}'s expression
        %
        % OUTPUTS:
        % - reach     [logical]  1×m reachability mask
            reach = false(1, numel(cf_names));
            changed = true;
            while changed
                changed = false;
                for jj = 1:numel(cf_names)
                    if ~reach(jj) && (any(ismember(seeds, syms_cf{jj})) || any(reach(ismember(cf_names, syms_cf{jj}))))
                        reach(jj) = true; changed = true;
                    end
                end
            end
        end % function

        function [r, ok] = inline_chains(r, forbidden, sub_names, sub_exprs, param_names)
        % Iteratively inline the closed-form chains sub_names -> sub_exprs into the
        % residual r until none of their names remains, simplifying after each sweep.
        % The gauge backout uses this to reduce a consistency equation to the open
        % gauges before probing it with ast.isolate.
        %
        % INPUTS:
        % - r            [ast]    residual to reduce
        % - forbidden    [cell]   symbol names that must never appear: the reduction is
        %                         abandoned (ok=false) when r references one, since the
        %                         equation then depends on another still-open variable
        % - sub_names    [cell]   substitution names, in priority order (first match
        %                         wins when a name appears more than once)
        % - sub_exprs    [cell]   expression strings aligned with sub_names
        % - param_names  [cell]   parameter names kept time-invariant by substitute
        %
        % OUTPUTS:
        % - r   [ast]      reduced residual (meaningful only when ok is true)
        % - ok  [logical]  false when a forbidden symbol appears, the pass cap is hit,
        %                  or the inlining blows the residual up past the node cap
            ok = true;
            for pass = 1:32
                syms_r = r.symbol_names();
                if any(ismember(syms_r, forbidden))
                    ok = false; break
                end
                todo = syms_r(ismember(syms_r, sub_names));
                if isempty(todo), break, end
                if pass == 32, ok = false; break, end
                for tt = 1:numel(todo)
                    s = todo{tt};
                    r = r.substitute(s, ast(sub_exprs{find(strcmp(sub_names, s), 1)}).staticise(), param_names);
                end
                r = r.simplify();
                if ast.node_count(r) > 8192
                    % inlining the chains is blowing the residual up; no recogniser
                    % will read anything off it
                    ok = false; break
                end
            end
        end % function

        function blocks = gauge_backout(o, blocks, eqasts_s, keys, var_idx, is_norm_anchor, known_names, known_asts, param_names, calib_values)
        % Recover the level of scale-free blocks from the consistency equations
        % absorbed by the normalisation anchors (the steady_plan gauge backout).
        % Re-matching a freed anchor equation inside a block can leave that block
        % HOMOGENEOUS in its variables: its equations pin the ratios but not the
        % level, and the scale-pinning equation sits among the consistency
        % conditions absorbed by the anchors. Each simultaneous block left with
        % open variables is re-parametrised in its gauge(s), the parametric forms
        % are substituted into each unused consistency equation, and the gauge is
        % isolated from the first one that pins it. Iterated to a fixed point,
        % because one backout can unlock another open block whose consistency
        % equation references the first block's parametric chain.
        %
        % INPUTS:
        % - o              [modBuilder]
        % - blocks         [struct array]  the topologically ordered plan built so far
        % - eqasts_s       [cell]          simplified static residual ASTs, one per equation
        % - keys           [cell]          declaration keys of the equations
        % - var_idx        [dictionary]    paired-variable name -> equation row
        % - is_norm_anchor [logical]       equation i is a consistency condition of a
        %                                  user-declared normalisation anchor
        % - known_names    [cell]          names with known steady-state expressions
        % - known_asts     [cell]          the matching expression ASTs
        % - param_names    [cell]          parameter names (kept time-invariant)
        % - calib_values   [struct]        numeric shadow of the plan
        %
        % OUTPUTS:
        % - blocks         [struct array]  plan with recovered levels prepended to the
        %                                  affected blocks' closed forms and .backout set
            cons_idx = find(is_norm_anchor(:)');
            cons_used = false(size(cons_idx));
            progress = true;
            while progress
                progress = false;
                % Emitted closed forms and still-open variables, for reachability.
                cf_names = {}; cf_exprs = {}; open_names = {};
                for kb = 1:numel(blocks)
                    solved = {};
                    if ~isempty(blocks(kb).closed_form), solved = {blocks(kb).closed_form.var}; end
                    for jj = 1:numel(blocks(kb).closed_form)
                        cf_names{end+1} = blocks(kb).closed_form(jj).var; %#ok<AGROW>
                        cf_exprs{end+1} = blocks(kb).closed_form(jj).expr; %#ok<AGROW>
                    end
                    if ~strcmp(blocks(kb).kind, 'anchor')
                        op = setdiff(blocks(kb).vars, solved);
                        open_names = [open_names, op(:)']; %#ok<AGROW>
                    end
                end
                syms_cf = cell(1, numel(cf_names));
                for jj = 1:numel(cf_names)
                    syms_cf{jj} = ast(cf_exprs{jj}).staticise().symbol_names();
                end
                for kb = 1:numel(blocks)
                    if ~strcmp(blocks(kb).kind, 'simultaneous'), continue, end
                    solved = {};
                    if ~isempty(blocks(kb).closed_form), solved = {blocks(kb).closed_form.var}; end
                    open_vars = setdiff(blocks(kb).vars, solved);
                    if isempty(open_vars), continue, end
                    if numel(open_vars) >= 2
                        % Several open variables: the block carries several
                        % independent scales (a multi-gauge structure). Close the
                        % gauges sequentially: each unused consistency equation --
                        % or leftover block equation -- reduced to the open gauges
                        % (chains, earlier gauge forms and known values substituted)
                        % pins one gauge, possibly parametrically in the others; a
                        % block equation already consumed by the elimination chains
                        % reduces to 0 = 0 and drops out. Loop until every gauge is
                        % closed, then order the gauge assignments topologically.
                        if numel(solved) ~= numel(blocks(kb).vars) - numel(open_vars), continue, end
                        mate_names = solved;
                        mate_exprs = cell(size(solved));
                        for jj = 1:numel(blocks(kb).closed_form)
                            mate_exprs{strcmp(mate_names, blocks(kb).closed_form(jj).var)} = blocks(kb).closed_form(jj).expr;
                        end
                        other_open = setdiff(open_names, open_vars);
                        reach_g = modBuilder.reach_closure(open_vars, cf_names, syms_cf);
                        reach_op = modBuilder.reach_closure(other_open, cf_names, syms_cf);
                        inline_names = cf_names(reach_g);
                        inline_exprs = cf_exprs(reach_g);
                        forbidden = [other_open, cf_names(reach_op)];
                        members_kb = zeros(1, numel(blocks(kb).vars));
                        for jj = 1:numel(blocks(kb).vars)
                            members_kb(jj) = var_idx(blocks(kb).vars{jj});
                        end
                        cand_rows = [cons_idx(~cons_used), members_kb];
                        cand_done = false(size(cand_rows));
                        gauges_left = open_vars;
                        gauge_names = {}; gauge_exprs = {};
                        used_cons = []; used_eq_names = {};
                        progress_g = true;
                        while progress_g && ~isempty(gauges_left)
                            progress_g = false;
                            for cc = 1:numel(cand_rows)
                                if cand_done(cc), continue, end
                                ci = cand_rows(cc);
                                r = modBuilder.substitute_known(eqasts_s{ci}, gauges_left, known_names, known_asts, param_names);
                                [r, okr] = modBuilder.inline_chains(r, forbidden, [gauge_names, mate_names, inline_names], [gauge_exprs, mate_exprs, inline_exprs], param_names);
                                if ~okr, continue, end
                                hit = gauges_left(ismember(gauges_left, r.symbol_names()));
                                if isempty(hit), continue, end
                                if ast.node_count(r) > 1024
                                    % oversized candidate: isolate probes cost minutes
                                    % here and their closed form would be unusable —
                                    % fail fast and let the re-orientation fallback
                                    % work from the compact original residuals
                                    continue
                                end
                                for gg = 1:numel(hit)
                                    gv = hit{gg};
                                    try
                                        rhs_g = r.isolate(gv);
                                    catch err
                                        modBuilder.rethrow_unless(err, {'ast:'});
                                        rhs_g = [];
                                    end
                                    if isempty(rhs_g), continue, end
                                    rhs_g = rhs_g.simplify();
                                    if ast.is_zero(rhs_g) && modBuilder.homogeneous_in(r, gauges_left, calib_values)
                                        % zero root of a homogeneous equation: the
                                        % trivial ray, not a level
                                        continue
                                    end
                                    gauge_names{end+1} = gv; %#ok<AGROW>
                                    gauge_exprs{end+1} = rhs_g.string(); %#ok<AGROW>
                                    gauges_left = gauges_left(~strcmp(gauges_left, gv));
                                    cand_done(cc) = true;
                                    if any(cons_idx == ci) && ~cons_used(cons_idx == ci)
                                        used_cons(end+1) = ci; %#ok<AGROW>
                                    end
                                    used_eq_names{end+1} = keys{ci}; %#ok<AGROW>
                                    progress_g = true;
                                    break
                                end
                            end
                        end
                        if ~isempty(gauges_left)
                            % Re-orientation fallback: the elimination chains baked
                            % a pairing (wage = f(gross wage) through the wage
                            % recursions) under which the leftover equations are
                            % not solvable for the remaining gauges, while the
                            % reverse orientation is linear (the labour FOC pins
                            % the net wage once consumption is known). Re-match and
                            % re-eliminate from the ORIGINAL block residuals,
                            % augmented with the reduced consistency equations (the
                            % level anchors) and with the gauge forms found so far
                            % substituted in.
                            unknowns2 = [gauges_left, mate_names];
                            resid2 = {};
                            for jj = 1:numel(members_kb)
                                rj = modBuilder.static_residual(o, members_kb(jj));
                                if isempty(rj), resid2 = {}; break, end
                                rj = modBuilder.substitute_known(rj, unknowns2, known_names, known_asts, param_names);
                                for gg2 = 1:numel(gauge_names)
                                    rj = rj.substitute(gauge_names{gg2}, ast(gauge_exprs{gg2}).staticise(), param_names);
                                end
                                resid2{end+1} = rj.simplify(); %#ok<AGROW>
                            end
                            if isempty(resid2), continue, end
                            keep2 = ~ismember(inline_names, mate_names);
                            cons2 = {}; cons2_src = [];
                            for cc = 1:numel(cand_rows)
                                if cand_done(cc) || ~any(cons_idx == cand_rows(cc)), continue, end
                                ci = cand_rows(cc);
                                r = modBuilder.substitute_known(eqasts_s{ci}, unknowns2, known_names, known_asts, param_names);
                                [r, okr] = modBuilder.inline_chains(r, forbidden, [gauge_names, inline_names(keep2)], [gauge_exprs, inline_exprs(keep2)], param_names);
                                if okr && any(ismember(r.symbol_names(), unknowns2))
                                    cons2{end+1} = r; %#ok<AGROW>
                                    cons2_src(end+1) = ci; %#ok<AGROW>
                                end
                            end
                            all_res = [resid2, cons2];
                            try
                                [elim_cf, closed_all] = modBuilder.rematch_eliminate(all_res, unknowns2, param_names);
                            catch err
                                modBuilder.rethrow_unless(err, {'ast:'});
                                elim_cf = struct('var', {}, 'expr', {}); closed_all = false;
                            end
                            if ~closed_all, continue, end
                            new_cf = elim_cf;
                            for gg2 = 1:numel(gauge_names)
                                new_cf(end+1).var = gauge_names{gg2}; %#ok<AGROW>
                                new_cf(end).expr = gauge_exprs{gg2};
                            end
                            blocks(kb).closed_form = new_cf;
                            % the consistency equations handed to the fallback are
                            % consumed (an unused one is satisfied identically once
                            % the block closes, so over-marking is harmless)
                            for cc2 = 1:numel(cons2_src)
                                used_eq_names{end+1} = keys{cons2_src(cc2)}; %#ok<AGROW>
                                cons_used(cons_idx == cons2_src(cc2)) = true;
                            end
                            blocks(kb).backout = struct('gauge', {open_vars}, 'eq', {used_eq_names});
                            for ci = used_cons
                                cons_used(cons_idx == ci) = true;
                            end
                            progress = true;
                            break
                        end
                        % order the gauge assignments so a parametric one follows
                        % the gauges it references
                        remaining_g = 1:numel(gauge_names);
                        order_g = [];
                        while ~isempty(remaining_g)
                            placed_any = false;
                            for ii = remaining_g
                                refs = ast(gauge_exprs{ii}).staticise().symbol_names();
                                others_gn = gauge_names(remaining_g(remaining_g ~= ii));
                                if ~any(ismember(refs, others_gn))
                                    order_g(end+1) = ii; %#ok<AGROW>
                                    remaining_g = remaining_g(remaining_g ~= ii);
                                    placed_any = true;
                                    break
                                end
                            end
                            if ~placed_any, break, end
                        end
                        if numel(order_g) ~= numel(gauge_names), continue, end
                        gcf = struct('var', {}, 'expr', {});
                        for ii = order_g
                            gcf(end+1).var = gauge_names{ii}; %#ok<AGROW>
                            gcf(end).expr = gauge_exprs{ii};
                        end
                        blocks(kb).closed_form = [gcf, blocks(kb).closed_form];
                        blocks(kb).backout = struct('gauge', {gauge_names}, 'eq', {used_eq_names});
                        for ci = used_cons
                            cons_used(cons_idx == ci) = true;
                        end
                        progress = true;
                        break
                    end
                    g = open_vars{1};
                    vars_block = blocks(kb).vars;
                    % Rebuild the block residuals for the ratio parametrisation.
                    residuals = cell(1, numel(vars_block)); okres = true;
                    for jj = 1:numel(vars_block)
                        rj = modBuilder.static_residual(o, var_idx(vars_block{jj}));
                        if isempty(rj), okres = false; break, end
                        residuals{jj} = modBuilder.substitute_known(rj, vars_block, known_names, known_asts, param_names);
                    end
                    if ~okres, continue, end
                    try
                        cf_ratio = modBuilder.ratio_parametrise(residuals, vars_block, param_names, g, calib_values);
                    catch err
                        modBuilder.rethrow_unless(err, {'ast:'});
                        cf_ratio = struct('var', {}, 'expr', {});
                    end
                    used_ratio = numel(cf_ratio) == numel(vars_block) - 1;
                    if used_ratio
                        mate_names = {cf_ratio.var}; mate_exprs = {cf_ratio.expr};
                    elseif numel(solved) == numel(vars_block) - 1
                        % fall back on the elimination chains already emitted
                        mate_names = solved;
                        mate_exprs = cell(size(solved));
                        for jj = 1:numel(blocks(kb).closed_form)
                            mate_exprs{strcmp(mate_names, blocks(kb).closed_form(jj).var)} = blocks(kb).closed_form(jj).expr;
                        end
                    else
                        continue
                    end
                    % Reachability over the emitted closed forms: a variable whose
                    % expression transitively references the gauge must be inlined
                    % (referencing it by name from the gauge expression would create
                    % a cycle); one that reaches ANOTHER open variable defers this
                    % backout to a later round.
                    other_open = setdiff(open_names, {g});
                    reach_g = modBuilder.reach_closure({g}, cf_names, syms_cf);
                    reach_op = modBuilder.reach_closure(other_open, cf_names, syms_cf);
                    inline_names = cf_names(reach_g);
                    inline_exprs = cf_exprs(reach_g);
                    forbidden = [other_open, cf_names(reach_op)];
                    for cpos = 1:numel(cons_idx)
                        if cons_used(cpos), continue, end
                        ci = cons_idx(cpos);
                        r = modBuilder.substitute_known(eqasts_s{ci}, {g}, known_names, known_asts, param_names);
                        if ~any(ismember(r.symbol_names(), [inline_names, mate_names, {g}])), continue, end
                        [r, ok] = modBuilder.inline_chains(r, forbidden, [mate_names, inline_names], [mate_exprs, inline_exprs], param_names);
                        if ~ok || ~ismember(g, r.symbol_names()), continue, end
                        if ast.node_count(r) > 1024
                            % oversized candidate: no recogniser reads anything off
                            % it and the probe alone costs minutes
                            continue
                        end
                        try
                            rhs_g = r.isolate(g);
                        catch err
                            modBuilder.rethrow_unless(err, {'ast:'});
                            rhs_g = [];
                        end
                        if isempty(rhs_g), continue, end
                        rhs_g = rhs_g.simplify();
                        if ast.is_zero(rhs_g) && modBuilder.homogeneous_in(r, {g}, calib_values)
                            % zero root of a homogeneous equation: the trivial ray
                            continue
                        end
                        gauge_cf = struct('var', g, 'expr', rhs_g.string());
                        if used_ratio
                            blocks(kb).closed_form = [gauge_cf, cf_ratio];
                        else
                            blocks(kb).closed_form = [gauge_cf, blocks(kb).closed_form];
                        end
                        blocks(kb).backout = struct('gauge', g, 'eq', keys{ci});
                        cons_used(cpos) = true;
                        progress = true;
                        break
                    end
                    if progress, break, end
                end
            end
        end % function

        function [var_names, keys, eqasts_s, calibrated_endos, is_anchor, is_norm_anchor, forced_pair] = plan_pairing(o, match, anchor_vars)
        % Equation<->variable pairing for steady_plan. Default: equation i is pinned
        % to its declaration key; calibration role swaps re-pair the anchor equation
        % of each calibrated endogenous to its swapped parameter. With match=true,
        % the pairing comes from bipartite matching on the simplified static
        % residuals (eqasts_s, reused for the dependency graph), exogenous driving
        % processes and user anchors (anchor_vars) excluded (see steady_plan REMARKS).
        %
        % OUTPUTS:
        % - var_names        [cell]     paired variable name per equation row
        % - keys             [cell]     declaration keys of the equations
        % - eqasts_s         [cell]     simplified static residual ASTs (match=true only)
        % - calibrated_endos [cell]     endogenous fixed by calibration swaps
        % - is_anchor        [logical]  equation belongs to an anchor block
        % - is_norm_anchor   [logical]  equation is a normalisation-anchor consistency condition
        % - forced_pair      [logical]  matcher force-paired the equation (endogenous unit root)
            n = size(o.equations, 1);
            keys = o.equations(:, modBuilder.EQ_COL_NAME);
            eqasts_s = {};
            calibrated_endos = {};
            is_anchor = false(n, 1);
            % is_norm_anchor(i): equation i is a consistency condition rendered
            % redundant by a user-declared normalisation anchor (Anchors), and its
            % paired variable is that anchor (a source with a user-supplied value).
            % Distinguished from exogenous anchors so no closed form is derived from
            % the now-redundant equation.
            is_norm_anchor = false(n, 1);
            % forced_pair(i): the bipartite matcher left equation i unmatched and the
            % completion pass force-paired it to a variable it does not pin -- the
            % endogenous unit-root signature, reported once at the pairing (the
            % singleton close skips its own unit-root warning for these blocks).
            forced_pair = false(n, 1);
            if match
                eqasts_s = cell(n, 1);
                eqlhs_s = cell(n, 1);
                rawsyms = cell(n, 1);
                for i = 1:n
                    parts = strsplit(o.equations{i, modBuilder.EQ_COL_EXPR}, '=');
                    if numel(parts) == 2
                        resstr = sprintf('(%s) - (%s)', strtrim(parts{1}), strtrim(parts{2}));
                        eqlhs_s{i} = ast(strtrim(parts{1})).symbol_names();
                    else
                        resstr = strtrim(parts{1});
                        eqlhs_s{i} = ast(resstr).symbol_names();
                    end
                    raw = ast(resstr);
                    rawsyms{i} = raw.symbol_names();
                    eqasts_s{i} = raw.staticise().simplify();
                end
                % Structurally identify economically exogenous variables (AR/ARMA/VAR
                % driving processes): a variable belongs to an exogenous block iff its
                % equation references, among endogenous symbols, only variables of that
                % same block (its own lags for an AR/ARMA, the block members for a VAR),
                % and the block is driven by at least one exogenous innovation. Such a
                % block is a sink of the declaration-paired dependency graph -- nothing in
                % the rest of the model determines it -- so its variables are free anchors
                % for the steady-state matching, excluded from it so the matcher cannot
                % steal a shock variable to pin a real equation.
                is_anchor = modBuilder.exogenous_processes(keys, rawsyms, @(nm) o.isexogenous(nm));

                % User-declared normalisation anchors: endogenous variables whose
                % steady-state level is fixed by the user (a scale normalisation).
                % They are removed from the matching candidates; fixing K of them
                % leaves the (square) real system over-determined by K, so the matcher
                % leaves K equations unmatched -- the consistency conditions. Each such
                % equation is paired to an anchor (marked anchor: a source) so the
                % downstream graph stays a bijection.
                for a = 1:numel(anchor_vars)
                    nm = anchor_vars{a};
                    ai = find(strcmp(keys, nm), 1);
                    if isempty(ai) || ~o.isendogenous(nm)
                        error('modBuilder:steady_plan:badAnchor', ...
                              'Anchor "%s" is not an endogenous variable of the model.', nm);
                    end
                    if is_anchor(ai)
                        error('modBuilder:steady_plan:redundantAnchor', ...
                              ['Anchor "%s" is already an auto-detected exogenous process; ' ...
                               'it need not be declared.'], nm);
                    end
                end

                % Calibration swaps: each fixes an endogenous (a known constant,
                % removed from the candidates) and frees its paired parameter (an
                % unknown added to the candidates). A swap is count-neutral (-1 endo,
                % +1 param), so the matcher stays square; it assigns the freed
                % parameter to whichever equation it settles.
                freed_params = {};
                if ~isempty(o.calibration_swaps)
                    calibrated_endos = o.calibration_swaps(:, 1)';
                    freed_params = o.calibration_swaps(:, 3)';
                end

                real_idx = find(~is_anchor);
                var_names = keys;   % anchor equations keep their own (anchor) variable
                if ~isempty(real_idx)
                    cand = keys(real_idx);
                    drop = [anchor_vars, calibrated_endos];
                    if ~isempty(drop)
                        cand = cand(~ismember(cand, drop));
                    end
                    if ~isempty(freed_params)
                        cand = [cand; freed_params(:)];
                    end
                    [eq2var_r, ~, umvars_r] = ...
                        modBuilder.matchequations(eqasts_s(real_idx), eqlhs_s(real_idx), cand);
                    % Complete the matching. First fill genuinely deficient equations
                    % (a variable cancels out of every residual) from leftover
                    % candidates; then absorb the anchor-induced surplus: each still
                    % unmatched equation is a consistency condition, paired to a
                    % remaining anchor variable (a source), else fall back to any
                    % leftover candidate / the declaration key.
                    remaining = umvars_r(:);
                    anchor_queue = anchor_vars(:);
                    for t = 1:numel(real_idx)
                        i = real_idx(t);
                        v = eq2var_r{t};
                        if isempty(v)
                            forced = false;
                            pos = find(strcmp(keys{i}, remaining), 1);
                            if isempty(pos)
                                pos = find(ismember(remaining, eqasts_s{i}.symbol_names()), 1);
                            end
                            if ~isempty(pos)
                                v = remaining{pos};
                                remaining(pos) = [];
                                forced = true;
                            elseif ~isempty(anchor_queue)
                                v = anchor_queue{1};
                                anchor_queue(1) = [];
                                is_anchor(i) = true;
                                is_norm_anchor(i) = true;
                            elseif ~isempty(remaining)
                                v = remaining{1};
                                remaining(1) = [];
                                forced = true;
                            else
                                v = keys{i};
                                forced = true;
                            end
                            % A forced pairing that the equation cannot honour is the
                            % endogenous unit-root signature: the matcher found no
                            % admissible variable for this equation (every candidate is
                            % absent or factors out of the static residual, as c does in
                            % the Euler condition once beta*R = 1), so some level is left
                            % undetermined and the pairing exists only to keep the plan
                            % square. Warn here, where the reduced residual is available.
                            if forced
                                [has, cancels] = eqasts_s{i}.check_factor(v);
                                if ~has || cancels
                                    forced_pair(i) = true;
                                    modBuilder.warn_silent('modBuilder:steady_plan:endogenousUnitRoot', 'Equation "%s" pins none of the remaining variables at the steady state (its static residual reduces to %s = 0), leaving the level of %s undetermined -- an endogenous unit root (e.g. incomplete-markets open economy). Close the model or fix the level of %s (declared steady-state value or anchor).', keys{i}, eqasts_s{i}.string(), v, v);
                                end
                            end
                        end
                        var_names{i} = v;
                    end
                end
            else
                var_names = o.equations(:, modBuilder.EQ_COL_NAME);
                if ~isempty(o.calibration_swaps)
                    calibrated_endos = o.calibration_swaps(:, 1)';
                    for s = 1:size(o.calibration_swaps, 1)
                        endo = o.calibration_swaps{s, 1};
                        param = o.calibration_swaps{s, 3};
                        eq_idx = find(strcmp(endo, var_names));
                        if isempty(eq_idx)
                            error('modBuilder:steady_plan:unpairedCalibration', ...
                                  'Calibrated endogenous "%s" is not paired with any equation.', endo);
                        end
                        if ~ismember(param, o.T.equations.(endo))
                            error('modBuilder:steady_plan:nonLocalSwap', ...
                                  ['Parameter "%s" does not appear in the equation paired with "%s"; ' ...
                                   'a non-local role swap would require re-running matchequations on the ' ...
                                   'swapped unknown set, which is not currently supported.'], param, endo);
                        end
                        var_names{eq_idx} = param;
                    end
                end
            end
        end % function

        function [endo_deps, ext_deps] = plan_dependencies(o, match, var_names, var_idx, eqasts_s, is_anchor, is_norm_anchor, calibrated_endos)
        % Collect the symbol names referenced by each equation (via AST) and partition
        % into endogenous deps vs external constants (parameters / exogenous /
        % calibrated endos). LHS-as-bare-paired-variable (the standard "y = expr"
        % form) does not count as a self-reference: the LHS occurrence is the
        % equation's pairing target, not a use.
            n = numel(var_names);
            endo_deps = cell(n, 1);
            ext_deps = cell(n, 1);
            for i = 1:n
                eqname_i = var_names{i};
                if match
                    if is_anchor(i) && ~is_norm_anchor(i)
                        % A process anchor is self-contained only when univariate: a
                        % member of a VAR process depends on its siblings, and cutting
                        % those edges would split the process SCC into singletons whose
                        % closed forms reference each other out of evaluation order,
                        % hiding the joint static system (I-K)x = c from the Bareiss
                        % determinant probe (det(I-K) = 0 at the calibration is a
                        % unit-root process). Keep dependencies on other process
                        % anchors: a sink block references no endogenous outside
                        % itself, so this reconstructs exactly the process SCC and
                        % leaves univariate anchors as pure sources.
                        cand = eqasts_s{i}.symbol_names();
                        cand = cand(~strcmp(cand, eqname_i));
                        names = {};
                        for kk = 1:numel(cand)
                            nm_kk = cand{kk};
                            if isKey(var_idx, nm_kk) && is_anchor(var_idx(nm_kk)) && ~is_norm_anchor(var_idx(nm_kk))
                                [has_kk, canc_kk] = eqasts_s{i}.check_factor(nm_kk);
                                if has_kk && ~canc_kk
                                    names{end+1} = nm_kk; %#ok<AGROW>
                                end
                            end
                        end
                    elseif is_anchor(i)
                        % A norm-anchor consistency equation stays a pure source: its
                        % anchor value is user-supplied and the equation pins nothing.
                        names = {};
                    else
                        % Dependencies from the simplified static residual; the paired
                        % (target) variable is not a dependency of its own equation. Keep
                        % only symbols that genuinely determine the steady state through
                        % this equation -- they appear AND do not cancel as a common factor
                        % -- matching the admission rule used by matchequations. This drops
                        % spurious edges from variables that cancel at the steady state
                        % (e.g. consumption in an Euler equation c = beta*R*c(+1)).
                        cand = eqasts_s{i}.symbol_names();
                        cand = cand(~strcmp(cand, eqname_i));
                        names = {};
                        for kk = 1:numel(cand)
                            [has_kk, canc_kk] = eqasts_s{i}.check_factor(cand{kk});
                            if has_kk && ~canc_kk
                                names{end+1} = cand{kk}; %#ok<AGROW>
                            end
                        end
                    end
                else
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
                end
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
        end % function

        function [bins, ord] = plan_scc_order(endo_deps, var_idx, n)
        % Strongly connected components of the dependency graph induced by endo_deps
        % and their topological ordering: bins(i) is the SCC of equation i, ord the
        % SCC evaluation order.
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
        end % function

        function [param_names, calib_values, endo_names_all, known_names, known_asts] = plan_known_values(o, propagate)
        % Assemble the known-value environment for the block closures: the parameter
        % name list, the numeric shadow of the calibration (calib_values, used by the
        % homogeneity / determinant / knife-edge probes), the endogenous name roster,
        % and -- when propagate is set -- the known steady-state expressions
        % (user-declared values and calibrated exogenous levels) to inline into the
        % residuals before the recognisers run.
            param_names = {};
            if ~isempty(o.params), param_names = o.params(:, modBuilder.COL_NAME)'; end
            % Numeric shadow of the plan: the calibrated point (parameters and
            % exogenous levels), extended below with each closed block's evaluated
            % forms as the topological sweep advances. Used to evaluate numeric
            % exponents in the block homogeneity test (block_scale_freedom), the
            % scale-ray determinant probe, and the knife-edge checks (a pinning
            % coefficient or block determinant that is symbolically non-zero but
            % vanishes at the calibrated point -- a unit root at this calibration).
            calib_values = struct();
            for i = 1:size(o.params, 1)
                val = o.params{i, modBuilder.COL_VALUE};
                if isnumeric(val) && isscalar(val) && isfinite(val)
                    calib_values.(o.params{i, modBuilder.COL_NAME}) = val;
                end
            end
            for i = 1:size(o.varexo, 1)
                val = o.varexo{i, modBuilder.COL_VALUE};
                if isnumeric(val) && isscalar(val) && isfinite(val)
                    calib_values.(o.varexo{i, modBuilder.COL_NAME}) = val;
                end
            end
            endo_names_all = o.var(:, modBuilder.COL_NAME)';
            known_names = {}; known_asts = {};
            if propagate && ~isempty(o.steady_state)
                for i = 1:size(o.steady_state, 1)
                    known_names{end+1} = o.steady_state{i, modBuilder.SS_COL_NAME}; %#ok<AGROW>
                    known_asts{end+1} = ast(o.steady_state{i, modBuilder.SS_COL_EXPR}).staticise(); %#ok<AGROW>
                end
            end
            if propagate && ~isempty(o.varexo)
                % Exogenous variables sit at their calibrated values in the steady
                % state (innovations at 0): inlining them folds the shock-anchor
                % closed forms to leaves (exp(0*sigma) -> 1), which unlocks the
                % alias chain (InflationFactor = InflationTarget = target parameter)
                % that collapses the indexation powers downstream.
                for i = 1:size(o.varexo, 1)
                    v = o.varexo{i, modBuilder.COL_VALUE};
                    if isnumeric(v) && isscalar(v) && isfinite(v)
                        known_names{end+1} = o.varexo{i, modBuilder.COL_NAME}; %#ok<AGROW>
                        known_asts{end+1} = ast('num', v, {}); %#ok<AGROW>
                    end
                end
            end
        end % function

        function cf = close_singleton(o, eq_idx, vars_block, known_names, known_asts, param_names, calib_values, forced)
        % Closed-form isolation for a singleton block: ast.isolate on the static
        % residual (linear / monomial / invertible-call recognisers), with the
        % knife-edge probe on success and the unit-root diagnostics on failure.
        % forced marks a force-paired equation (the pairing already warned, so the
        % singleton unit-root warning is skipped).
            cf = struct('var', {}, 'expr', {});
            f = modBuilder.static_residual(o, eq_idx);
            f = modBuilder.substitute_known(f, vars_block, known_names, known_asts, param_names);
            if ~isempty(f)
                [rhs_tree, iso] = f.isolate(vars_block{1});
                if ~isempty(rhs_tree)
                    cf(1).var = vars_block{1};
                    cf(1).expr = rhs_tree.string();
                    modBuilder.check_knife_edge(iso.coefs, calib_values, o.equations{eq_idx, modBuilder.EQ_COL_NAME}, vars_block{1});
                else
                    % Unit-root diagnostic: either the invertible-call recogniser
                    % saw the coefficients on f(x) sum to zero, or the variable
                    % cancelled outright between its own occurrences when the
                    % residual was simplified (the rho = 1 literal, e.g.
                    % log(Z) - log(Z(-1)) folding to 0). Both mean the equation
                    % pins the growth rate and leaves the level undetermined.
                    vname = vars_block{1};
                    cancelled = ast.count_occurrences(f, vname) > 0 && ast.count_occurrences(f.canonicalise().simplify(), vname) == 0;
                    if (iso.unit_root || cancelled) && ~forced
                        modBuilder.warn_silent('modBuilder:steady_plan:unitRoot', 'Equation "%s" has a unit root in %s: its coefficients cancel in the static residual, so the equation pins the growth rate of %s, not its level. The steady-state level of %s is yours to fix (declare a steady-state value or pass it as an anchor).', o.equations{eq_idx, modBuilder.EQ_COL_NAME}, vname, vname, vname);
                    end
                end
            end
        end % function

        function [cf, reduced_info] = close_simultaneous(o, members, vars_block, known_names, known_asts, param_names, calib_values)
        % Closed-form closure of a simultaneous block: scale-freedom routing, joint
        % linearisation + Bareiss back-substitution, iterated symbolic elimination,
        % and the ratio change of variables as last resort (see the inline comments).
        % The caller gates the block size (options.MaxBlockSize); Bareiss keeps its
        % own cap of 8 inside. reduced_info carries the reduced square system of a
        % stalled elimination (empty .vars otherwise).
            cf = struct('var', {}, 'expr', {});
            reduced_info = struct('vars', {{}}, 'residuals', {{}});
            % The default cap trades closure ambition against the cost of
            % symbolic elimination, which grows quickly with block size; raise
            % MaxBlockSize to attempt larger cores (a 13-variable block takes
            % minutes). Bareiss keeps its own cap of 8 below: its O(n^3)
            % polynomial fill-in is prohibitive beyond that, and the generated
            % assignments would be unreadable anyway.
            residuals = cell(1, numel(members));
            for jj = 1:numel(members)
                rj = modBuilder.static_residual(o, members(jj));
                residuals{jj} = modBuilder.substitute_known(rj, vars_block, known_names, known_asts, param_names);
            end
            if all(~cellfun(@isempty, residuals))
              try
                % A block that is HOMOGENEOUS in its variables never goes
                % through plain linear solving or elimination: its solution set
                % is a scale ray through zero, and both paths would "close" it
                % on the trivial all-zero point (the rational normalisation in
                % linearise_system makes ratio equations like z1/z2 = p
                % recognisably linear, so the Cramer path WOULD fire). Decide
                % scale freedom up front and route accordingly.
                scale_free = modBuilder.block_scale_freedom(residuals, vars_block, calib_values);
                % First attempt: jointly linear → Bareiss + back-substitution.
                ok_lin = false;
                if numel(members) <= 8
                    [ok_lin, A_mat, b_vec] = ast.linearise_system(residuals, vars_block);
                end
                if ok_lin && scale_free
                    % Homogeneous AND jointly linear: a scale ray exists only if
                    % the system matrix is singular. When the determinant
                    % evaluates to a non-zero number at the calibration, the
                    % all-zero point is the UNIQUE solution — the steady state
                    % of a zero-mean VAR block — so the linear path is correct.
                    % A vanishing or non-evaluable determinant (it references an
                    % anchored variable with no declared value, or the block is
                    % genuinely scale-free) keeps the gauge machinery in charge.
                    regular = false;
                    try
                        dv = ast.symbolic_det(A_mat).eval(calib_values);
                        regular = isfinite(dv) && abs(dv) > 1e-9;
                    catch err
                        modBuilder.rethrow_unless(err, {'ast:'});
                    end
                    if regular
                        scale_free = false;
                    else
                        ok_lin = false;
                    end
                end
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
                        % Knife-edge check: bareiss_triangulate only rules out
                        % SYMBOLIC singularity; a determinant vanishing at the
                        % calibrated point slips through and the back-substituted
                        % forms divide by a numerical zero. Tolerance relative to
                        % the entry magnitudes (Hadamard-style bound); skipped
                        % when an entry references an unavailable value, since
                        % that path fails loudly at evaluation time anyway.
                        try
                            dv = ast.symbolic_det(A_mat).eval(calib_values);
                            ma = 0;
                            for rr = 1:n_var
                                for cc = 1:n_var
                                    ma = max(ma, abs(A_mat{rr, cc}.eval(calib_values)));
                                end
                            end
                            if isnumeric(dv) && isscalar(dv) && isfinite(dv) && isreal(dv) && abs(dv) <= 1e-9 * max(1, ma^n_var)
                                modBuilder.warn_silent('modBuilder:steady_plan:calibrationUnitRoot', 'The block {%s} is singular at the calibration: its determinant evaluates to %.3g, so the levels are jointly undetermined -- a unit root at this calibration. Fix one level or move the calibration off the knife edge.', strjoin(vars_block, ', '), dv);
                            end
                        catch err
                            modBuilder.rethrow_unless(err, {'ast:'});
                        end
                    end
                end
                % Fallback: iterated symbolic elimination via the per-equation
                % recognisers. Substitution between equations may turn a
                % non-linear residual into a linear / monomial / call-wrapped
                % one that the recognisers then handle. A scale-free block is
                % parametrised in a gauge instead (ratios in closed form, level
                % left open for the gauge backout below or for the user).
                if isempty(cf)
                    if scale_free
                        for gi = 1:numel(vars_block)
                            cf_gauge = modBuilder.ratio_parametrise(residuals, vars_block, param_names, vars_block{gi}, calib_values);
                            if numel(cf_gauge) == numel(vars_block) - 1
                                cf = cf_gauge;
                                break
                            end
                        end
                    else
                        % reject_zero: the block-level homogeneity test above
                        % only sees a JOINT scale freedom, but a block can hide
                        % a scale-free subsystem (the SW price-recursion chain
                        % inside the consumption/wage core). Elimination then
                        % consumes the ratios and reduces the level equation to
                        % v·c = 0, whose zero root is the trivial ray. A block
                        % reaching this path is never jointly linear (Bareiss
                        % ran first), so a zero level here is the artefact, and
                        % rejecting it leaves the variable open for the gauge
                        % backout instead of poisoning the chain.
                        [elim_cf, elim_rem] = ast.iterated_elimination(residuals, vars_block, param_names, true);
                        for jj = 1:numel(elim_cf)
                            cf(end+1).var = elim_cf(jj).var; %#ok<AGROW>
                            cf(end).expr = elim_cf(jj).expr.string();
                        end
                        % A stalled elimination still shrinks the numerical
                        % problem: record the reduced square system (open
                        % variables + substituted residuals) so the helper
                        % generation solves 4 unknowns instead of 10, with the
                        % closed forms becoming the conditional epilogue.
                        if ~isempty(elim_cf) && ~isempty(elim_rem.vars)
                            reduced_info.vars = elim_rem.vars;
                            reduced_info.residuals = cellfun(@(t) t.string(), elim_rem.residuals, 'UniformOutput', false);
                        end
                    end
                end
                % Last resort for a block single-variable elimination leaves
                % (fully or partly) open: a ratio change of variables closes a
                % block that is homogeneous in its variables (elimination sees it
                % as an irreducible cycle). Keep whichever result closes more.
                if numel(cf) < numel(vars_block)
                    cf_ratio = modBuilder.ratio_reduce(residuals, vars_block, param_names);
                    if numel(cf_ratio) > numel(cf)
                        cf = cf_ratio;
                    end
                end
              catch err
                % A block whose closed form cannot be derived (e.g. an AST shape
                % the linear / elimination recognisers do not support) stays
                % reported as simultaneous with no closed form, for a numerical solve.
                modBuilder.rethrow_unless(err, {'ast:'});
                cf = struct('var', {}, 'expr', {});
              end
            end
        end % function

        function f = substitute_known(f, blockvars, known_names, known_asts, param_names)
        % Inline the known steady-state values (known_names -> known_asts) into the
        % residual f, then simplify. Variables of the current block (blockvars) are
        % never substituted -- they are the unknowns being solved for. Several passes
        % resolve chains where one known value references another. Used by steady_plan's
        % PropagateKnown option to collapse steady-state-constant factors before the
        % closed-form recognisers run.
            if isempty(f) || isempty(known_names)
                return
            end
            % Only inline LEAF values (a number or a single symbol): a normalisation = 1
            % or = 0, a shock = 1, or a symbol alias (InflationFactor = InflationTarget).
            % These collapse steady-state-constant factors (x/1 -> x, (a/a)^E -> 1,
            % log(1) -> 0) without bloating the residual, which inlining a compound
            % expression (a full rental-rate formula) would do and defeat the recognisers.
            for pass = 1:3
                for i = 1:numel(known_names)
                    if ismember(known_names{i}, blockvars)
                        continue
                    end
                    if ~any(strcmp(known_asts{i}.type, {'num','sym','tsym','ss'}))
                        continue
                    end
                    f = f.substitute(known_names{i}, known_asts{i}, param_names);
                end
                f = f.simplify();
            end
        end % function

        function f = dynamic_residual(o, eq_idx)
        % Build the dynamic (NON-staticised) residual AST for the equation at row eq_idx of
        % o.equations: "LHS - RHS" (or "LHS" if there is no '=' symbol), with all leads/lags
        % preserved. Empty if the equation cannot be parsed. The dynamic counterpart of
        % static_residual; used by partial / symbolic_jacobian for period-specific derivatives.
            eq_str = o.equations{eq_idx, modBuilder.EQ_COL_EXPR};
            LHSRHS = strsplit(eq_str, '=');
            if isscalar(LHSRHS)
                f = ast(strtrim(LHSRHS{1}));
            elseif length(LHSRHS) == 2
                f = ast('binop', '-', {ast(strtrim(LHSRHS{1})), ast(strtrim(LHSRHS{2}))});
            else
                f = [];
            end
        end % function

        function body = tex_align(blockrows, filename)
        % Assemble pre-rendered rows into a LaTeX align environment, optionally writing it to a
        % file, and return the string. Shared by the tex_* reporting methods.
        %
        % INPUTS:
        % - blockrows  [cell]   cell array of blocks; each block is a cell array of row strings
        %                       (already including the "&" alignment markers and indentation). A
        %                       flat list of rows is a single block, e.g. tex_align({rows}).
        % - filename   [char]   (optional) path to write the assembled string to.
        %
        % OUTPUTS:
        % - body       [char]   the "\begin{align} ... \end{align}" string.
        %
        % REMARKS:
        % - Rows within a block are separated by "\\"; consecutive blocks by "\\[\medskipamount]"
        %   for a little vertical space. The row break is appended by plain concatenation, NOT
        %   through strjoin, whose delimiter is escape-translated (it would collapse "\\" to "\").
            arguments
                blockrows cell
                filename (1,:) char = ''
            end
            nl = newline;
            body = ['\begin{align}' nl];
            for bi = 1:numel(blockrows)
                rows = blockrows{bi};
                for ri = 1:numel(rows)
                    body = [body rows{ri}]; %#ok<AGROW>
                    last_in_block = ri == numel(rows);
                    last_overall = bi == numel(blockrows) && last_in_block;
                    if ~last_overall
                        if last_in_block
                            body = [body ' \\[\medskipamount]']; %#ok<AGROW>
                        else
                            body = [body ' \\']; %#ok<AGROW>
                        end
                    end
                    body = [body nl]; %#ok<AGROW>
                end
            end
            body = [body '\end{align}' nl];
            if ~isempty(filename)
                fid = fopen(filename, 'w');
                if fid == -1
                    error('modBuilder:tex_align:cannotOpen', 'Cannot open file "%s" for writing.', filename);
                end
                c = onCleanup(@() fclose(fid)); %#ok<NASGU>
                fprintf(fid, '%s', body);
            end
        end % function

        function w = foc_weight(M, k, paramnames)
        % One-period weight applied to the lag-k term of a Lagrangian FOC: the relative
        % cumulative discount between the period where the control lives and the period whose
        % equation contributes. M is the marginal continuation value (the discount). For a
        % constant M = beta this is beta^(-k); the products below also cover a state-dependent
        % M (recursive preferences), with M dated to the contributing period.
            if k == 0
                w = ast('num', 1, {});
            elseif k > 0
                % 1 / ( M(-1)·M(-2)·…·M(-k) )
                w = ast('num', 1, {});
                for j = 1:k
                    mj = M.shift_lag(-j, paramnames);
                    w = ast('binop', '*', {w, ast('binop', '^', {mj, ast('num', -1, {})})});
                end
            else
                % M(0)·M(+1)·…·M(-k-1)
                w = ast('num', 1, {});
                for j = 0:(-k - 1)
                    w = ast('binop', '*', {w, M.shift_lag(j, paramnames)});
                end
            end
            w = w.simplify();
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
            % symbol_names prefilter: its reach (sym + tsym + ss) is a superset of
            % check_factor's has-reach (sym + tsym), so a candidate absent from the
            % name set cannot have has=true — n cheap walks replace n×m structural
            % check_factor probes on the pairs that cannot match.
            eqnames_set = cell(n, 1);
            for i = 1:n
                eqnames_set{i} = eqasts{i}.symbol_names();
            end
            contains_eq = false(n, m);
            for j = 1:m
                v = candidates{j};
                for i = 1:n
                    if ~any(strcmp(v, eqnames_set{i}))
                        continue
                    end
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
            C = modBuilder.MATCH_FORBID * ones(n, m);
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
            M = matchpairs(C, modBuilder.MATCH_UNMATCHED);
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
        % Deserialize a modBuilder object represented by structure s.
        %
        % INPUTS:
        % s    [struct]
        %
        % OUTPUTS:
        % - o  [modBuilder]
        %
        % REMARKS:
        % - The struct carries a 'version' schema tag (see saveobj and
        %   modBuilder.SCHEMA_VERSION). Older files written before versioning
        %   lack the tag; they are treated as version 0 and brought forward by
        %   migrate_saved_struct(). A file written by a newer modBuilder than
        %   this class understands is rejected rather than silently mis-read.

            if ~isstruct(s)
                % MATLAB hands loadobj the already-built object on a normal
                % (non-struct) load; pass it through untouched.
                o = s;
                return
            end

            % Core fields present in every schema version.
            core = {'params', 'varexo', 'var', 'symbols', 'equations', 'T', 'date'};
            if ~all(isfield(s, core))
                error('modBuilder:loadobj:invalidObject', 'Cannot instantiate a modBuilder object (missing fields).')
            end

            if isfield(s, 'version')
                v = s.version;
            else
                v = 0;   % unversioned legacy file
            end
            if v > modBuilder.SCHEMA_VERSION
                error('modBuilder:loadobj:futureVersion', ...
                      'This file uses modBuilder schema version %d, but this class only understands up to version %d. Please update modBuilder.', ...
                      v, modBuilder.SCHEMA_VERSION)
            end

            s = modBuilder.migrate_saved_struct(s, v);

            o = modBuilder(s.date);
            o.T = s.T;
            o.var = s.var;
            o.params = s.params;
            o.varexo = s.varexo;
            o.tags = s.tags;
            o.symbols = s.symbols;
            o.equations = s.equations;
            o.steady_state = s.steady_state;
            o.calibration_swaps = s.calibration_swaps;
        end % function

        function s = migrate_saved_struct(s, v)
        % Bring a saved struct from schema version v up to SCHEMA_VERSION.
        %
        % INPUTS:
        % - s   [struct]    saved struct as returned by saveobj (or an older one)
        % - v   [integer]   the struct's schema version (0 for legacy files)
        %
        % OUTPUTS:
        % - s   [struct]    struct with every current field present and the
        %                   'version' tag set to SCHEMA_VERSION
        %
        % REMARKS:
        % - One branch per legacy version, filling fields introduced later with
        %   their current defaults. Add a new branch (and bump SCHEMA_VERSION)
        %   whenever the persisted field set grows.
            if v < 1
                % Version 0 (unversioned): tags has always been present, but
                % steady_state and calibration_swaps were added incrementally
                % and may be absent. Fill any missing field with its default.
                if ~isfield(s, 'tags')
                    s.tags = struct();
                end
                if ~isfield(s, 'steady_state')
                    s.steady_state = cell(0, 2);
                end
                if ~isfield(s, 'calibration_swaps')
                    s.calibration_swaps = cell(0, 3);
                end
            end
            s.version = modBuilder.SCHEMA_VERSION;
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

        function o = addeq(o, varname, equation, require_in_equation)
        % Add an equation to the model and associate an endogenous variable (internal method)
        %
        % INPUTS:
        % - o                   [modBuilder]
        % - varname             [char]      1×n, name of an endogenous variable
        % - equation            [char]      1×m, equation expression
        % - require_in_equation [logical]   scalar, require varname to appear in equation
        %                                   (default true; augment passes false to key a FOC to a
        %                                   variable — e.g. an instrument — that need not appear in it)
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
                varname             (1,:) char {mustBeNonempty}
                equation            (1,:) char {mustBeNonempty}
                require_in_equation (1,1) logical = true
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
            if require_in_equation && ~ismember(varname, symbols_in_eq)
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

            % o.var / o.varexo were just mutated; invalidate the symbol map so the
            % issymbol cellfun below sees current state instead of a stale cached copy.
            o.symbol_map_dirty = true;

            o.T.equations.(varname) = setdiff(symbols_in_eq, varname);
            % Only the NEW equation's tokens need a type check: the accumulated pool
            % already holds untyped names only, and the sole pre-existing entry this
            % add can type is varname itself (now endogenous), removed explicitly.
            new_untyped = symbols_in_eq(~cellfun(@o.issymbol, symbols_in_eq));
            o.symbols = setdiff(unique([o.symbols, new_untyped]), {varname});
            o.tags.(varname).name = varname;

            o.mark_dirty();
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
            o = o.declare_typed('parameter', pname, varargin{:});
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
            o = o.declare_typed('exogenous', xname, varargin{:});
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

            % A variable assigned by a multi-output block call cannot also carry a
            % scalar expression; drop the call (rebuild the plan) first.
            for r = 1:size(o.steady_state, 1)
                nm = o.steady_state{r, modBuilder.SS_COL_NAME};
                if iscell(nm) && ismember(varname, nm)
                    error('modBuilder:steady:assignedByCall', 'Symbol "%s" is already assigned by the block call "[%s] = %s"; it cannot also carry a scalar steady-state expression.', varname, strjoin(nm, ', '), o.steady_state{r, modBuilder.SS_COL_EXPR});
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

        function o = steady_call(o, outnames, expression)
        % Register a multi-output call in the steady_state_model block:
        % [outnames{1}, ..., outnames{n}] = expression;
        %
        % INPUTS:
        % - o            [modBuilder]
        % - outnames     [cell]   cellstr of endogenous variable names assigned by the call
        % - expression   [char]   RHS call, e.g. 'mymodel_ssblock_2(K, alpha, s)'
        %
        % OUTPUTS:
        % - o            [modBuilder]
        %
        % REMARKS:
        % - Dynare accepts MATLAB functions returning several outputs inside a
        %   steady_state_model block; this is how apply_steady_plan hands the blocks
        %   without a symbolic closed form over to a generated numerical routine.
        % - The row is stored with a cellstr in the name column; checksteady treats it
        %   as a single node assigning all its outputs, whose dependencies are the
        %   symbols appearing in the call's argument list.
        % - Each output must be an endogenous variable not already assigned (neither by
        %   a scalar expression nor by another call).
            arguments
                o
                outnames   (1,:) cell {mustBeNonempty}
                expression (1,:) char {mustBeNonempty}
            end
            for j = 1:numel(outnames)
                nm = outnames{j};
                if ~ismember(nm, o.var(:, modBuilder.COL_NAME))
                    error('modBuilder:steady_call:notEndogenous', 'Symbol "%s" is not a known endogenous variable.', nm)
                end
                for r = 1:size(o.steady_state, 1)
                    prev = o.steady_state{r, modBuilder.SS_COL_NAME};
                    if (ischar(prev) && strcmp(prev, nm)) || (iscell(prev) && ismember(nm, prev))
                        error('modBuilder:steady_call:alreadyExists', 'Symbol "%s" already has a steady-state assignment.', nm)
                    end
                end
            end
            n = size(o.steady_state, 1);
            o.steady_state{n+1, modBuilder.SS_COL_NAME} = outnames;
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
        %   calibration swap. Errors with id 'modBuilder:calibrate:*' otherwise.
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
                error('modBuilder:calibrate:notEndogenous', '"%s" must be an endogenous variable.', endo_name);
            end
            if ~o.isparameter(param_name)
                error('modBuilder:calibrate:notParameter', '"%s" must be a parameter.', param_name);
            end
            if ~isempty(o.calibration_swaps)
                if any(strcmp(endo_name, o.calibration_swaps(:, 1)))
                    error('modBuilder:calibrate:duplicateSwap', 'Endogenous "%s" is already in a calibration swap.', endo_name);
                end
                if any(strcmp(param_name, o.calibration_swaps(:, 3)))
                    error('modBuilder:calibrate:duplicateSwap', 'Parameter "%s" is already in a calibration swap.', param_name);
                end
            end
            o.refresh_tables();
            % The freed parameter must appear in at least one equation (otherwise
            % nothing can pin it). Locality (the parameter appearing in the equation
            % paired with endo_name) is required only by the declaration-pairing path
            % and is re-checked there by steady_plan; steady_plan(Match=true) resolves
            % non-local swaps by re-running matchequations on the swapped unknown set.
            if ~isfield(o.T.params, param_name) || isempty(o.T.params.(param_name))
                error('modBuilder:calibrate:unusedParameter', ...
                      'Parameter "%s" does not appear in any equation, so it cannot be solved for.', param_name);
            end

            n = size(o.calibration_swaps, 1);
            o.calibration_swaps{n+1, 1} = endo_name;
            o.calibration_swaps{n+1, 2} = target_value;
            o.calibration_swaps{n+1, 3} = param_name;
        end % function

        function [sorted_names, sorted_rows] = checksteady(o)
        % Validate steady-state expressions and return symbol names in topological order.
        %
        % INPUTS:
        % - o              [modBuilder]
        %
        % OUTPUTS:
        % - sorted_names   [cell]      1×n cell array of symbol names in dependency order
        % - sorted_rows    [double]    row indices of o.steady_state in the same order;
        %                              a multi-output call row (added by steady_call)
        %                              appears once here while contributing all its
        %                              output names to sorted_names.
        %
        % REMARKS:
        % - For each expression, all symbols must be known (via issymbol()).
        % - Topological sort uses Kahn's algorithm.
        % - Nodes are the rows of steady_state; a row assigns one symbol (char name)
        %   or several (cellstr name, a block call registered by steady_call).
        % - Edge A → B means the expression of row B references a symbol assigned by
        %   row A. For a call row, the dependencies are the symbols of the argument
        %   list only (the leading identifier is the generated function's name, not a
        %   model symbol).
        % - Symbols with only numeric values (not nodes) are treated as leaf constants.
        % - Tie-breaking: when multiple nodes have in-degree 0, the one with the smallest
        %   row index in steady_state is picked first (preserves call order).
        % - Errors on unknown symbols, circular dependencies, or missing values.

            n = size(o.steady_state, 1);

            if n == 0
                sorted_names = {};
                sorted_rows = [];
                return
            end

            % provides{i}: cellstr of the symbols assigned by row i.
            provides = cell(1, n);
            row_label = cell(1, n);
            for i = 1:n
                nm = o.steady_state{i, modBuilder.SS_COL_NAME};
                if ischar(nm)
                    provides{i} = {nm};
                    row_label{i} = nm;
                else
                    provides{i} = nm;
                    row_label{i} = ['[' strjoin(nm, ', ') ']'];
                end
            end

            % Build adjacency and in-degree
            in_degree = zeros(1, n);
            % adj{i} = list of node indices that depend on node i (i.e. i → j)
            adj = cell(1, n);
            for i = 1:n
                adj{i} = [];
            end

            % Name -> providing-row lookup, built once. The previous per-symbol
            % find(cellfun(@(p) ismember(sym, p), provides)) rescanned every row for
            % every symbol of every expression -- quadratic in the table size.
            % find(..., 1) kept the FIRST providing row, so duplicates keep the
            % earliest row here too.
            provider_of = configureDictionary("string", "double");
            for r = 1:n
                for pp = 1:numel(provides{r})
                    nm_p = string(provides{r}{pp});
                    if ~isKey(provider_of, nm_p)
                        provider_of(nm_p) = r;
                    end
                end
            end

            for i = 1:n
                expr = o.steady_state{i, modBuilder.SS_COL_EXPR};
                if ~ischar(o.steady_state{i, modBuilder.SS_COL_NAME})
                    % Call row: dependencies live in the argument list; the leading
                    % identifier is the helper function's name, not a model symbol.
                    op = find(expr == '(', 1);
                    cl = find(expr == ')', 1, 'last');
                    if isempty(op) || isempty(cl) || cl < op
                        error('modBuilder:checksteady:badCall', 'Malformed block call "%s" for %s.', expr, row_label{i})
                    end
                    expr = expr(op+1:cl-1);
                end
                syms_in_expr = modBuilder.getsymbols(expr);
                for j = 1:numel(syms_in_expr)
                    sym = syms_in_expr{j};
                    % If sym is itself assigned by a row of the steady-state table (a
                    % model variable with a steady-state expression, an auxiliary
                    % intermediate added by steady_aux, or an output of a block call),
                    % record the dependency edge. Otherwise it must be a declared model
                    % symbol — error if it isn't.
                    if isKey(provider_of, sym)
                        node_idx = provider_of(sym);
                        % Edge: node_idx → i (sym must be computed before node i);
                        % a self-reference builds the loop edge i → i and surfaces
                        % as a circular-dependency error below, as before.
                        adj{node_idx}(end+1) = i;
                        in_degree(i) = in_degree(i) + 1;
                    elseif ~o.issymbol(sym)
                        error('modBuilder:checksteady:unknownSymbol', 'Unknown symbol "%s" in steady-state expression for "%s".', sym, row_label{i})
                    end
                end
            end

            % Kahn's algorithm with stable tie-breaking (smallest row index first)
            sorted_names = {};
            sorted_rows = zeros(1, n);

            for iter = 1:n
                % Find all nodes with in-degree 0
                candidates = find(in_degree == 0);
                if isempty(candidates)
                    % Remaining nodes form a cycle
                    remaining = row_label(in_degree > 0);
                    error('modBuilder:checksteady:circularDep', 'Circular dependency detected among steady-state expressions: %s.', strjoin(remaining, ', '))
                end
                % Tie-breaking: pick the candidate with smallest original row index
                chosen = candidates(1);
                sorted_rows(iter) = chosen;
                sorted_names = [sorted_names, provides{chosen}]; %#ok<AGROW>
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

                    % The deletion shifted the row indices after id: invalidate the
                    % map so the next lookup rebuilds it from the current arrays.
                    % Iterations that delete nothing keep the map valid.
                    o.symbol_map_dirty = true;
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

            o.mark_dirty();
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

            if strcmp(oldsymbol, newsymbol)
                return
            end

            % Validate the target name before any mutation: an invalid identifier
            % would make the dynamic-field assignments below fail half-way through,
            % and a collision would silently overwrite the existing symbol's entry.
            if ~isvarname(newsymbol)
                error('modBuilder:rename:badName', '"%s" is not a valid symbol name.', newsymbol)
            end

            modBuilder.validate_symbol_name(newsymbol, 'rename');

            if o.issymbol(newsymbol) || ismember(newsymbol, o.symbols)
                error('modBuilder:rename:nameCollision', 'Cannot rename "%s" into "%s": "%s" already exists in the model.', oldsymbol, newsymbol, newsymbol)
            end

            [type, id] = o.typeof(oldsymbol);

            % Equations that actually reference oldsymbol, captured before the
            % tables are mutated (for an endogenous variable, T.var seeds each
            % variable with its own equation, so the defining equation is in the
            % list). The AST rewrite below is restricted to these rows: the other
            % equations are neither reparsed nor re-rendered, so their text keeps
            % the user's original formatting.
            switch type
              case 'parameter'
                affected = o.T.params.(oldsymbol);
              case 'exogenous'
                affected = o.T.varexo.(oldsymbol);
              case 'endogenous'
                affected = o.T.var.(oldsymbol);
            end

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

            % Rename in the affected equations via an AST walk: parse each side of
            % '=', rewrite matching sym / tsym / ss leaves, render back. This avoids
            % the regex word-boundary edge cases of the previous text-based rewrite.
            % (When the renamed symbol is endogenous, its own equation was re-keyed
            % to newsymbol in the switch above, so the affected list is re-keyed too.)
            affected = modBuilder.replaceincell(affected, oldsymbol, newsymbol);
            row_of = dictionary(string(o.equations(:, modBuilder.EQ_COL_NAME)), (1:size(o.equations, 1))');
            for a = 1:numel(affected)
                i = row_of(affected{a});
                eq_str = o.equations{i,modBuilder.EQ_COL_EXPR};
                LHSRHS = strsplit(eq_str, '=');
                if length(LHSRHS) == 2
                    new_lhs = ast(strtrim(LHSRHS{1})).rename(oldsymbol, newsymbol).string();
                    new_rhs = ast(strtrim(LHSRHS{2})).rename(oldsymbol, newsymbol).string();
                    o.equations{i,modBuilder.EQ_COL_EXPR} = sprintf('%s = %s', new_lhs, new_rhs);
                elseif isscalar(LHSRHS)
                    o.equations{i,modBuilder.EQ_COL_EXPR} = ast(strtrim(LHSRHS{1})).rename(oldsymbol, newsymbol).string();
                else
                    error('modBuilder:rename:multipleEquals', 'rename: equation "%s" contains more than one "=" symbol.', affected{a})
                end
                o.T.equations.(o.equations{i,modBuilder.EQ_COL_NAME}) = modBuilder.replaceincell(o.T.equations.(o.equations{i,modBuilder.EQ_COL_NAME}), oldsymbol, newsymbol);
            end

            % Update steady-state expressions (same AST walk; expressions are pure RHS,
            % no '=' to split on). Expressions not referencing oldsymbol are left as
            % written.
            for i=1:size(o.steady_state, 1)
                if strcmp(o.steady_state{i, modBuilder.SS_COL_NAME}, oldsymbol)
                    o.steady_state{i, modBuilder.SS_COL_NAME} = newsymbol;
                end
                if ismember(oldsymbol, modBuilder.getsymbols(o.steady_state{i, modBuilder.SS_COL_EXPR}))
                    o.steady_state{i, modBuilder.SS_COL_EXPR} = ast(o.steady_state{i, modBuilder.SS_COL_EXPR}).rename(oldsymbol, newsymbol).string();
                end
            end

            o.mark_dirty();
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
            % Print list of parameters
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
                [sorted_names, sorted_rows] = o.checksteady();
                fprintf(fid, '\nsteady_state_model;\n\n');
                for i=1:numel(sorted_rows)
                    nm = o.steady_state{sorted_rows(i), modBuilder.SS_COL_NAME};
                    expr = o.steady_state{sorted_rows(i), modBuilder.SS_COL_EXPR};
                    if ischar(nm)
                        fprintf(fid, '\t%s = %s;\n', nm, expr);
                    elseif isscalar(nm)
                        % Single-output block call: plain assignment, no brackets.
                        fprintf(fid, '\t%s = %s;\n', nm{1}, expr);
                    else
                        % Multi-output block call registered by steady_call (a helper
                        % generated by apply_steady_plan): Dynare accepts MATLAB
                        % functions returning several outputs in steady_state_model.
                        fprintf(fid, '\t[%s] = %s;\n', strjoin(nm, ', '), expr);
                    end
                end
                fprintf(fid, '\nend;\n');
                % Dynare requires every endogenous variable to be assigned in a
                % steady_state_model block; a partial block fails at run time with an
                % uninitialised-variable error far from its cause, so flag it here.
                missing = setdiff(o.var(:, modBuilder.COL_NAME)', sorted_names);
                if ~isempty(missing)
                    modBuilder.warn_silent('modBuilder:write:incompleteSteadyStateModel', 'The steady_state_model block leaves %d endogenous variable(s) unassigned:%s Dynare will fail at run time; close the corresponding blocks (apply_steady_plan with GenerateHelpers=true) or declare their values with steady().', numel(missing), modBuilder.printlist(missing));
                end
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

        function out = tex_model(o, filename)
        % Render the model equations as a LaTeX align environment.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - filename  [char]   (optional) path to write the LaTeX to. If omitted, nothing is
        %                      written; the rendering is only returned.
        %
        % OUTPUTS:
        % - out       [char]   the LaTeX string (assigned only when an output is requested).
        %
        % REMARKS:
        % - Each equation "LHS = RHS" becomes an aligned row "<LHS> &= <RHS>" inside a single
        %   \begin{align} … \end{align} block, in declaration order. An equation with no '='
        %   is rendered as a residual "<expr> &= 0".
        % - Symbols are rendered via ast.to_latex using the per-symbol texname metadata
        %   (parameter(..., 'texname', ...) and friends); symbols without a texname render
        %   literally. Endogenous and exogenous variables are dated: a current-period use gets
        %   a _t subscript (y → y_t) and a lead/lag its period (k(-1) → k_{t-1}), while
        %   parameters stay bare.
        % - The expressions keep their full dynamics (no staticisation).
        %
        % EXAMPLES:
        % tex = m.tex_model();              % return the LaTeX string
        % m.tex_model('paper/model.tex');   % write it to a file
            arguments
                o
                filename (1,:) char = ''
            end
            map = o.texname_map();
            dated = [o.var(:, modBuilder.COL_NAME); o.varexo(:, modBuilder.COL_NAME)];
            neq = size(o.equations, 1);
            rows = cell(neq, 1);
            for i = 1:neq
                LHSRHS = strsplit(o.equations{i, modBuilder.EQ_COL_EXPR}, '=');
                if isscalar(LHSRHS)
                    rows{i} = ['  ' ast(strtrim(LHSRHS{1})).to_latex(map, dated) ' &= 0'];
                else
                    lhs = ast(strtrim(LHSRHS{1})).to_latex(map, dated);
                    rhs = ast(strtrim(LHSRHS{2})).to_latex(map, dated);
                    rows{i} = ['  ' lhs ' &= ' rhs];
                end
            end
            body = modBuilder.tex_align({rows}, filename);
            if nargout > 0
                out = body;
            end
        end % function

        function out = tex_steady_state_system(o, filename)
        % Render the steady-state system as a LaTeX align environment: each equation's static
        % residual, simplified, set to zero.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - filename  [char]   (optional) path to write the LaTeX to. If omitted, nothing is
        %                      written; the rendering is only returned.
        %
        % OUTPUTS:
        % - out       [char]   the LaTeX string (assigned only when an output is requested).
        %
        % REMARKS:
        % - Each equation becomes a row "<residual> = 0". The residual is the static "LHS - RHS"
        %   (all leads/lags collapsed to the steady-state value) passed through simplify, so the
        %   dynamic structure cancels (e.g. c(-1)/c reduces to 1 and an Euler equation collapses
        %   to its steady-state form). An equation with no '=' is taken as "<expr> = 0".
        % - Rows are LEFT-aligned: the align column sits at the left of every equation, not on the
        %   equals sign, so the equations line up flush on the left.
        % - Endogenous variables carry the steady-state superscript (k -> k^{\star}); exogenous
        %   variables and parameters render with their texname (or escaped literal) and stay bare.
        %   Symbol texnames come from the per-symbol metadata (parameter(..., 'texname', ...) etc.).
        %
        % EXAMPLES:
        % tex = m.tex_steady_state_system();                 % return the LaTeX string
        % m.tex_steady_state_system('paper/steady.tex');     % write it to a file
            arguments
                o
                filename (1,:) char = ''
            end
            % Endogenous variables become steady-state nodes (rendered k^{\star}, with powers handled
            % via to_latex's invisible delimiters); exogenous variables and parameters stay bare.
            map = o.texname_map();
            endo = reshape(o.var(:, modBuilder.COL_NAME), 1, []);
            neq = size(o.equations, 1);
            rows = cell(neq, 1);
            for i = 1:neq
                r = modBuilder.static_residual(o, i);
                if isempty(r)
                    error('modBuilder:tex_steady_state_system:unparsableEquation', 'Equation "%s" cannot be parsed.', o.equations{i, modBuilder.EQ_COL_NAME});
                end
                rows{i} = ['  &' r.simplify().at_steady_state(endo).to_latex(map) ' = 0'];
            end
            body = modBuilder.tex_align({rows}, filename);
            if nargout > 0
                out = body;
            end
        end % function

        function out = tex_steady_state_plan(o, filename)
        % Render the steady-state system as a recursively-ordered LaTeX align block, following the
        % block decomposition from steady_plan.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - filename  [char]   (optional) path to write the LaTeX to. If omitted, nothing is
        %                      written; the rendering is only returned.
        %
        % OUTPUTS:
        % - out       [char]   the LaTeX string (assigned only when an output is requested).
        %
        % REMARKS:
        % - The equations are ordered by steady_plan's SCC decomposition (topological order), not by
        %   declaration order. Each block renders one of two ways:
        %     * a block solved analytically (steady_plan found a closed form for every variable it
        %       determines) prints the SOLUTIONS, one per row, "<var>^{\star} = <expr>";
        %     * a block that needs a numerical solver prints the RESIDUAL system it must solve,
        %       "<residual> = 0" per equation.
        %   So a model reads as a recursive cascade: an analytic prologue solved from the parameters
        %   and exogenous variables, then the simultaneous blocks a solver must close, then an
        %   analytic epilogue whose solutions are written in terms of the just-solved unknowns. The
        %   two forms are self-identifying (= <expr> vs = 0), so no block headers are emitted; blocks
        %   are separated by a little vertical space.
        % - Endogenous variables carry the steady-state superscript (k -> k^{\star}); exogenous
        %   variables and parameters stay bare. Symbol texnames come from the per-symbol metadata.
        %
        % EXAMPLES:
        % tex = m.tex_steady_state_plan();
        % m.tex_steady_state_plan('paper/steady_plan.tex');
            arguments
                o
                filename (1,:) char = ''
            end
            map = o.texname_map();
            endo = reshape(o.var(:, modBuilder.COL_NAME), 1, []);
            blocks = o.steady_plan();
            blockrows = {};
            for bi = 1:numel(blocks)
                b = blocks(bi);
                rows = {};
                if ~isempty(b.vars) && numel(b.closed_form) == numel(b.vars)
                    % Fully solved analytically: print each variable's closed-form solution. The
                    % expression may reference earlier-solved variables (including the numerical
                    % blocks' unknowns) by name, which render with the steady-state star.
                    for j = 1:numel(b.closed_form)
                        lhs = ast('ss', [], {ast('sym', b.closed_form(j).var, {})}).to_latex(map);
                        rhs = ast(b.closed_form(j).expr).at_steady_state(endo).to_latex(map);
                        rows{end+1} = ['  ' lhs ' &= ' rhs]; %#ok<AGROW>
                    end
                else
                    % Needs a numerical solver: print the residual system it must close.
                    for j = 1:numel(b.eqs)
                        idx = find(strcmp(b.eqs{j}, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
                        r = modBuilder.static_residual(o, idx).simplify().at_steady_state(endo);
                        rows{end+1} = ['  ' r.to_latex(map) ' &= 0']; %#ok<AGROW>
                    end
                end
                if ~isempty(rows)
                    blockrows{end+1} = rows; %#ok<AGROW>
                end
            end
            % Each block renders as its own group, separated by a little vertical space (no headers).
            body = modBuilder.tex_align(blockrows, filename);
            if nargout > 0
                out = body;
            end
        end % function

        function out = tex_linearise(o, varlist, options)
        % Render the log-linearised model as a LaTeX align environment, each equation normalized
        % on its keyed endogenous variable.
        %
        % INPUTS:
        % - o         [modBuilder]
        % - varlist   [cell]   (optional) the time-varying variables to linearise (and whose
        %                      equations to render). Defaults to every endogenous variable. A
        %                      variable not in varlist (any parameter, and exogenous/excluded
        %                      variables) is held at its steady state and drops out.
        %
        % OPTIONS (name-value):
        % - LevelVars  [cell]    variables to enter as a level deviation (x_t - x^{\star}) rather
        %                        than a log deviation \hat{x}_t. Use for variables with a zero or
        %                        negative steady state (rates, multipliers). Default {} (all log).
        % - Evaluate   [logical] false (default) keeps the coefficients symbolic, as steady-state
        %                        expressions (k^{\star} etc.); true substitutes the numeric steady
        %                        state (which must already be solved/set). Default false.
        % - filename   [char]    path to write the LaTeX to; if omitted nothing is written.
        %
        % OUTPUTS:
        % - out       [char]   the LaTeX string (assigned only when an output is requested).
        %
        % REMARKS:
        % - For each equation residual f, the coefficient on a variable v entering at lag k is the
        %   period-specific partial df/dv(k) evaluated at the steady state, times v^{\star} when v
        %   is a log variable (since dv = v^{\star} \hat{v}). The equation is then divided by the
        %   keyed variable's own (lag-0) coefficient and that variable isolated on the left, so the
        %   row reads x_hat = sum of elasticities (e.g. y_hat = (c*/y*) c_hat + (i*/y*) i_hat).
        % - Rows are aligned on the equals sign. Log deviations render as \hat{x}_t / \hat{x}_{t-1};
        %   level deviations as (x_t - x^{\star}); coefficients carry the ^{\star} steady-state mark
        %   (Evaluate=false) or a number (Evaluate=true).
        %
        % EXAMPLES:
        % tex = m.tex_linearise();                                  % all endogenous, symbolic
        % tex = m.tex_linearise({'y','c','k'}, 'Evaluate', true);   % subset, numeric coefficients
        % tex = m.tex_linearise({'y','pi','i'}, 'LevelVars', {'pi','i'});
            arguments
                o
                varlist                cell = {}
                options.LevelVars      cell = {}
                options.Evaluate (1,1) logical = false
                options.filename (1,:) char = ''
            end
            if isempty(varlist)
                varlist = reshape(o.var(:, modBuilder.COL_NAME), 1, []);
            end
            map = o.texname_map();
            % Variables (endogenous and exogenous) become steady-state values in a coefficient;
            % parameters stay bare.
            allvars = reshape([o.var(:, modBuilder.COL_NAME); o.varexo(:, modBuilder.COL_NAME)], 1, []);
            if options.Evaluate
                vals = o.steady_values_struct();
            else
                vals = struct();
            end

            neq = numel(varlist);
            rows = cell(neq, 1);
            for vi = 1:neq
                key = varlist{vi};
                eq_idx = find(strcmp(key, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
                if isempty(eq_idx)
                    error('modBuilder:tex_linearise:notAnEquation', 'Variable "%s" has no equation to linearise.', key);
                end
                f = modBuilder.dynamic_residual(o, eq_idx);
                if isempty(f)
                    error('modBuilder:tex_linearise:unparsableEquation', 'Equation "%s" cannot be parsed.', key);
                end
                if ~ismember(0, f.lags_of(key))
                    error('modBuilder:tex_linearise:cannotNormalise', 'Cannot normalise equation "%s" on "%s": the variable does not appear contemporaneously.', key, key);
                end
                den = coef_ast(key, 0, ismember(key, options.LevelVars));

                terms = {};
                for wi = 1:numel(varlist)
                    v = varlist{wi};
                    ks = f.lags_of(v);
                    for kk = 1:numel(ks)
                        k = ks(kk);
                        if strcmp(v, key) && k == 0
                            continue
                        end
                        % Coefficient is -(partial/den). Build the negation as 0 - ratio (not a
                        % uminus), which simplify distributes cleanly: -(-1 + delta) collapses to the
                        % readable 1 - delta rather than staying wrapped in a unary minus.
                        ratio = ast('binop', '/', {coef_ast(v, k, ismember(v, options.LevelVars)), den}).simplify();
                        c = ast('binop', '-', {ast('num', 0, {}), ratio}).simplify();
                        [sgn, coefpart, skip] = render_coef(c);
                        if skip
                            continue
                        end
                        terms{end+1} = struct('sgn', sgn, 'core', [coefpart linearise_dev(v, k, ismember(v, options.LevelVars))]); %#ok<AGROW>
                    end
                end
                lhs = linearise_dev(key, 0, ismember(key, options.LevelVars));
                rows{vi} = ['  ' lhs ' &= ' assemble_sum(terms)];
            end

            body = modBuilder.tex_align({rows}, options.filename);
            if nargout > 0
                out = body;
            end

            % --- nested helpers (share f / map / starmap / vals / options) ---
            function g = coef_ast(v, k, islevel)
                % Steady-state coefficient on v at lag k: df/dv(k) at the SS, times v^{\star} for a
                % log variable. Built symbolically (staticised); evaluated numerically downstream
                % when Evaluate is true.
                g = f.diff_ast(v, k);
                if ~islevel
                    g = ast('binop', '*', {g, ast('sym', v, {})});
                end
                g = g.staticise();
            end

            function [sgn, coefpart, skip] = render_coef(c)
                % Split the (already negated) coefficient AST into a leading sign and the
                % (parenthesised when additive) coefficient string, dropping a unit coefficient and
                % a numerically zero term. Numeric when Evaluate.
                skip = false;
                if options.Evaluate
                    x = c.eval(vals);
                    if ~isfinite(x)
                        error('modBuilder:tex_linearise:steadyStateRequired', 'Evaluate=true needs a finite steady state; a coefficient evaluated to a non-finite value. Solve or set the steady state first.');
                    end
                    if abs(x) < 1e-12
                        skip = true; sgn = '+'; coefpart = ''; return
                    end
                    if x < 0, sgn = '-'; else, sgn = '+'; end
                    a = abs(x);
                    if abs(a - 1) < 1e-12
                        coefpart = '';
                    else
                        coefpart = [ast('num', a, {}).to_latex() '\,'];
                    end
                    return
                end
                if strcmp(c.type, 'num') && c.value == 0
                    skip = true; sgn = '+'; coefpart = ''; return
                end
                if strcmp(c.type, 'uminus')
                    sgn = '-'; body = c.children{1};
                elseif strcmp(c.type, 'num') && c.value < 0
                    sgn = '-'; body = ast('num', -c.value, {});
                else
                    sgn = '+'; body = c;
                end
                bstr = body.at_steady_state(allvars).to_latex(map);
                if strcmp(bstr, '1')
                    coefpart = '';
                else
                    if strcmp(body.type, 'binop') && (strcmp(body.value, '+') || strcmp(body.value, '-'))
                        bstr = ['\left(' bstr '\right)'];
                    end
                    coefpart = [bstr '\,'];
                end
            end

            function d = linearise_dev(v, k, islevel)
                % LaTeX for the deviation of v at lag k: a level deviation (v_t - v^{\star}) or a log
                % deviation \hat{v}_t / \hat{v}_{t+k}.
                if islevel
                    if k == 0
                        tp = ast('sym', v, {}).to_latex(map, {v});
                    else
                        tp = ast('tsym', {v, k}, {}).to_latex(map, {v});
                    end
                    d = ['\left(' tp ' - ' ast('ss', [], {ast('sym', v, {})}).to_latex(map) '\right)'];
                else
                    base = ast('sym', v, {}).to_latex(map);
                    if k == 0
                        d = ['\hat{' base '}_t'];
                    else
                        d = ['\hat{' base '}_{t' sprintf('%+d', k) '}'];
                    end
                end
            end

            function s = assemble_sum(terms)
                if isempty(terms)
                    s = '0';
                    return
                end
                if strcmp(terms{1}.sgn, '-')
                    s = ['-' terms{1}.core];
                else
                    s = terms{1}.core;
                end
                for i = 2:numel(terms)
                    s = [s ' ' terms{i}.sgn ' ' terms{i}.core]; %#ok<AGROW>
                end
            end
        end % function

        function vals = steady_values_struct(o)
        % Build a struct mapping every declared symbol to its current numeric value (calibration /
        % steady state), for evaluating expressions at the steady state. Errors if a value is NaN,
        % since a missing steady state would silently poison the evaluation.
            vals = struct();
            tables = {o.params, o.varexo, o.var};
            for t = 1:numel(tables)
                tbl = tables{t};
                for i = 1:size(tbl, 1)
                    name = tbl{i, modBuilder.COL_NAME};
                    value = tbl{i, modBuilder.COL_VALUE};
                    if isempty(value) || isnan(value)
                        error('modBuilder:steady_values_struct:missingValue', 'Symbol "%s" has no value; solve or set the steady state before evaluating.', name);
                    end
                    vals.(name) = value;
                end
            end
        end % function

        function map = texname_map(o)
        % Build a struct mapping each symbol name to its declared LaTeX name (texname),
        % skipping symbols without one (those render literally). Shared by the LaTeX
        % reporting methods and passed as the texname_map argument of ast.to_latex.
            map = struct();
            tables = {o.var, o.varexo, o.params};
            for t = 1:numel(tables)
                tbl = tables{t};
                for i = 1:size(tbl, 1)
                    tx = tbl{i, modBuilder.COL_TEX_NAME};
                    if ~isempty(tx)
                        map.(tbl{i, modBuilder.COL_NAME}) = tx;
                    end
                end
            end
        end % function

        function s = saveobj(o)
        % Serialize a modBuilder object, used when saving object to mat file.
        %
        % INPUTS:
        % - o      [modBuilder]
        %
        % OUTPUTS:
        % - s      [struct]        One field for each member of the modBuilder
        %                          class, plus a 'version' schema tag (see
        %                          modBuilder.SCHEMA_VERSION and loadobj).
            s.version = modBuilder.SCHEMA_VERSION;
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

            % (Re)initialize all symbol tables and pre-create a field for every known symbol (O(n)).
            % Parameters and exogenous start with no referencing equations; each endogenous seeds with its own equation.
            kinds = modBuilder.symbol_kinds();
            for k=1:numel(kinds)
                tbl = o.(kinds(k).prop);
                o.T.(kinds(k).prop) = struct();
                seed_self = strcmp(kinds(k).type, 'endogenous');
                for i=1:size(tbl, 1)
                    name = tbl{i, modBuilder.COL_NAME};
                    if seed_self
                        o.T.(kinds(k).prop).(name) = {name};
                    else
                        o.T.(kinds(k).prop).(name) = cell(1, 0);
                    end
                end
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
                        equation = o.equations(strcmp(eqnames{i}, o.equations(:,modBuilder.EQ_COL_NAME)),modBuilder.EQ_COL_EXPR);
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


        function disp(o)
        % Compact one-line description of the model.
        %
        % INPUTS:
        % - o      [modBuilder]
        %
        % REMARKS:
        % - Overrides MATLAB's default property dump. Called automatically at
        %   the prompt when an expression returning a modBuilder object is not
        %   terminated by a semicolon (through the default display), and by an
        %   explicit disp(m). Use summary() for the fuller multi-line report,
        %   and table() / lookfor() / equationmap() to inspect contents.
        % - The status flag reports whether the symbol tables (o.T) are current.
        %   A "stale" model is not an error: the tables are rebuilt lazily on the
        %   next query that needs them.
        % - A handle object array (e.g. [m1 m2]) is dispatched to the built-in
        %   disp, which lists the elements one per line.
            if ~isscalar(o)
                builtin('disp', o);
                return
            end
            n_params = o.size('parameters');
            if n_params > 0
                n_calibrated = sum(~cellfun(@isnan, o.params(:, modBuilder.COL_VALUE)));
                paramstr = sprintf('%d parameters (%d calibrated)', n_params, n_calibrated);
            else
                paramstr = '0 parameters';
            end
            if o.tables_dirty
                status = 'symbol tables stale';
            else
                status = 'symbol tables up to date';
            end
            fprintf('  modBuilder: %d endogenous, %d exogenous, %s, %d equations [%s]\n', ...
                    o.size('endogenous'), o.size('exogenous'), paramstr, o.size('equations'), status);
            if ~isempty(o.symbols)
                fprintf('  warning: %d untyped symbol(s): %s\n', numel(o.symbols), strjoin(o.symbols, ', '));
            end
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

                % Expand both names over the Cartesian product of the index values
                % and flip all matching pairs using recursion
                expanded = modBuilder.expand_templates({varname, varexoname}, varargin);
                for i=1:size(expanded, 1)
                    o.flip(expanded{i,1}, expanded{i,2});
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

                % The equation currently attached to varname becomes varexoname's
                % equation: varexoname must appear in it, otherwise the equation
                % cannot determine varexoname. Checked before any mutation so a
                % bad pair leaves the object untouched.
                if ~ismember(varexoname, o.T.equations.(varname))
                    error('modBuilder:flip:notInEquation', 'Exogenous variable "%s" does not appear in equation "%s".', varexoname, varname)
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

            o.mark_dirty();
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

            o.mark_dirty();
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

                % Expand both names over the Cartesian product of the index values
                % and recurse for each combination
                expanded = modBuilder.expand_templates({eqname, newexo}, varargin);
                for i = 1:size(expanded, 1)
                    o.rmflip(expanded{i,1}, expanded{i,2});
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
            p.symbol_map_dirty = o.symbol_map_dirty;
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

            % Calibration swaps are model state (copy and saveobj carry them, and
            % they change steady_plan output), so two models differing only in
            % their swaps must not compare equal.
            if not(isequal(o.calibration_swaps, p.calibration_swaps))
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

            for i=1:length(list_of_symbols_potentially_to_be_removed)
                if not(o.appear_in_more_than_one_equation(list_of_symbols_potentially_to_be_removed{i}))
                    % Remove parameter/variable if it does not appear in another equation.
                    [type, id] = o.typeof(list_of_symbols_potentially_to_be_removed{i});

                    switch type
                      case 'parameter'
                        o.params(id,:) = [];
                        o.T.params = rmfield(o.T.params, list_of_symbols_potentially_to_be_removed{i});
                        % The deletion shifted the row indices after id: rebuild the
                        % map lazily on the next lookup.
                        o.symbol_map_dirty = true;
                      case 'exogenous'
                        o.varexo(id,:) = [];
                        o.T.varexo = rmfield(o.T.varexo, list_of_symbols_potentially_to_be_removed{i});
                        o.symbol_map_dirty = true;
                      otherwise
                        % Nothing to be done here.
                    end
                end
            end

            o.T.equations.(varname) = ntokens;

            o.mark_dirty();
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
            % Equations where the target cannot appear -- the symbol (or, for an
            % expression target, one of its symbols) is absent from the equation's
            % symbol set -- are skipped outright: no parse, no rewrite, and their
            % text keeps the user's original formatting.
            row_of = dictionary(string(o.equations(:, modBuilder.EQ_COL_NAME)), (1:size(o.equations, 1))');
            target_syms = target_ast.symbol_names();
            for i = 1:numel(eqnames)
                nm = eqnames{i};
                eq_syms = [o.T.equations.(nm), {nm}];
                if target_is_symbol
                    if ~ismember(expr1, eq_syms)
                        continue
                    end
                elseif ~isempty(target_syms) && ~all(ismember(target_syms, eq_syms))
                    continue
                end
                ide = row_of(nm);
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

            % Drop parameters / exogenous no longer referenced by any equation, then
            % rebuild T and the symbol map in one consistent pass. The "referenced"
            % set comes from o.T.equations.(eqname), which the loop above refreshed
            % for every rewritten equation. Pruning BEFORE updatesymboltables() means
            % the rebuilt T.params / T.varexo / symbol_map are consistent on the
            % first pass — no orphan T fields to rmfield, no stale rows in the map,
            % no second tables_dirty=true to "fix it up" after the fact.
            eqnames = o.equations(:, modBuilder.EQ_COL_NAME);
            referenced_lists = cellfun(@(nm) o.T.equations.(nm), eqnames, 'UniformOutput', false);
            referenced = unique([referenced_lists{:}]);
            o.params(~ismember(o.params(:, modBuilder.COL_NAME), referenced), :) = [];
            o.varexo(~ismember(o.varexo(:, modBuilder.COL_NAME), referenced), :) = [];
            o.mark_dirty();
            o.updatesymboltables();
        end % function

        function o = eliminate(o, varname)
        % Eliminate an endogenous variable: solve its own equation for it, substitute the result
        % into every equation, and drop the now-redundant defining equation and the variable.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - varname  [char]   name of the endogenous variable to eliminate
        %
        % OUTPUTS:
        % - o        [modBuilder]   updated object (one equation and one variable fewer)
        %
        % REMARKS:
        % - Only an endogenous variable can be eliminated: it is the one that owns a defining
        %   equation. A parameter, an exogenous variable or an unknown symbol raises
        %   modBuilder:eliminate:notEndogenous.
        % - varname must be defined statically by its own equation: if it appears at a lead/lag of
        %   itself the equation is a genuine difference equation (e.g. an AR(1) law of motion) and
        %   raises modBuilder:eliminate:dynamicDefinition (ast.isolate would otherwise aggregate the
        %   leads/lags into a steady-state value, an invalid dynamic substitution).
        % - The variable's equation (LHS - RHS = 0) is solved for varname with ast.isolate, which
        %   handles the linear / monomial / invertible-call cases. If it cannot isolate varname in
        %   closed form it returns nothing and this raises modBuilder:eliminate:notClosedForm; the
        %   user can still eliminate the variable by hand with subs.
        % - The substitution is model-wide and lag-aware: every occurrence of varname is replaced,
        %   so a lead/lag varname(k) becomes the solved expression shifted to period k. The model
        %   stays square (one equation and one variable removed).
        % - This packages the isolate -> subs -> remove composition. Typical use: substitute a
        %   Lagrange multiplier introduced by augment back out to recover the textbook condition,
        %   e.g. eliminate('mult_1') turns the optimal-growth FOCs into the consumption Euler.
        %
        % EXAMPLES:
        % r = m.lagrangian_foc('W', {'k'}, {'c', 'k'});
        % m.augment(r);
        % m.eliminate('mult_1');   % isolate mult_1 = 1/c, substitute throughout, drop the equation
            arguments
                o
                varname (1,:) char {mustBeNonempty}
            end
            if ~o.isendogenous(varname)
                error('modBuilder:eliminate:notEndogenous', 'Can only eliminate an endogenous variable; "%s" is not one.', varname);
            end
            idx = find(strcmp(varname, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
            res = modBuilder.dynamic_residual(o, idx);
            % varname must be defined statically by its own equation. If it appears at a lead/lag
            % of itself the equation is a genuine difference equation (e.g. an AR(1) law of motion);
            % ast.isolate would aggregate those occurrences into a steady-state value, which is not a
            % valid dynamic substitution, so refuse.
            if any(res.lags_of(varname) ~= 0)
                error('modBuilder:eliminate:dynamicDefinition', 'The equation defining "%s" involves its own lead/lag, so it cannot be eliminated by static substitution.', varname);
            end
            sol = res.isolate(varname);
            if isempty(sol) || ismember(varname, sol.symbol_names())
                error('modBuilder:eliminate:notClosedForm', 'Cannot solve the equation for "%s" in closed form; eliminate it manually with subs.', varname);
            end
            o = o.subs(varname, sol.string());
            o = o.remove(varname);
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
                            % The deletion shifted the row indices after id: rebuild
                            % the map lazily on the next lookup.
                            o.symbol_map_dirty = true;
                        end
                    end
                end

                o.T.equations.(eqname) = Symbols;
            end

            % Add unknown symbols to symbols list
            if unknown_count > 0
                o.symbols = unique([o.symbols, list_of_unknown_symbols(1:unknown_count)]);
            end

            o.mark_dirty();
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

        function blocks = steady_plan(o, options)
        % Compute the structural steady-state plan: SCC decomposition of the dependency graph
        % induced by the variable↔equation pairing.
        %
        % OUTPUT:
        % - blocks    [struct array]   one entry per SCC, in topological order:
        %               .vars         [cell]    endogenous variable names in the block
        %               .eqs          [cell]    equation names paired to those vars (= .vars in this codebase)
        %               .eqnames      [cell]    declaration keys of the block's equations (they differ
        %                                       from .eqs under Match=true, where the pairing is
        %                                       recomputed; used to rebuild the block residuals)
        %               .kind         [char]    'trivial' | 'self-recursive' | 'simultaneous' | 'anchor'
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
        %               .reduced      [struct]  non-empty .vars/.residuals when a stalled elimination
        %                                       left a REDUCED square system: .vars are the open
        %                                       variables, .residuals (cell of char) their equations
        %                                       with every closed form substituted in. closed_form is
        %                                       then the conditional epilogue: valid once .vars are
        %                                       solved (apply_steady_plan's generated helpers solve
        %                                       exactly this reduced system).
        %               .backout      [struct]  non-empty when the block scale was recovered by the
        %                                       gauge backout, with fields .gauge (the variable whose
        %                                       level the consistency equation pins) and .eq (the
        %                                       original name of that consistency equation). For a
        %                                       multi-gauge block (several independent scales) both
        %                                       fields are cell arrays, one entry per closed gauge.
        %
        % REMARKS:
        % - 'trivial':         single equation, the paired variable does not appear in its own equation
        %                      (no self-reference at any lag). Solvable in one step in the recursive order.
        % - 'self-recursive':  single equation, the paired variable appears in its own equation (typically
        %                      via a lag, so the equation staticises to an equation in the variable itself).
        % - 'simultaneous':    SCC of size > 1; the variables are jointly determined by the equations and
        %                      require either further symbolic reduction or a numerical solver.
        % - 'anchor':          (Match=true only) an economically exogenous variable -- one belonging to an
        %                      AR/ARMA/VAR driving process (a sink block of the dependency graph fed by an
        %                      exogenous innovation), whose steady-state value is a free anchor supplied by
        %                      the user rather than pinned by the rest of the model. A multivariate process
        %                      (VAR) is kept as a single 'anchor' block of size > 1: its joint static
        %                      system (I-K)x = c is closed like a simultaneous block, so the closed forms
        %                      come out in evaluation order and the determinant probe catches unit-root
        %                      processes (det(I-K) = 0 at the calibration).
        % - The dependency analysis collects symbol names from each equation via the AST, regardless of
        %   lag. The static dependency graph and its SCC structure are identical to what one obtains by
        %   first staticising every equation, since name equality is unchanged by staticise.
        % - For singleton blocks (trivial / self-recursive), ast.isolate is invoked on the static residual
        %   to derive a closed form. For simultaneous blocks of size 2..4, ast.linearise_system attempts
        %   to extract a coefficient matrix; if the system is jointly linear and the matrix is non-singular,
        %   ast.solve_linear_system returns the closed forms via Cramer's rule.
        % - options.Match [logical, default false]: when true, the equation<->variable
        %   pairing is recomputed by bipartite matching (matchequations) on the
        %   SIMPLIFIED static residuals, and the dependency graph is built from those
        %   same residuals, instead of using the declaration pairing. This exposes the
        %   recursive steady-state structure that an arbitrary declaration pairing hides:
        %   a large simultaneous block frequently decomposes into singletons plus a few
        %   tiny blocks. Economically exogenous variables (AR/ARMA/VAR driving processes,
        %   detected structurally) are treated as anchors and excluded from the matching.
        %   Not supported together with calibration swaps.
        % - options.Anchors [cell of char, default {}]: additional endogenous variables
        %   to treat as user-declared normalisation anchors (e.g. a labour-supply scale),
        %   on top of the auto-detected exogenous processes. Requires Match=true. Each
        %   anchor variable is removed from the matching candidates and becomes an
        %   'anchor' source (its steady-state value is user-supplied). Fixing K anchors
        %   leaves K equations unmatched -- the consistency conditions that the anchor
        %   values must satisfy; each is reported as the equation of its 'anchor' block.
        %   A homogeneous (scale) normalisation is well-posed as is; if instead the
        %   surplus equation genuinely pins something, a calibration swap (freeing a
        %   parameter) is required rather than a plain anchor.
        % - options.MaxBlockSize [integer, default 8]: largest simultaneous block the
        %   symbolic machinery attempts to close (Bareiss keeps its own cap of 8).
        %   Elimination cost grows quickly with block size -- raising the cap to reach
        %   a large core (e.g. 13+ variables) can cost minutes.
        % - Gauge backout: re-matching a freed anchor equation inside a block can leave
        %   that block HOMOGENEOUS in its variables (e.g. the Calvo recursions once the
        %   optimal-price equation, degree 0, replaces the level equation): its equations
        %   pin the ratios but not the level, and the scale-pinning equation (aggregate
        %   production, market clearing) sits among the consistency conditions absorbed
        %   by the anchors. When a simultaneous block is left with a single open variable,
        %   the block is re-parametrised in that gauge (ratio_parametrise), the parametric
        %   forms are substituted into each unused consistency equation, and the gauge is
        %   isolated from the first one that pins it -- the hand technique of solving in
        %   ratios and backing the level out of a discarded equation. Runs to a fixed
        %   point, since one backout can unlock another block downstream.
            arguments
                o
                options.Match (1,1) logical = false
                options.Anchors (1,:) cell = {}
                options.PropagateKnown (1,1) logical = false
                options.MaxBlockSize (1,1) double {mustBeInteger, mustBePositive} = 8
            end

            if ~isempty(options.Anchors) && ~options.Match
                error('modBuilder:steady_plan:anchorsNeedMatch', ...
                      'The Anchors option requires Match=true.');
            end

            o.refresh_tables();

            n = size(o.equations, 1);
            blocks = struct('vars', {}, 'eqs', {}, 'eqnames', {}, 'kind', {}, 'deps', {}, 'extdeps', {}, 'closed_form', {}, 'backout', {}, 'reduced', {});
            if n == 0
                return
            end

            % Equation<->variable pairing (plan_pairing), dependency graph
            % (plan_dependencies), SCC order (plan_scc_order) and known-value
            % environment (plan_known_values).
            [var_names, keys, eqasts_s, calibrated_endos, is_anchor, is_norm_anchor, forced_pair] = modBuilder.plan_pairing(o, options.Match, options.Anchors);
            var_idx = dictionary(string(var_names(:)), (1:n)');

            [endo_deps, ext_deps] = modBuilder.plan_dependencies(o, options.Match, var_names, var_idx, eqasts_s, is_anchor, is_norm_anchor, calibrated_endos);

            [bins, ord] = modBuilder.plan_scc_order(endo_deps, var_idx, n);

            propagate = options.PropagateKnown;
            [param_names, calib_values, endo_names_all, known_names, known_asts] = modBuilder.plan_known_values(o, propagate);

            % Group equation indices by SCC, in topological order.
            for k = 1:numel(ord)
                members = find(bins == ord(k));
                reduced_info = struct('vars', {{}}, 'residuals', {{}});
                vs = var_names(members)';
                if isrow(vs)
                    vars_block = vs;
                else
                    vars_block = vs';
                end

                if numel(members) > 1
                    if all(is_anchor(members)) && ~any(is_norm_anchor(members))
                        % A multivariate exogenous driving process (VAR): kept as one
                        % block so its joint static system closes in evaluation order.
                        kind = 'anchor';
                    else
                        kind = 'simultaneous';
                    end
                else
                    i = members(1);
                    if is_anchor(i)
                        kind = 'anchor';
                    elseif ismember(var_names{i}, endo_deps{i})
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

                % Closed-form isolation: singleton blocks → ast.isolate (linear /
                % monomial / invertible-call); small simultaneous blocks → Bareiss /
                % elimination / ratio machinery (close_simultaneous).
                cf = struct('var', {}, 'expr', {});
                if numel(members) == 1 && ~is_norm_anchor(members(1))
                    cf = modBuilder.close_singleton(o, members(1), vars_block, known_names, known_asts, param_names, calib_values, forced_pair(members(1)));
                elseif numel(members) >= 2 && numel(members) <= options.MaxBlockSize
                    [cf, reduced_info] = modBuilder.close_simultaneous(o, members, vars_block, known_names, known_asts, param_names, calib_values);
                end

                % Propagate: a closed form that resolves to a constant (no endogenous
                % symbol once the known values are inlined) becomes known for the
                % downstream blocks -- e.g. InflationFactor = InflationTarget collapses
                % to a parameter, which then linearises the price recursion block.
                if propagate
                    for jj = 1:numel(cf)
                        ca = modBuilder.substitute_known(ast(cf(jj).expr).staticise(), {}, known_names, known_asts, param_names);
                        if ~any(ismember(ca.symbol_names(), endo_names_all))
                            known_names{end+1} = cf(jj).var; known_asts{end+1} = ca; %#ok<AGROW>
                        end
                    end
                end

                blocks(end+1).vars = vars_block; %#ok<AGROW>
                blocks(end).eqs = vars_block;
                % Declaration keys of the block's equations: under Match=true the
                % pairing is recomputed, so the paired variable names (.eqs) no longer
                % identify the equation rows; the keys let apply_steady_plan rebuild
                % the block residuals when it generates a numerical helper.
                blocks(end).eqnames = o.equations(members, modBuilder.EQ_COL_NAME)';
                blocks(end).kind = kind;
                blocks(end).deps = already_solved;
                blocks(end).extdeps = consts;
                blocks(end).closed_form = cf;
                blocks(end).reduced = reduced_info;

                % Advance the numeric shadow: evaluate the block's closed forms in
                % order (later assignments may reference earlier ones by name) so the
                % knife-edge and determinant probes downstream can conclude. A form
                % whose value is unavailable or non-finite is skipped -- dependent
                % probes then skip too, and the gap surfaces loudly at evaluation time.
                for jj = 1:numel(cf)
                    try
                        vv = ast(cf(jj).expr).eval(calib_values);
                        if isnumeric(vv) && isscalar(vv) && isfinite(vv) && isreal(vv)
                            calib_values.(cf(jj).var) = vv;
                        end
                    catch err
                        modBuilder.rethrow_unless(err, {'ast:'});
                    end
                end
            end

            % Gauge backout: recover the level of a scale-free block from a consistency
            % equation absorbed by a normalisation anchor (see REMARKS and gauge_backout).
            if options.Match && any(is_norm_anchor)
                blocks = modBuilder.gauge_backout(o, blocks, eqasts_s, keys, var_idx, is_norm_anchor, known_names, known_asts, param_names, calib_values);
            end
        end % function

        function suggestions = suggest_calibrations(o, blocks, options)
        % Scan candidate calibration role swaps that would close a residual sub-block.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - blocks   [struct array]   optional; if omitted, computed by o.steady_plan()
        %                             with the options below. When blocks IS supplied,
        %                             pass the SAME planning options that produced it:
        %                             each trial re-plans with these options, and a
        %                             baseline counted under a different regime (e.g.
        %                             Match=true blocks scored against default-plan
        %                             trials) makes the comparison meaningless.
        % - options                   steady_plan planning options, forwarded to every
        %                             trial re-plan (Match, Anchors, PropagateKnown,
        %                             MaxBlockSize; same defaults as steady_plan).
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
                options.Match (1,1) logical = false
                options.Anchors (1,:) cell = {}
                options.PropagateKnown (1,1) logical = false
                options.MaxBlockSize (1,1) double {mustBeInteger, mustBePositive} = 8
            end
            opts = namedargs2cell(options);
            if isempty(blocks)
                blocks = o.steady_plan(opts{:});
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
                % Any non-anchor block can carry a residual worth a swap: now that the
                % elimination probes every (equation, unknown) pair, an unresolved
                % variable often survives as an open SINGLETON (a transcendental FOC)
                % rather than inside a simultaneous block. Anchor levels are
                % user-supplied by convention, not swap targets.
                if strcmp(b.kind, 'anchor'), continue, end
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
                            new_blocks = m_copy.steady_plan(opts{:});
                        catch err
                            modBuilder.rethrow_unless(err, {'ast:', 'modBuilder:'});
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

        function out = suggest_anchors(o, options)
        % Reduce a pool of candidate steady-state anchors to an irreducible subset.
        %
        % INPUTS:
        % - o                       [modBuilder]
        % - options.Candidates      [cell]     candidate anchor names. Default: the endogenous
        %                                      variables with a value declared through m.steady,
        %                                      excluding auto-detected exogenous processes. The
        %                                      candidates are the modeller's economically known
        %                                      values (symmetric normalisations = 1, calibration
        %                                      targets, textbook steady-state constants); this
        %                                      method never invents a value, it only reports
        %                                      which of the declared knowns the structural plan
        %                                      actually needs.
        % - options.Keep            [cell]     anchors always kept, never tested (default {}).
        % - options.PropagateKnown  [logical]  passed to steady_plan (default true).
        %
        % OUTPUTS:
        % - out  [struct] with fields:
        %     .anchors   [cell]  the irreducible anchor subset (Keep members included)
        %     .dropped   [cell]  candidates found deducible: the plan closes as well
        %                        without them (anchor status AND declared value removed)
        %     .residual  [int]   number of open variables under the returned set
        %     .open      [cell]  their names (empty on full closure)
        %
        % REMARKS:
        % - Greedy leave-one-out, swept to a fixed point: candidates are tested in the
        %   given order; each trial removes the candidate's anchor status AND its
        %   declared steady-state value (so the value cannot leak into the known-value
        %   propagation), re-runs steady_plan(Match=true), and accepts the drop when
        %   the residual count does not deteriorate. Sweeps repeat until none is
        %   accepted: an OVER-anchored pool can start with a positive residual (too
        %   many freed equations disorient the matching), and drops rejected early can
        %   strictly improve once the pool has shrunk.
        % - The result is AN irreducible set for the given order, not a provable global
        %   minimum: candidates can be individually deducible yet jointly necessary,
        %   because the declared values feed the propagation that closes other blocks.
        % - The values of the anchors kept must be primitive from the modeller's
        %   standpoint (parameters and other anchors only): a kept anchor whose value
        %   references a variable the plan now derives creates a circular
        %   steady_state_model (rejected by checksteady at write time).
        % - Cost: one steady_plan re-run per candidate and per sweep (typically two
        %   sweeps), the same trade-off as suggest_calibrations.
        % - Called with no output, prints a readable summary.
        %
        % EXAMPLE:
        % m.steady('OptimalRelativePrice', '1');           % symmetric normalisation
        % m.steady('HouseholdLabourSupply', 'hours_ss');   % calibration target
        % out = m.suggest_anchors();
        % b = m.steady_plan(Match=true, Anchors=out.anchors, PropagateKnown=true);
            arguments
                o
                options.Candidates (1,:) cell = {}
                options.Keep (1,:) cell = {}
                options.PropagateKnown (1,1) logical = true
            end
            o.refresh_tables();
            candidates = options.Candidates;
            if isempty(candidates)
                if isempty(o.steady_state)
                    error('modBuilder:suggest_anchors:noCandidates', ...
                          'No candidates: declare the known steady-state values with m.steady, or pass Candidates.');
                end
                declared_names = o.steady_state(:, modBuilder.SS_COL_NAME)';
                keys = o.equations(:, modBuilder.EQ_COL_NAME);
                n = size(o.equations, 1);
                rawsyms = cell(n, 1);
                for i = 1:n
                    parts = strsplit(o.equations{i, modBuilder.EQ_COL_EXPR}, '=');
                    if numel(parts) == 2
                        resstr = sprintf('(%s) - (%s)', strtrim(parts{1}), strtrim(parts{2}));
                    else
                        resstr = strtrim(parts{1});
                    end
                    rawsyms{i} = ast(resstr).symbol_names();
                end
                is_exo = modBuilder.exogenous_processes(keys, rawsyms, @(nm) o.isexogenous(nm));
                exo_vars = keys(is_exo)';
                sel = cellfun(@(nm) o.isendogenous(nm) && ~ismember(nm, exo_vars), declared_names);
                candidates = declared_names(sel);
            end
            candidates = candidates(~ismember(candidates, options.Keep));

            [baseline, ~] = modBuilder.anchor_residual(o, [options.Keep, candidates], {}, options.PropagateKnown);
            % Greedy sweeps to a fixed point. A drop is accepted when the residual
            % does not deteriorate; the current residual is re-based after each
            % accepted drop. Repeated sweeps matter because an OVER-anchored pool can
            % start with a positive baseline (too many freed equations disorient the
            % matching): early drops shrink the pool, after which further drops --
            % rejected in the first sweep -- can strictly reduce the residual.
            current = baseline;
            dropped = {};
            progress = true;
            while progress
                progress = false;
                remaining = candidates(~ismember(candidates, dropped));
                for ci = 1:numel(remaining)
                    trial_drop = [dropped, remaining(ci)];
                    anchors = [options.Keep, candidates(~ismember(candidates, trial_drop))];
                    try
                        [nres, ~] = modBuilder.anchor_residual(o, anchors, trial_drop, options.PropagateKnown);
                    catch err
                        modBuilder.rethrow_unless(err, {'ast:', 'modBuilder:'});
                        continue
                    end
                    if nres <= current
                        dropped = trial_drop;
                        current = nres;
                        progress = true;
                    end
                end
            end
            kept = candidates(~ismember(candidates, dropped));
            [nres, open] = modBuilder.anchor_residual(o, [options.Keep, kept], dropped, options.PropagateKnown);

            out = struct();
            out.anchors = [options.Keep, kept];
            out.dropped = dropped;
            out.residual = nres;
            out.open = open;

            if nargout == 0
                modBuilder.dprintf('suggest_anchors: %d of %d candidates needed, residual %d (baseline %d)', ...
                    numel(kept), numel(candidates), nres, baseline);
                modBuilder.dprintf('  anchors : %s', strjoin(out.anchors, ', '));
                modBuilder.dprintf('  dropped : %s', strjoin(out.dropped, ', '));
                if nres > 0
                    modBuilder.dprintf('  open    : %s', strjoin(out.open, ', '));
                end
                clear out
            end
        end % function

        function print_steady_plan(o, blocks, options)
        % Render the structural steady-state plan as a human-readable summary.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - blocks   [struct array]   optional; if omitted, computed by o.steady_plan()
        %                             with the options below. When blocks IS supplied,
        %                             pass the SAME planning options that produced it,
        %                             so the calibration-swap suggestions below re-plan
        %                             under the regime the displayed counts came from.
        % - options                   steady_plan planning options (Match, Anchors,
        %                             PropagateKnown, MaxBlockSize), forwarded to
        %                             steady_plan and suggest_calibrations.
        %
        % REMARKS:
        % - Each block is shown with its kind, its variable(s), the already-solved endogenous
        %   variables it depends on, and its external constants (parameters / exogenous).
        % - When ast.isolate produced a closed form for a singleton block, it is rendered as
        %   "x = expr". Otherwise, simultaneous blocks are flagged "needs solver".
            arguments
                o
                blocks = []
                options.Match (1,1) logical = false
                options.Anchors (1,:) cell = {}
                options.PropagateKnown (1,1) logical = false
                options.MaxBlockSize (1,1) double {mustBeInteger, mustBePositive} = 8
            end
            opts = namedargs2cell(options);
            if isempty(blocks)
                blocks = o.steady_plan(opts{:});
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
                suggestions = o.suggest_calibrations(blocks, opts{:});
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

        function symmetries = scaling_symmetries(o, options)
        % Detect the scale symmetries of the steady-state system: assignments of an
        % exponent s_v to each endogenous variable such that scaling v -> lambda^{s_v}·v
        % leaves every static equation homogeneous. Each independent symmetry is a scale
        % freedom of the steady state; its invariant monomials are the "useful ratios"
        % (K/L, C/Y, ...) that make the system scale-free and can decouple the otherwise
        % large simultaneous core.
        %
        % Method: each static residual is expanded to a sum of monomials; homogeneity
        % requires the monomials of an equation to share a scaling degree (linear in the
        % s_v) and every nonlinear-call argument to have degree 0 (ast.scaling_degree).
        % Stacking these linear constraints gives a matrix C; null(C) is the space of
        % scale symmetries.
        %
        % OUTPUT:
        % - symmetries [struct array] one entry per independent scale symmetry (a basis
        %     vector of null(C)), each describing a CO-SCALING GROUP -- the variables
        %     that move together under that scale freedom:
        %       .vars       [cell]    symbols with a non-zero scaling exponent
        %       .exponents  [double]  their scaling exponents (normalised so first = +1)
        %   The scale-free (intensive) variables are the within-group ratios, e.g. two
        %   members v_i, v_j with equal exponent give the invariant ratio v_i / v_j.
        %   Called with no output, prints a readable summary of the co-scaling groups.
        %
        % REMARKS:
        % - Diagnostic only: it reports the ratios, it does not rewrite the model.
        % - Exponents that are parameters (x^alpha) are evaluated with the current
        %   calibration; an equation with a variable exponent or an unanalysable shape
        %   contributes no constraint and is counted as skipped in the summary.
        % - options.IncludeParameters [logical, default false]: also treat parameters
        %   as scaling variables. Explicit level parameters (a normalisation such as
        %   household_labour_supply_ss) PIN the scale, so on the pinned model no
        %   symmetry remains; letting the parameters scale reveals the LATENT scaling
        %   structure -- the invariant monomials then expose the useful ratios and the
        %   level parameters that fix the scale.
            arguments
                o
                options.IncludeParameters (1,1) logical = false
            end
            o.refresh_tables();
            scalable = o.var(:, modBuilder.COL_NAME);
            if options.IncludeParameters && ~isempty(o.params)
                scalable = [scalable; o.params(:, modBuilder.COL_NAME)];
            end
            nvar = numel(scalable);
            symmetries = struct('vars', {}, 'exponents', {});
            if nvar == 0
                return
            end
            var_index = dictionary(string(scalable(:)), (1:nvar)');

            % Symbol -> numeric value map for evaluating exponents.
            values = struct();
            for i = 1:size(o.params, 1)
                val = o.params{i, modBuilder.COL_VALUE};
                if isnumeric(val) && isscalar(val) && isfinite(val)
                    values.(o.params{i, modBuilder.COL_NAME}) = val;
                end
            end

            neq = size(o.equations, 1);
            C = zeros(0, nvar);
            n_skipped = 0;
            for i = 1:neq
                f = modBuilder.static_residual(o, i);
                if isempty(f)
                    n_skipped = n_skipped + 1;
                    continue
                end
                [~, cons, ok] = f.expand().scaling_degree(var_index, nvar, values);
                if ~ok
                    n_skipped = n_skipped + 1;
                    continue
                end
                for k = 1:numel(cons)
                    C(end+1, :) = cons{k}; %#ok<AGROW>
                end
            end

            % Scale symmetries = null space of the stacked constraints.
            if isempty(C)
                N = eye(nvar);
            else
                N = null(C, 'r');
            end

            tol = 1e-9;
            n_degenerate = 0;
            for j = 1:size(N, 2)
                s = N(:, j);
                nz = find(abs(s) > tol);
                if isempty(nz)
                    continue
                end
                s = s / s(nz(1));           % normalise: first non-zero exponent = 1
                s(abs(s) < tol) = 0;
                nz = find(abs(s) > tol);
                if numel(nz) < 2
                    % A single-symbol freedom is a symbol unconstrained by the steady
                    % state, not an invariant ratio; count it but do not report it.
                    n_degenerate = n_degenerate + 1;
                    continue
                end
                symmetries(end+1).vars = scalable(nz)'; %#ok<AGROW>
                symmetries(end).exponents = s(nz)';
            end

            if nargout == 0
                modBuilder.dprintf('Scale symmetries: %d invariant ratio(s), %d degenerate freedom(s) (%d equations, %d skipped)', ...
                    numel(symmetries), n_degenerate, neq, n_skipped);
                for j = 1:numel(symmetries)
                    vs = symmetries(j).vars; es = symmetries(j).exponents;
                    parts = cell(1, numel(vs));
                    for t = 1:numel(vs)
                        parts{t} = sprintf('%s^%g', vs{t}, es(t));
                    end
                    modBuilder.dprintf('  co-scaling group %d: %s', j, strjoin(parts, ' * '));
                end
                clear symmetries
            end
        end % function

        function o = apply_steady_plan(o, blocks, options)
        % Write the closed-form assignments produced by steady_plan into o.steady_state.
        %
        % INPUTS:
        % - o        [modBuilder]
        % - blocks   [struct array]   optional; if omitted, computed by o.steady_plan().
        % - options.GenerateHelpers  [logical] (default false) generate a numerical routine
        %            for every non-anchor block without a complete set of closed forms and
        %            register its call in the steady_state_model block (steady_call).
        % - options.Basename         [char]    base name of the generated routines, required
        %            with GenerateHelpers=true; a path prefix is honoured ('out/mymodel'
        %            writes out/mymodel_ssblock_<k>.m).
        % - options.Solver           [char]    'newton' (default) inlines a damped Newton
        %            iteration with the analytic Jacobian, making the helper self-contained;
        %            'dynare' delegates to dynare_solve -- the solver family distributed with
        %            Dynare, fsolve included via solve_algo = 0 -- reusing the running
        %            session's options_ with jacobian_flag set.
        % - options.SolveAlgo        [int]     with Solver='dynare', force options_.solve_algo
        %            inside the helper; when omitted the session's solve_algo applies.
        % - options.Tolerance        [double]  residual tolerance baked into the helper
        %            (default 1e-10; also passed as tolx to dynare_solve).
        % - options.MaxIterations    [int]     iteration cap baked into the helper (default 100).
        %
        % OUTPUTS:
        % - o        [modBuilder]     updated object with steady_state populated for each block
        %                             that has a closed form (and, under GenerateHelpers, a
        %                             block call registered for each one that has not).
        %
        % REMARKS:
        % - Iterates over the plan in topological order and calls m.steady(var, expr) for
        %   every block whose closed_form is complete.
        % - Without GenerateHelpers, a block with an incomplete closed_form writes whatever
        %   assignments it carries (possibly none); the user must provide the missing values
        %   manually (m.steady) or call m.solve_system. write() warns when the resulting
        %   steady_state_model block does not cover every endogenous variable.
        % - With GenerateHelpers, each non-anchor block without a complete closed_form is
        %   handed to a generated routine <Basename>_ssblock_<k>.m that solves its static
        %   system (residuals and analytic Jacobian inlined), and the steady_state_model
        %   block gains the multi-output call [x1, ..., xn] = <Basename>_ssblock_<k>(...)
        %   at its topological position -- Dynare accepts multi-output MATLAB functions
        %   there. Anchor blocks are left open: their levels are user-supplied by
        %   convention, and a unit-root process has no level to solve for.
        % - m.steady replaces an existing entry in place, so calling apply_steady_plan twice
        %   is idempotent for the closed-form blocks. Block calls are not replaced in place;
        %   regenerate on a fresh copy of the model when the plan changes.
            arguments
                o
                blocks = []
                options.GenerateHelpers (1,1) logical = false
                options.Basename (1,:) char = ''
                options.Solver (1,:) char {mustBeMember(options.Solver, {'newton', 'dynare'})} = 'newton'
                options.SolveAlgo double {mustBeScalarOrEmpty} = []
                options.Tolerance (1,1) double {mustBePositive} = 1e-10
                options.MaxIterations (1,1) double {mustBeInteger, mustBePositive} = 100
            end
            if options.GenerateHelpers && isempty(options.Basename)
                error('modBuilder:apply_steady_plan:missingBasename', 'GenerateHelpers=true requires the Basename option (it names the generated routines).');
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
            [helper_dir, helper_stem] = fileparts(options.Basename);
            for k = 1:numel(blocks)
                cf = blocks(k).closed_form;
                if ~options.GenerateHelpers || numel(cf) == numel(blocks(k).vars) || strcmp(blocks(k).kind, 'anchor')
                    for jj = 1:numel(cf)
                        o.steady(cf(jj).var, cf(jj).expr);
                    end
                else
                    funcname = sprintf('%s_ssblock_%d', helper_stem, k);
                    if ~isempty(blocks(k).reduced.vars)
                        % A stalled elimination left a reduced square system: the
                        % helper solves only the open variables, and the block's
                        % closed forms become the conditional epilogue, emitted as
                        % scalar rows that checksteady orders after the call.
                        outvars = blocks(k).reduced.vars;
                        res = cellfun(@(s) ast(s).strip_ss().simplify(), blocks(k).reduced.residuals, 'UniformOutput', false);
                        for jj = 1:numel(cf)
                            o.steady(cf(jj).var, cf(jj).expr);
                        end
                    else
                        % No reduction available (e.g. the block exceeded MaxBlockSize
                        % and no closure was attempted): solve the whole block.
                        outvars = blocks(k).vars;
                        res = cell(1, numel(outvars));
                        for jj = 1:numel(outvars)
                            idx = find(strcmp(blocks(k).eqnames{jj}, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
                            if isempty(idx)
                                error('modBuilder:apply_steady_plan:unknownEquation', 'Equation "%s" of the block is not in the model.', blocks(k).eqnames{jj});
                            end
                            f = modBuilder.static_residual(o, idx);
                            if isempty(f)
                                error('modBuilder:apply_steady_plan:badEquation', 'Equation "%s" cannot be parsed into a static residual.', blocks(k).eqnames{jj});
                            end
                            res{jj} = f.strip_ss().simplify();
                        end
                    end
                    argnames = o.generate_ss_helper(fullfile(helper_dir, [funcname '.m']), funcname, outvars, res, options.Solver, options.SolveAlgo, options.Tolerance, options.MaxIterations);
                    o.steady_call(outvars, sprintf('%s(%s)', funcname, strjoin(argnames, ', ')));
                end
            end
        end % function

        function argnames = generate_ss_helper(o, filepath, funcname, outvars, res, solver, solve_algo, tolf, maxit)
        % Generate the numerical routine solving one steady-state system; internal,
        % called by apply_steady_plan(GenerateHelpers=true).
        %
        % INPUTS:
        % - o          [modBuilder]
        % - filepath   [char]    destination .m file
        % - funcname   [char]    function name (file stem)
        % - outvars    [cell]    unknowns solved by the routine (the whole block, or the
        %                        open variables of its reduced system)
        % - res        [cell]    static residual asts of the system, one per unknown,
        %                        STEADY_STATE wrappers already stripped
        % - solver     [char]    'newton' (self-contained damped Newton) or 'dynare'
        %                        (delegate to dynare_solve with jacobian_flag set)
        % - solve_algo [double]  [] or the options_.solve_algo to force under 'dynare'
        % - tolf       [double]  residual tolerance baked into the file
        % - maxit      [double]  iteration cap baked into the file
        %
        % OUTPUTS:
        % - argnames   [cell]    symbols the helper takes as inputs, in signature order:
        %                        every symbol referenced by the residuals that is not an
        %                        unknown (upstream endogenous, parameters, exogenous).
        %                        The caller passes them by name from the
        %                        steady_state_model scope.
        %
        % REMARKS:
        % - The Jacobian is derived symbolically (ast.diff_ast), so the generated file
        %   has no dependency on modBuilder at run time -- and none at all beyond
        %   dynare_solve in the 'dynare' variant.
        % - The initial guess is the calibration of the unknowns at generation time
        %   (1 for variables without a finite value).
            nv = numel(outvars);
            argnames = {};
            for j = 1:nv
                sn = res{j}.symbol_names();
                for s = 1:numel(sn)
                    if ~ismember(sn{s}, outvars) && ~ismember(sn{s}, argnames)
                        argnames{end+1} = sn{s}; %#ok<AGROW>
                    end
                end
            end
            x0 = ones(nv, 1);
            for j = 1:nv
                vi = find(strcmp(outvars{j}, o.var(:, modBuilder.COL_NAME)), 1);
                if ~isempty(vi)
                    v = o.var{vi, modBuilder.COL_VALUE};
                    if isnumeric(v) && isscalar(v) && isfinite(v)
                        x0(j) = v;
                    end
                end
            end
            outlist = strjoin(outvars, ', ');
            arglist = strjoin(argnames, ', ');
            x0list = strjoin(arrayfun(@(v) num2str(v, 15), x0, 'UniformOutput', false), '; ');
            fid = fopen(filepath, 'w');
            if fid == -1
                error('modBuilder:generate_ss_helper:cannotWrite', 'Cannot open "%s" for writing.', filepath);
            end
            closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
            fprintf(fid, 'function [%s] = %s(%s)\n', outlist, funcname, arglist);
            fprintf(fid, '%% Steady-state block {%s} -- generated by modBuilder.apply_steady_plan (Solver=''%s'').\n', outlist, solver);
            fprintf(fid, '%% Solves the static system r(x) = 0 with the analytic Jacobian inlined below.\n');
            fprintf(fid, '%% Regenerate rather than edit.\n\n');
            fprintf(fid, 'x = [%s];\n', x0list);
            if strcmp(solver, 'newton')
                fprintf(fid, 'for it = 1:%d\n', maxit);
                fprintf(fid, '    [r, J] = block_system(x%s);\n', sprintf(', %s', argnames{:}));
                fprintf(fid, '    if max(abs(r)) < %g\n', tolf);
                fprintf(fid, '        break\n');
                fprintf(fid, '    end\n');
                fprintf(fid, '    dx = -(J\\r);\n');
                fprintf(fid, '    lambda = 1;\n');
                fprintf(fid, '    r0 = max(abs(r));\n');
                fprintf(fid, '    while lambda > 1/1024\n');
                fprintf(fid, '        rt = block_system(x + lambda*dx%s);\n', sprintf(', %s', argnames{:}));
                fprintf(fid, '        if all(isfinite(rt)) && all(isreal(rt)) && max(abs(rt)) < r0\n');
                fprintf(fid, '            break\n');
                fprintf(fid, '        end\n');
                fprintf(fid, '        lambda = lambda/2;\n');
                fprintf(fid, '    end\n');
                fprintf(fid, '    x = x + lambda*dx;\n');
                fprintf(fid, 'end\n');
                fprintf(fid, 'r = block_system(x%s);\n', sprintf(', %s', argnames{:}));
                fprintf(fid, 'if ~(max(abs(r)) < %g)\n', tolf);
                fprintf(fid, '    error(''%s:noConvergence'', ''No convergence after %d iterations (max residual %%g).'', max(abs(r)));\n', funcname, maxit);
                fprintf(fid, 'end\n');
            else
                fprintf(fid, 'global options_\n');
                fprintf(fid, 'if isempty(options_)\n');
                fprintf(fid, '    error(''%s:noDynareSession'', ''This helper delegates to dynare_solve and must run inside a Dynare session (global options_ is not set).'');\n', funcname);
                fprintf(fid, 'end\n');
                fprintf(fid, 'opts = options_;\n');
                fprintf(fid, 'opts.jacobian_flag = true;\n');
                if ~isempty(solve_algo)
                    fprintf(fid, 'opts.solve_algo = %d;\n', solve_algo);
                end
                fprintf(fid, '[x, errorflag] = dynare_solve(@block_system, x, %d, %g, %g, opts%s);\n', maxit, tolf, tolf, sprintf(', %s', argnames{:}));
                fprintf(fid, 'if errorflag\n');
                fprintf(fid, '    error(''%s:noConvergence'', ''dynare_solve failed on the steady-state block {%s}.'');\n', funcname, outlist);
                fprintf(fid, 'end\n');
            end
            for j = 1:nv
                fprintf(fid, '%s = x(%d);\n', outvars{j}, j);
            end
            fprintf(fid, 'end\n\n');
            fprintf(fid, 'function [r, J] = block_system(x%s)\n', sprintf(', %s', argnames{:}));
            for j = 1:nv
                fprintf(fid, '%s = x(%d);\n', outvars{j}, j);
            end
            fprintf(fid, 'r = zeros(%d, 1);\n', nv);
            for j = 1:nv
                fprintf(fid, 'r(%d) = %s;\n', j, res{j}.string());
            end
            fprintf(fid, 'J = zeros(%d, %d);\n', nv, nv);
            for i2 = 1:nv
                for j2 = 1:nv
                    % Simplify=false: the emitted Jacobian is machine read, and the
                    % full simplify costs an order of magnitude more than
                    % canonicalise for a tree of the same size. The second
                    % simplify() this call used to carry was a no-op anyway --
                    % diff_ast already returns a normalised tree.
                    d = res{i2}.diff_ast(outvars{j2}, 0, Simplify=false);
                    if ~ast.is_zero(d)
                        fprintf(fid, 'J(%d, %d) = %s;\n', i2, j2, d.string());
                    end
                end
            end
            fprintf(fid, 'end\n');
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
            equation = modBuilder.staticise_equation_string(o.equations{eqID, modBuilder.EQ_COL_EXPR});

            %
            % Build a single replacement table: every known symbol → its numeric value,
            % the unknown sname → 'x'. One regex pass over the equation, not one per symbol.
            %
            knownsymbols = setdiff([o.T.equations.(eqname), eqname], sname);
            replacements = struct();
            for i = 1:length(knownsymbols)
                replacements.(knownsymbols{i}) = num2str(o.get_value(knownsymbols{i}), 15);
            end
            replacements.(sname) = 'x';
            equation = modBuilder.substitute_symbols(equation, replacements);

            %
            % Set anonymous function
            %
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
            [x, fval, ~, flag] = solvers.newton(f, sinit, tol, maxit);
            if flag ~= 0
                error('modBuilder:solve:noConvergence', ...
                      'Newton solver failed to solve equation "%s" for symbol "%s" (flag=%d, residual=%g). No value was assigned.', ...
                      eqname, sname, flag, fval);
            end
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
        % - options.Method [char]         Jacobian method (default 'ad'):
        %                                    'ad'         — automatic differentiation (autoDiff1);
        %                                    'analytical' — analytical only; errors on an operator
        %                                                   with no differentiation rule;
        %                                    'auto'       — analytical where a differentiation
        %                                                   rule exists, automatic differentiation
        %                                                   per equation otherwise (warns once per
        %                                                   fallen-back equation);
        %                                    'numerical'  — finite-difference Jacobian.
        %
        % OUTPUTS:
        % - o              [modBuilder]   updated object with solved symbol values
        %
        % REMARKS:
        % - The system must be square (m equations, m unknowns).
        % - Symbols to solve for can be any mix of parameters, exogenous,
        %   and endogenous variables.
        % - Current symbol values are used as the initial guess.
        % - All methods use the same sparsity pattern from the symbol table; analytical and
        %   AD agree numerically, so the choice affects speed, not the solution.
        % - The default is 'ad': benchmarking showed AD is as fast or faster than the analytical
        %   path (parity on tiny systems, ~2× faster at scale), so analytical/auto are provided
        %   for an inspectable/symbolic Jacobian rather than speed. The analytical partials are
        %   still cached per equation (static_jacobian_cache, content-guarded on the equation
        %   text) so repeated analytical/auto solves do not re-differentiate; the cache is
        %   transient (not saved, empty after copy) and rebuilt lazily.
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
                options.Method (1,:) char {mustBeMember(options.Method, {'auto', 'analytical', 'ad', 'numerical'})} = 'ad'
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

            % Build closures for the solver. The residual is the same for every method;
            % the Jacobian depends on Method.
            residual_fn = @(x) eval_residuals(fhandles, x, m);
            switch options.Method
                case 'ad'
                    jacobian_fn = @(x) eval_jacobian(fhandles, incidence, x, n);
                case 'numerical'
                    jacobian_fn = @(x) eval_jacobian_fd(residual_fn, x, m, n);
                otherwise   % 'auto' or 'analytical'
                    jacobian_fn = o.analytical_jacobian_fn(eqnames, snames, incidence, fhandles, options.Method);
            end

            [xsol, fval, ~, flag] = solvers.newton_system(residual_fn, jacobian_fn, x0, options.tol, options.maxit);
            if flag ~= 0
                error('modBuilder:solve_system:noConvergence', ...
                      'Newton solver failed to solve the system for symbols {%s} (flag=%d, max|residual|=%g). No values were assigned.', ...
                      strjoin(snames, ', '), flag, max(abs(fval)));
            end

            % Write solution back
            for j = 1:n
                o.set_value(snames{j}, xsol(j));
            end
        end % function

        function jfn = analytical_jacobian_fn(o, eqnames, snames, incidence, fhandles, method)
        % Build a Jacobian closure that evaluates the analytical partials at a Newton iterate.
        % The per-equation strategy is assembled once here: each equation's static residual is
        % differentiated w.r.t. the symbols it contains, reusing partials from (and populating)
        % static_jacobian_cache so the diff_ast/simplify cost is paid once per equation across
        % calls. An equation whose residual uses an operator with no differentiation rule either
        % aborts (method='analytical') or falls back to automatic differentiation for that
        % equation only (method='auto'). The returned closure reuses the strategy across
        % Newton iterations.
            m = numel(eqnames);
            n = numel(snames);
            rows = cell(m, 1);            % rows{i}{j} = partial ast (set only where incidence(i,j))
            use_ad = false(m, 1);         % equations that fall back to automatic differentiation
            refsyms = {};                 % non-solve symbols referenced by the analytical partials
            for i = 1:m
                eq_idx = find(strcmp(eqnames{i}, o.equations(:, modBuilder.EQ_COL_NAME)), 1);
                if isempty(eq_idx)
                    error('modBuilder:solve_system:unknownEquation', 'No equation named "%s".', eqnames{i});
                end
                eqstr = o.equations{eq_idx, modBuilder.EQ_COL_EXPR};
                entry = o.static_jacobian_entry(eqnames{i}, eqstr);   % cached or fresh (content-guarded)

                if entry.fallback
                    % Already known to have no analytical Jacobian (cached decision).
                    use_ad(i) = true;
                    o.static_jacobian_cache(eqnames{i}) = entry;
                    continue
                end

                f = [];   % static residual built only on a cache miss
                rowasts = cell(1, n);
                ok = true;
                try
                    for j = 1:n
                        if incidence(i, j)
                            if entry.partials.isKey(snames{j})
                                rowasts{j} = entry.partials(snames{j}).ast;
                            else
                                if isempty(f), f = modBuilder.static_residual(o, eq_idx); end
                                g = f.diff_ast(snames{j});
                                entry.partials(snames{j}) = struct('ast', g);
                                rowasts{j} = g;
                            end
                        end
                    end
                catch err
                    if ~strcmp(err.identifier, 'ast:diff_ast:noRule')
                        rethrow(err);
                    end
                    ok = false;
                end

                if ok
                    rows{i} = rowasts;
                    for j = 1:n
                        if ~isempty(rowasts{j})
                            refsyms = [refsyms, rowasts{j}.symbol_names()]; %#ok<AGROW>
                        end
                    end
                else
                    entry.fallback = true;
                    if strcmp(method, 'analytical')
                        o.static_jacobian_cache(eqnames{i}) = entry;
                        error('modBuilder:solve_system:noAnalyticalJacobian', ...
                              ['Equation "%s" uses a function with no differentiation rule; ', ...
                               'use Method=''auto'' or Method=''ad''.'], eqnames{i});
                    end
                    use_ad(i) = true;
                    warning('modBuilder:solve_system:analyticalFallback', ...
                            'Equation "%s" has no analytical Jacobian (unsupported operator); falling back to AD for it.', eqnames{i});
                end
                o.static_jacobian_cache(eqnames{i}) = entry;   % write back (value-type dictionary)
            end
            % Fixed values for every non-solve symbol referenced, looked up once.
            refsyms = setdiff(unique(refsyms), snames);
            base = struct();
            for k = 1:numel(refsyms)
                base.(refsyms{k}) = o.get_value(refsyms{k});
            end
            jfn = @(x) eval_analytical_jacobian(rows, use_ad, base, snames, fhandles, incidence, x, m, n);
        end % function

        function entry = static_jacobian_entry(o, eqname, eqstr)
        % Return the static-Jacobian cache entry for eqname, or a fresh empty entry if absent
        % or stale (the stored equation string no longer matches eqstr — a content change).
        % The caller fills in partials / fallback and writes the entry back.
            if o.static_jacobian_cache.isKey(eqname)
                entry = o.static_jacobian_cache(eqname);
                if strcmp(entry.eqstr, eqstr)
                    return
                end
            end
            entry = struct('eqstr', eqstr, 'fallback', false, ...
                           'partials', configureDictionary("string", "struct"));
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
                [props, meths] = modBuilder.class_name_lists();
                if ismember(name, props)
                    p = o.(name);
                    S = modBuilder.shiftS(S, 1);
                elseif o.issymbol(name)
                    p = o.get_value(name);
                    S = modBuilder.shiftS(S, 1);
                elseif ismember(name, meths)
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

            [props, meths, mlist] = modBuilder.class_name_lists();
            if indexingContext == matlab.mixin.util.IndexingContext.Statement ...
                    && isequal(s(1).type, '.') ...
                    && ~ismember(s(1).subs, props)
                % Dot reference that is not a property — could be a method or symbol.
                % Check if it is a method with multiple outputs.
                idx = strcmp(s(1).subs, meths);
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

                % Explicit symbol check rather than try/catch on set_value: a blanket
                % catch would relabel ANY internal set_value failure as an unknown
                % symbol, misdiagnosing genuine errors.
                if ~o.issymbol(S(1).subs)
                    error('modBuilder:subsasgn:unknownSymbol', 'Unknown symbol ''%s''. Cannot assign to non-existent symbol.', S(1).subs);
                end
                o.set_value(S(1).subs, B);

            elseif isequal(S(1).type, '()')
                % Parentheses notation: o('endovar') = 'equation'
                % Only for changing equations (endogenous variables only)
                if ~ischar(S(1).subs{1})
                    error('modBuilder:subsasgn:badIndex', 'Wrong assignment (index must be a character array, a variable name).')
                end

                % Explicit lookup rather than try/catch on typeof (same rationale as
                % the dot branch above).
                [found, type] = o.lookup_symbol(S(1).subs{1});
                if ~found
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
    % Zero-seed dual vector built once; each column swaps its own seeded entry
    % in and out (O(n) constructions instead of O(n^2)).
    v_ad = cell(n, 1);
    for k = 1:n
        v_ad{k} = autoDiff1(x(k), 0.0);
    end
    for j = 1:n
        affected = find(incidence(:, j));
        if isempty(affected), continue; end
        v_ad{j} = autoDiff1(x(j), 1.0);
        for i = affected'
            r = fhandles{i}(v_ad);
            idx = idx + 1;
            II(idx) = i;
            JJ(idx) = j;
            VV(idx) = r.dx;
        end
        v_ad{j} = autoDiff1(x(j), 0.0);
    end
    J = sparse(II, JJ, VV, m, n);
end

function J = eval_jacobian_fd(residual_fn, x, m, n)
    % Forward finite-difference Jacobian, used by Method='numerical'.
    x = x(:);
    r0 = residual_fn(x);
    nnzJ = m * n;
    II = zeros(nnzJ, 1);
    JJ = zeros(nnzJ, 1);
    VV = zeros(nnzJ, 1);
    idx = 0;
    for j = 1:n
        step = 1e-7 * max(1, abs(x(j)));
        xp = x;
        xp(j) = xp(j) + step;
        col = (residual_fn(xp) - r0) / step;
        for i = 1:m
            idx = idx + 1;
            II(idx) = i;
            JJ(idx) = j;
            VV(idx) = col(i);
        end
    end
    J = sparse(II, JJ, VV, m, n);
end

function J = eval_analytical_jacobian(rows, use_ad, base, snames, fhandles, incidence, x, m, n)
    % Evaluate the precomputed analytical Jacobian at x. Analytical rows evaluate the stored
    % partial asts; rows marked use_ad fall back to autoDiff1 (Method='auto' only).
    x = x(:);
    values = base;
    for j = 1:n
        values.(snames{j}) = x(j);
    end
    nnzJ = nnz(incidence);
    II = zeros(nnzJ, 1);
    JJ = zeros(nnzJ, 1);
    VV = zeros(nnzJ, 1);
    idx = 0;
    % Zero-seed dual vector for the AD-fallback rows, built once; each entry
    % swaps its own seed in and out (O(n) constructions instead of O(n) per
    % Jacobian entry).
    v_ad = {};
    if any(use_ad)
        v_ad = cell(n, 1);
        for k = 1:n
            v_ad{k} = autoDiff1(x(k), 0.0);
        end
    end
    for i = 1:m
        if use_ad(i)
            affected = find(incidence(i, :));
            for j = affected
                v_ad{j} = autoDiff1(x(j), 1.0);
                r = fhandles{i}(v_ad);
                v_ad{j} = autoDiff1(x(j), 0.0);
                idx = idx + 1;
                II(idx) = i;
                JJ(idx) = j;
                VV(idx) = r.dx;
            end
        else
            ra = rows{i};
            for j = 1:n
                if ~isempty(ra{j})
                    idx = idx + 1;
                    II(idx) = i;
                    JJ(idx) = j;
                    VV(idx) = ra{j}.eval(values);
                end
            end
        end
    end
    J = sparse(II(1:idx), JJ(1:idx), VV(1:idx), m, n);
end
