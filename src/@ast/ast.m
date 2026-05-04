classdef ast
% Abstract syntax tree for modBuilder equations.
%
% USAGE:
%   t = ast('alpha*GDP(-1) + beta')   build a tree from an equation string
%   t.string()                     render the tree back to a string
%   t.staticise()                     collapse all time subscripts (x(±k) → x)
%   t.substitute('alpha', '1-gamma')  replace a symbol by an AST subtree (lag-aware;
%                                     pass the parameter names as a 4th argument to
%                                     keep them time-invariant in the replacement)
%   t.shift_lag(-1, {'alpha'})        lag-shift every variable, skipping parameters
%   [has, cancels] = t.check_factor('alpha')
%                                     test whether a variable appears as a
%                                     common multiplicative factor of the tree
%
% Node types:
%   'num'    numeric literal (e.g. 0.33, 1e-5)
%            value = double scalar                children = {}
%   'sym'    bare symbol — parameter, endogenous or exogenous variable at the
%            current period, with no time subscript (e.g. alpha, GDP)
%            value = char (name)                  children = {}
%   'tsym'   time-subscripted variable: a lead or lag of an endogenous or
%            exogenous variable (e.g. Consumption(-1), K(+1)). The lag is
%            stored as a non-zero signed integer; lag 0 collapses to 'sym'.
%            value = {name, lag}                  children = {}
%   'ss'     steady-state operator on a symbol (STEADY_STATE(x)). Treated as
%            a constant w.r.t. the dynamic variable x.
%            value = char (name)                  children = {}
%   'call'   function call: built-in mathematical function applied to one or
%            more arguments (exp(x), log(a+b), max(a, b)). The function name
%            must belong to ast.RESERVED_FNAMES.
%            value = char (function name)         children = {arg1, arg2, ...}
%   'binop'  binary arithmetic operator (+, -, *, /, ^). The exponent ^ is
%            right-associative; the others are left-associative.
%            value = char in {+, -, *, /, ^}      children = {left, right}
%   'uminus' unary minus, with precedence between * and ^ (so -x^2 means
%            -(x^2) and -x*y means (-x)*y).
%            value = []                           children = {operand}

    properties
        type = ''
        value = []
        children = {}
    end

    properties (Constant)
        % Reserved function names recognised by the parser as 'call' nodes.
        % Shared with modBuilder.DYNARE_RESERVED_NAMES (see
        % dynare_reserved_function_names.m for the single source of truth).
        % STEADY_STATE is included in the list but parse_atom handles it with
        % a dedicated branch before the ismember test, so it always produces
        % a dedicated 'ss' node rather than a 'call' node.
        RESERVED_FNAMES = dynare_reserved_function_names()
    end

    methods

        function o = ast(varargin)
        % Build an ast node, either by parsing an equation string or by directly assembling a single node.
        %
        % INPUTS:
        % - varargin   [cell]    one of three accepted forms:
        %                          ()                          returns an empty node
        %                          (string)                    parses string into a tree
        %                          (type, value, children)     builds one node of the given type
        %                        See the class header for the layout of value and children
        %                        expected for each type.
        %
        % OUTPUTS:
        % - o          [ast]     root of the constructed tree
        %
        % REMARKS:
        % - The single-string form is the standard way to obtain a tree from an equation
        %   written in the modBuilder language.
        % - The three-argument form is used internally by the parser to assemble intermediate
        %   nodes; outside callers rarely need it.
            if nargin == 0
                % Empty node — relies on default property values.
                return
            end
            if nargin == 1
                % Parsing form. parse_expr returns a fully-built ast, which we
                % assign to o; this replaces the default-constructed node.
                str = char(varargin{1});
                tokens = ast.tokenise(str);
                if isempty(tokens)
                    error('ast:parse', 'Empty expression.');
                end
                [o, pos] = ast.parse_expr(tokens, 1);
                if pos <= length(tokens)
                    % Trailing tokens left over after parse_expr returned.
                    error('ast:parse', 'Unexpected token "%s" after position %d.', tokens{pos}.value, pos-1);
                end
                return
            end
            if nargin == 3
                % Direct construction. Used by the parser to assemble nodes
                % bottom-up; no validation of the shape (caller is trusted).
                o.type = varargin{1};
                o.value = varargin{2};
                o.children = varargin{3};
                return
            end
            error('ast:constructor', 'Wrong number of arguments.');
        end % function

        function str = string(o, parent_op, is_right)
        % Render tree back to a string with minimal parentheses.
        %
        % INPUTS:
        % - o          [ast]      node to render
        % - parent_op  [char]     (optional) operator of the parent node, in
        %                         {'+', '-', '*', '/', '^', 'uminus', ''} ('' means no parent /
        %                         top level). Used to decide whether to wrap the rendered
        %                         subtree in parentheses.
        % - is_right   [logical]  (optional) true iff this node is the right child of its
        %                         parent. Used together with parent_op to handle non-commutative
        %                         parent operators.
        %
        % OUTPUTS:
        % - str        [char]     1×n array, the rendered expression
        %
        % REMARKS:
        % - Outside callers should call string() with no extra arguments; parent_op and
        %   is_right are passed by recursive invocations on children.
        % - Round-trip: ast(t.string()) is structurally equal to t for every tree t built
        %   by the parser (verified in tests/ast/t06).
        % - The parenthesisation rules guarantee that re-parsing the output yields the same
        %   tree, even for non-associative cases like (a^b)^c or a/(b/c).
            if nargin < 2, parent_op = ''; end
            if nargin < 3, is_right = false; end
            switch o.type
                case 'num'
                    % %.16g preserves enough precision to round-trip through str2double.
                    str = num2str(o.value, '%.16g');
                case 'sym'
                    str = o.value;
                case 'tsym'
                    % Defensive: lag 0 normally collapses to 'sym' at parse time, but
                    % handle it here too in case a 3-arg constructor created a tsym(_, 0).
                    if o.value{2} == 0
                        str = o.value{1};
                    else
                        str = sprintf('%s(%d)', o.value{1}, o.value{2});
                    end
                case 'ss'
                    str = sprintf('STEADY_STATE(%s)', o.value);
                case 'call'
                    args = cell(1, numel(o.children));
                    for i = 1:numel(o.children)
                        % Top-level context for each argument: a function call already
                        % delimits its content with parentheses, so no further wrapping needed.
                        args{i} = o.children{i}.string();
                    end
                    str = sprintf('%s(%s)', o.value, strjoin(args, ', '));
                case 'uminus'
                    % Tell the operand its parent has prec 3 (the precedence of unary minus
                    % itself) so a binop child knows to wrap iff its prec is < 3 (i.e. + - * /).
                    % A '^' child (prec 4) renders bare, giving e.g. -x^2 (= -(x^2)) as expected.
                    str = ['-' o.children{1}.string('uminus', false)];
                    % If our parent is '^' (prec 4 > 3), wrap the whole "-x" so we get
                    % (-x)^y instead of -x^y (which would re-parse as -(x^y)).
                    if ast.op_precedence(parent_op) > 3
                        str = ['(' str ')'];
                    end
                case 'binop'
                    op = o.value;
                    L = o.children{1};
                    R = o.children{2};
                    % Pretty-print canonical forms produced by canonicalise / simplify:
                    %   binop('+', L, uminus(Y))                    rendered as  L - Y
                    %   binop('*', L, binop('^', Y, num(-1)))       rendered as  L / Y
                    if strcmp(op, '+') && strcmp(R.type, 'uminus')
                        op = '-';
                        R = R.children{1};
                    elseif strcmp(op, '*') && strcmp(R.type, 'binop') && strcmp(R.value, '^') && ast.is_neg_one(R.children{2})
                        op = '/';
                        R = R.children{1};
                    end
                    cp = ast.op_precedence(op);
                    pp = ast.op_precedence(parent_op);
                    l = L.string(op, false);
                    r = R.string(op, true);
                    str = [l ' ' op ' ' r];
                    % Decide whether the rendered subtree must be wrapped to round-trip
                    % to the same tree shape after re-parsing. The two sources of
                    % ambiguity are precedence and same-precedence associativity.
                    parens = false;
                    if cp < pp
                        % Lower precedence than parent: wrap unconditionally.
                        parens = true;
                    elseif cp == pp
                        if strcmp(parent_op, '^')
                            % '^' is right-associative: same-prec left children must wrap
                            % so that (a^b)^c does not re-parse as a^(b^c).
                            parens = ~is_right;
                        else
                            % '+', '-', '*', '/' are left-associative: same-prec right
                            % children must wrap so that a-(b-c) does not re-parse as a-b-c.
                            parens = is_right;
                        end
                    end
                    if parens
                        str = ['(' str ')'];
                    end
                otherwise
                    error('ast:string', 'Unknown node type "%s".', o.type);
            end
        end % function

        function o = staticise(o)
        % Collapse all time subscripts to plain symbols (static version of the equation).
        %
        % INPUTS:
        % - o   [ast]   tree to staticise
        %
        % OUTPUTS:
        % - o   [ast]   same tree with every 'tsym' node replaced by a 'sym' node carrying
        %               the same name (the lag is dropped)
        %
        % REMARKS:
        % - Used to obtain the static version of a dynamic equation before checking whether
        %   a candidate endogenous variable cancels out (see check_factor).
        % - Other node types ('num', 'sym', 'ss', 'call', 'binop', 'uminus') are recursed
        %   into but otherwise unchanged.
            if strcmp(o.type, 'tsym')
                % tsym is the only leaf that knows about time; replace it with
                % a plain sym carrying the same name, dropping the lag.
                o = ast('sym', o.value{1}, {});
            else
                % Other leaves have no children to recurse into (loop is a no-op);
                % internal nodes propagate the transformation to every child.
                for i = 1:numel(o.children)
                    o.children{i} = o.children{i}.staticise();
                end
            end
        end % function

        function o = substitute(o, target_name, replacement, parameter_names)
        % Replace every occurrence of a symbol by an AST subtree, lag-aware.
        %
        % INPUTS:
        % - o                [ast]        tree to transform
        % - target_name      [char]       1×n array, name of the symbol to replace
        % - replacement      [ast | char] subtree to inline at every match. A char input
        %                                 is auto-parsed via ast(replacement).
        % - parameter_names  [cell]       (optional) 1×k cell array of symbol names that
        %                                 are time-invariant (typically the model's
        %                                 parameters). Names in this set are excluded
        %                                 from the lag-shift performed for tsym matches.
        %                                 Defaults to {}.
        %
        % OUTPUTS:
        % - o                [ast]        new tree with the substitution applied
        %
        % REMARKS:
        % - Matches both 'sym' and 'tsym' nodes carrying target_name. The match is
        %   exact (whole symbol nodes), so substring traps like substituting "k" inside
        %   "k_bar" cannot occur.
        % - Precedence is preserved by construction: the replacement is inlined as a
        %   subtree, and string() adds the right parentheses when re-stringifying.
        %   This fixes the precedence bug of strrep-based substitution (e.g. substituting
        %   x by y+z in a*x^2 correctly produces a*(y+z)^2 instead of a*y+z^2).
        % - For tsym matches, the replacement is lag-shifted by the matching tsym's
        %   lag before being inlined: substituting mc by w/mpl into pi - beta*mc(-1)
        %   produces pi - beta*(w(-1)/mpl(-1)). Names listed in parameter_names are
        %   skipped (kept time-invariant), and 'num' / 'ss' leaves are never shifted.
        % - 'ss' nodes (STEADY_STATE) in the host tree are leaves and are left
        %   untouched: the dynamic variable name they carry is not a substitution target.
            if ischar(replacement) || isstring(replacement)
                replacement = ast(char(replacement));
            end
            if nargin < 4
                parameter_names = {};
            end
            switch o.type
                case 'sym'
                    if strcmp(o.value, target_name)
                        % Lag 0: inline the replacement as-is.
                        o = replacement;
                    end
                case 'tsym'
                    if strcmp(o.value{1}, target_name)
                        % Shift the replacement by this match's lag, leaving any
                        % parameter (and num / ss) inside it time-invariant.
                        o = replacement.shift_lag(o.value{2}, parameter_names);
                    end
                otherwise
                    % All other node types either have no children (num, ss) — loop is
                    % a no-op — or carry expression children we recurse into.
                    for i = 1:numel(o.children)
                        o.children{i} = o.children{i}.substitute(target_name, replacement, parameter_names);
                    end
            end
        end % function

        function o = shift_lag(o, k, parameter_names)
        % Shift every time-varying variable's lag by k.
        %
        % INPUTS:
        % - o                [ast]      tree to shift
        % - k                [integer]  scalar lag offset (positive = lead, negative = lag)
        % - parameter_names  [cell]     (optional) 1×n cell array of names treated as
        %                               time-invariant (typically the model parameters).
        %                               Defaults to {}.
        %
        % OUTPUTS:
        % - o                [ast]      new tree with every sym/tsym variable shifted by k
        %
        % REMARKS:
        % - 'num' and 'ss' leaves are time-invariant and never shifted.
        % - A 'sym' carrying a non-parameter name becomes a 'tsym' with lag k; an
        %   existing 'tsym' becomes a 'tsym' with lag (its existing lag + k). When the
        %   resulting lag is 0, the node collapses back to a 'sym'.
        % - Names listed in parameter_names are kept untouched, regardless of whether
        %   they appear as 'sym' or (degenerately) as 'tsym'.
        % - k = 0 is a no-op.
            if nargin < 3
                parameter_names = {};
            end
            if k == 0
                return
            end
            switch o.type
                case 'num'
                    % constants are time-invariant
                case 'sym'
                    if ~ismember(o.value, parameter_names)
                        o = ast('tsym', {o.value, k}, {});
                    end
                case 'tsym'
                    if ~ismember(o.value{1}, parameter_names)
                        new_lag = o.value{2} + k;
                        if new_lag == 0
                            % Total lag is zero: collapse back to a plain sym so that
                            % rendering and structural comparison match a parser-built tree.
                            o = ast('sym', o.value{1}, {});
                        else
                            o = ast('tsym', {o.value{1}, new_lag}, {});
                        end
                    end
                case 'ss'
                    % steady-state values are time-invariant
                otherwise
                    for i = 1:numel(o.children)
                        o.children{i} = o.children{i}.shift_lag(k, parameter_names);
                    end
            end
        end % function

        function [has, cancels] = check_factor(o, varname)
        % Test whether varname is a common multiplicative factor of the tree.
        %
        % INPUTS:
        % - o        [ast]      tree to test
        % - varname  [char]     1×n array, name of the symbol to test
        %
        % OUTPUTS:
        % - has      [logical]  scalar, true iff varname appears anywhere in o
        % - cancels  [logical]  scalar, true iff varname appears only as a multiplicative
        %                       factor (i.e., the whole expression equals varname * f where
        %                       f does not depend on varname). Implies has.
        %
        % REMARKS:
        % - 'tsym' nodes match by name, so check_factor on a non-staticised tree treats x
        %   and x(-1) as the same symbol. Call staticise first if you want the static check.
        % - 'ss' nodes (STEADY_STATE) never match, since STEADY_STATE(x) is a constant w.r.t.
        %   the dynamic variable x.
        % - The test is purely structural: cases like w/w − ω that require algebraic
        %   simplification to detect a zero net power of w are not handled here. They will
        %   be covered by the follow-up simplify pass.
            switch o.type
                case {'num', 'ss'}
                    % Numeric literals and STEADY_STATE(_) are constants w.r.t. varname.
                    has = false;
                    cancels = false;
                case 'sym'
                    % A bare 'x' is trivially x*1, so cancels iff this is x.
                    has = strcmp(o.value, varname);
                    cancels = has;
                case 'tsym'
                    % Match by name only: x and x(-1) share the same multiplicative role
                    % once the equation is staticised.
                    has = strcmp(o.value{1}, varname);
                    cancels = has;
                case 'uminus'
                    % Sign flip preserves the multiplicative-factor structure.
                    [has, cancels] = o.children{1}.check_factor(varname);
                case 'call'
                    % varname appearing inside a non-linear function f(...) cannot be
                    % factored out of f; just report presence.
                    has = false;
                    for i = 1:numel(o.children)
                        if o.children{i}.check_factor(varname)
                            has = true;
                            break
                        end
                    end
                    cancels = false;
                case 'binop'
                    [lhas, lcanc] = o.children{1}.check_factor(varname);
                    [rhas, rcanc] = o.children{2}.check_factor(varname);
                    has = lhas || rhas;
                    switch o.value
                        case '*'
                            % Multiplication preserves cancellation: x*g cancels if x
                            % cancels in the side that contains it; x*x cancels iff
                            % both sides cancel (giving x^2 ⋅ rest).
                            if lhas && ~rhas
                                cancels = lcanc;
                            elseif rhas && ~lhas
                                cancels = rcanc;
                            elseif lhas && rhas
                                cancels = lcanc && rcanc;
                            else
                                cancels = false;
                            end
                        case '/'
                            % Numerator only: cancellation propagates from the numerator.
                            % Otherwise (denominator contains x, or both sides do) we
                            % conservatively say no — would require simplification.
                            if lhas && ~rhas
                                cancels = lcanc;
                            else
                                cancels = false;
                            end
                        case {'+', '-'}
                            % Additive split: x is a common factor only if it factors out
                            % of every term. If one side lacks x entirely, the whole sum
                            % is f + g(x-free) and x cannot be pulled out.
                            if lhas && rhas
                                cancels = lcanc && rcanc;
                            else
                                cancels = false;
                            end
                        case '^'
                            % x^n is itself a multiplicative factor; f^x with x in the
                            % exponent is transcendental in x and does not factor.
                            if lhas && ~rhas
                                cancels = lcanc;
                            else
                                cancels = false;
                            end
                    end
                otherwise
                    error('ast:check_factor', 'Unknown node type "%s".', o.type);
            end
        end % function

        function disp(o)
        % Compact display: print the rendered expression of the tree.
        %
        % INPUTS:
        % - o   [ast]   tree to display
            if isempty(o.type)
                fprintf('  ast (empty)\n\n');
            else
                fprintf('  ast: %s\n\n', o.string());
            end
        end % function

        function o = replace_subtree(o, target, replacement)
        % Replace every subtree of o that is structurally equal to target by replacement.
        %
        % INPUTS:
        % - o            [ast]    tree to transform
        % - target       [ast]    pattern to match
        % - replacement  [ast]    subtree to inline at every match
        %
        % OUTPUTS:
        % - o            [ast]    new tree with the substitution applied
        %
        % REMARKS:
        % - Both o and target are canonicalised once at entry, so commutative
        %   reorderings (a+b vs b+a, a*b vs b*a) match. Subsequent recursion descends
        %   the canonicalised tree.
        % - Matching is structural (ast.ast_equal). The MVP does not perform
        %   sub-multiset matching, so a target a+c is not found inside a+b+c
        %   (whose canonical left-associated tree exposes (a+b) and c, not (a+c)).
        %   The simplify or factor passes can sometimes reshape an equation to make
        %   the desired subtree appear.
        % - Used by modBuilder.inline when the substitution target is an arbitrary
        %   expression rather than a single symbol; for symbol targets, the
        %   ast.substitute primitive (lag-aware) is preferred.
            o = o.canonicalise();
            target = target.canonicalise();
            o = ast.replace_subtree_helper(o, target, replacement);
        end % function

        function o = canonicalise(o)
        % Return a canonical form of the tree.
        %
        % INPUTS:
        % - o   [ast]    tree to normalise
        %
        % OUTPUTS:
        % - o   [ast]    canonicalised tree:
        %                  - subtraction is rewritten as addition with a unary minus:
        %                    a - b becomes a + (-b)
        %                  - division is rewritten as multiplication by an inverse:
        %                    a / b becomes a * b^(-1)
        %                  - chains of '+' and '*' are flattened, the operands sorted by
        %                    a stable key (see ast.sort_key), then re-built into a left-
        %                    associated tree
        %
        % REMARKS:
        % - Used internally by simplify to make structurally equivalent expressions
        %   syntactically identical (so that, e.g., a*b - b*a → 0 is detected).
        % - The canonical tree uses 'uminus' and '^' rather than '-' and '/'. The
        %   string() renderer detects those patterns and pretty-prints them as '-' and
        %   '/' so the rendered output stays readable.
        % - Pure transformation; idempotent on inputs already in canonical form.
            for i = 1:numel(o.children)
                o.children{i} = o.children{i}.canonicalise();
            end
            if strcmp(o.type, 'uminus') && strcmp(o.children{1}.type, 'uminus')
                % --x → x
                o = o.children{1}.children{1};
            end
            if strcmp(o.type, 'binop') && strcmp(o.value, '-')
                % a - b → a + (-b), with the double-negation case a - (-b) → a + b
                % handled by ast.negate so we never construct uminus(uminus(_)).
                o = ast('binop', '+', {o.children{1}, ast.negate(o.children{2})});
            end
            if strcmp(o.type, 'binop') && strcmp(o.value, '/')
                % a / b → a · b^(-1), with the case a / b^(-1) → a · b handled by
                % ast.invert so we never construct (b^(-1))^(-1).
                o = ast('binop', '*', {o.children{1}, ast.invert(o.children{2})});
            end
            if strcmp(o.type, 'binop') && (strcmp(o.value, '+') || strcmp(o.value, '*'))
                op = o.value;
                operands = ast.flatten(o, op);
                operands = ast.cancel_pairs(operands, op);
                if strcmp(op, '+')
                    operands = ast.collect_like_terms(operands);
                else
                    operands = ast.collect_powers(operands);
                end
                if isempty(operands)
                    % All operands cancelled: '+'-chain reduces to 0, '*'-chain to 1.
                    if strcmp(op, '+')
                        o = ast('num', 0, {});
                    else
                        o = ast('num', 1, {});
                    end
                    return
                end
                if isscalar(operands)
                    o = operands{1};
                    return
                end
                keys = cellfun(@ast.sort_key, operands, 'UniformOutput', false);
                [~, idx] = sort(keys);
                operands = operands(idx);
                result = operands{1};
                for i = 2:numel(operands)
                    result = ast('binop', op, {result, operands{i}});
                end
                o = result;
            end
        end % function

        function o = simplify(o)
        % Return a simplified version of the tree (constant folding, identity rules,
        % structural cancellation).
        %
        % INPUTS:
        % - o   [ast]    tree to simplify
        %
        % OUTPUTS:
        % - o   [ast]    simplified tree, in canonical form (see canonicalise)
        %
        % REMARKS:
        % - Iterates canonicalise + a bottom-up rule pass until a fixed point is
        %   reached. The rule set is intentionally local; it covers:
        %     * constant folding (numeric-only binop)
        %     * additive identities (0+f → f, f+0 → f), multiplicative identities
        %       (0*f → 0, 1*f → f, f^0 → 1, f^1 → f, 1^f → 1)
        %     * structural cancellation across direct children
        %       (f − f → 0,  f / f → 1,  f + (−f) → 0,  f · f^(−1) → 1)
        %     * structural merging  (f + f → 2·f,  f · f → f^2)
        %     * double negation     (−(−f) → f, and −num → num(-num))
        % - Cases that need genuine algebraic insight (e.g. partial cancellation in
        %   long sums like a + b − a → b) are not handled by this MVP and may require
        %   pair-cancellation across flattened chains.
        % - The output preserves canonical form (with 'uminus' for subtraction and
        %   '^(-1)' for division). The string() renderer prints those as '-' and '/'.
            previous_key = '';
            while true
                o = o.canonicalise();
                key = ast.sort_key(o);
                if strcmp(key, previous_key)
                    break
                end
                previous_key = key;
                o = ast.simplify_pass(o);
            end
        end % function

        function o = expand(o)
        % Distribute multiplication over addition and unroll integer powers of sums.
        %
        % INPUTS:
        % - o   [ast]    tree to expand
        %
        % OUTPUTS:
        % - o   [ast]    expanded tree, in canonical form
        %
        % REMARKS:
        % - Applies the rules a · (b + c) → a·b + a·c, (a + b) · c → a·c + b·c, and
        %   (a + b)^n → (a + b) · (a + b) · ... (n times) for non-negative integer n,
        %   then re-canonicalises the result.
        % - Tree size grows: a product of k '+' chains of size m_i expands to a sum of
        %   ∏ m_i terms. Use deliberately on equations where the expanded form makes
        %   pair-cancellation or symbolic differentiation easier to read.
        % - Idempotent on already-expanded inputs (a sum of products).
            o = o.canonicalise();
            for i = 1:numel(o.children)
                o.children{i} = o.children{i}.expand();
            end
            % Expand a power of a sum directly via the multinomial theorem
            %   (a₁ + ... + a_k)^n = Σ (n choose m₁, ..., m_k) · a₁^m₁ · ... · a_k^m_k
            % over all non-negative integer multi-indices summing to n. Only the
            % distinct terms are emitted, each with its multinomial coefficient — so
            % no costly collect-like-terms pass is needed afterwards.
            if strcmp(o.type, 'binop') && strcmp(o.value, '^')
                base = o.children{1};
                exponent = o.children{2};
                if strcmp(exponent.type, 'num') && exponent.value >= 2 && rem(exponent.value, 1) == 0 && strcmp(base.type, 'binop') && strcmp(base.value, '+')
                    n = exponent.value;
                    summands = ast.flatten(base, '+');
                    k = numel(summands);
                    indices = ast.multi_indices(k, n);
                    nfac = factorial(n);
                    terms = cell(1, size(indices, 1));
                    for i = 1:size(indices, 1)
                        m = indices(i, :);
                        coef = nfac;
                        for j = 1:k
                            coef = coef / factorial(m(j));
                        end
                        factors = {};
                        if coef ~= 1
                            factors{end+1} = ast('num', coef, {});
                        end
                        for j = 1:k
                            if m(j) == 1
                                factors{end+1} = summands{j};
                            elseif m(j) > 1
                                factors{end+1} = ast('binop', '^', {summands{j}, ast('num', m(j), {})});
                            end
                        end
                        if isempty(factors)
                            terms{i} = ast('num', 1, {});
                        else
                            terms{i} = ast.product_of(factors);
                        end
                    end
                    o = ast.sum_of(terms).simplify();
                    return
                end
            end
            % Distribute '*' over any '+' operand sitting in this product.
            if strcmp(o.type, 'binop') && strcmp(o.value, '*')
                L = o.children{1};
                R = o.children{2};
                if strcmp(L.type, 'binop') && strcmp(L.value, '+')
                    terms = ast.flatten(L, '+');
                    products = cell(1, numel(terms));
                    for i = 1:numel(terms)
                        products{i} = ast('binop', '*', {terms{i}, R}).expand();
                    end
                    o = ast.sum_of(products).simplify();
                    return
                end
                if strcmp(R.type, 'binop') && strcmp(R.value, '+')
                    terms = ast.flatten(R, '+');
                    products = cell(1, numel(terms));
                    for i = 1:numel(terms)
                        products{i} = ast('binop', '*', {L, terms{i}}).expand();
                    end
                    o = ast.sum_of(products).simplify();
                    return
                end
            end
            o = o.simplify();
        end % function

        function o = factor(o)
        % Extract a common multiplicative factor from a sum.
        %
        % INPUTS:
        % - o   [ast]    tree to factor
        %
        % OUTPUTS:
        % - o   [ast]    factored tree, in canonical form
        %
        % REMARKS:
        % - For a '+' chain, finds factors that appear in every term (multiset
        %   intersection of the '*'-chain factor lists, with uminus(t) treated as
        %   (-1)·t for the purpose of factoring) and rewrites
        %     t1 + t2 + ... + tk = g · (r1 + r2 + ... + rk)
        %   where g is the common factor and ri = ti / g.
        % - Both structural common factors and numeric GCDs are pulled out:
        %     2·a·b + 2·a·c  →  2·a · (b + c)
        %     2·a·b − 2·a·c  →  2·a · (b − c)
        %   The numeric GCD is computed only when all decomposed coefficients are
        %   integer-valued; otherwise the coefficient factor stays at 1.
        % - The factor analysis does not understand power identities, so
        %   a² + a³ is not factored to a²·(1 + a). That is a deferred extension.
        % - Tree size shrinks (or stays the same). Idempotent.
            o = o.canonicalise();
            for i = 1:numel(o.children)
                o.children{i} = o.children{i}.factor();
            end
            if strcmp(o.type, 'binop') && strcmp(o.value, '+')
                operands = ast.flatten(o, '+');
                if numel(operands) < 2
                    return
                end
                % Decompose each operand into (coefficient, list of non-numeric factors).
                coefs = zeros(1, numel(operands));
                monomial_lists = cell(1, numel(operands));
                for i = 1:numel(operands)
                    [coefs(i), monomial_lists{i}] = ast.decompose_factors(operands{i});
                end
                % Multiset intersection of structural factors.
                common_monos = monomial_lists{1};
                for i = 2:numel(operands)
                    common_monos = ast.multiset_intersect(common_monos, monomial_lists{i});
                end
                % Numeric GCD across coefficients (only when all are integers).
                coef_gcd = 1;
                if all(coefs == round(coefs)) && any(coefs ~= 0)
                    g = abs(coefs(1));
                    for i = 2:numel(coefs)
                        g = gcd(g, abs(coefs(i)));
                    end
                    if g >= 1
                        coef_gcd = g;
                    end
                end
                if isempty(common_monos) && coef_gcd == 1
                    return
                end
                % Build residuals: (coef/g) · product(monomial_factors \ common_monos)
                residuals = cell(1, numel(operands));
                for i = 1:numel(operands)
                    leftover = ast.multiset_difference(monomial_lists{i}, common_monos);
                    new_coef = coefs(i) / coef_gcd;
                    pieces = {};
                    if new_coef ~= 1 || isempty(leftover)
                        pieces{end+1} = ast('num', new_coef, {}); %#ok<AGROW>
                    end
                    pieces = [pieces, leftover];
                    residuals{i} = ast.product_of(pieces);
                end
                residual_sum = ast.sum_of(residuals).simplify();
                common_factors = common_monos;
                if coef_gcd ~= 1
                    common_factors = [{ast('num', coef_gcd, {})}, common_factors];
                end
                factor_node = ast.product_of(common_factors).simplify();
                o = ast('binop', '*', {factor_node, residual_sum}).simplify();
            end
        end % function

    end % methods

    methods (Static)

        function tokens = tokenise(str)
        % Split an equation string into a flat list of tokens.
        %
        % INPUTS:
        % - str       [char]    1×n array, equation expression
        %
        % OUTPUTS:
        % - tokens    [cell]    1×m array of structs with fields 'type' and 'value'.
        %                       type is one of: 'number', 'symbol', 'plus', 'minus',
        %                       'times', 'divide', 'power', 'lparen', 'rparen', 'comma'.
        %                       value is the original character (for operators and
        %                       punctuation), the parsed double (for numbers), or the
        %                       identifier text (for symbols).
        %
        % REMARKS:
        % - Whitespace is skipped silently. Any other unrecognised character raises an
        %   error giving the offending character and its position in str.
        % - Numbers accept decimal and scientific notation (0.33, 1e-5, 1.5E+3).
        % - The tokeniser does not distinguish reserved function names from user
        %   identifiers; both come out as 'symbol'. Disambiguation happens in parse_atom
        %   based on the symbol name and the following token.
            tokens = {};
            n = length(str);
            i = 1;
            while i <= n
                c = str(i);
                if isspace(c)
                    i = i + 1;
                elseif c == '+'
                    tokens{end+1} = struct('type', 'plus', 'value', '+');
                    i = i + 1;
                elseif c == '-'
                    tokens{end+1} = struct('type', 'minus', 'value', '-');
                    i = i + 1;
                elseif c == '*'
                    tokens{end+1} = struct('type', 'times', 'value', '*');
                    i = i + 1;
                elseif c == '/'
                    tokens{end+1} = struct('type', 'divide', 'value', '/');
                    i = i + 1;
                elseif c == '^'
                    tokens{end+1} = struct('type', 'power', 'value', '^');
                    i = i + 1;
                elseif c == '('
                    tokens{end+1} = struct('type', 'lparen', 'value', '(');
                    i = i + 1;
                elseif c == ')'
                    tokens{end+1} = struct('type', 'rparen', 'value', ')');
                    i = i + 1;
                elseif c == ','
                    tokens{end+1} = struct('type', 'comma', 'value', ',');
                    i = i + 1;
                elseif c == '.' || (c >= '0' && c <= '9')
                    % Numeric literal: digits with at most one decimal point,
                    % optionally followed by an exponent ([eE][+-]?digits).
                    j = i;
                    seen_dot = false;
                    while j <= n && ((str(j) >= '0' && str(j) <= '9') || (str(j) == '.' && ~seen_dot))
                        if str(j) == '.', seen_dot = true; end
                        j = j + 1;
                    end
                    if j <= n && (str(j) == 'e' || str(j) == 'E')
                        j = j + 1;
                        if j <= n && (str(j) == '+' || str(j) == '-')
                            j = j + 1;
                        end
                        while j <= n && (str(j) >= '0' && str(j) <= '9')
                            j = j + 1;
                        end
                    end
                    num_str = str(i:j-1);
                    val = str2double(num_str);
                    % Guard against corner cases like a lone '.': str2double would
                    % return NaN, and a literal must contain at least one digit.
                    if isnan(val) || ~any(num_str >= '0' & num_str <= '9')
                        error('ast:tokenise', 'Invalid number "%s" at position %d.', num_str, i);
                    end
                    tokens{end+1} = struct('type', 'number', 'value', val);
                    i = j;
                elseif isletter(c) || c == '_'
                    % Identifier: starts with a letter or underscore, followed by
                    % any mix of letters, digits, and underscores. Reserved-vs-user
                    % disambiguation is the parser's job (see parse_atom).
                    j = i;
                    while j <= n && (isletter(str(j)) || (str(j) >= '0' && str(j) <= '9') || str(j) == '_')
                        j = j + 1;
                    end
                    tokens{end+1} = struct('type', 'symbol', 'value', str(i:j-1));
                    i = j;
                else
                    error('ast:tokenise', 'Unexpected character "%c" at position %d.', c, i);
                end
            end
        end % function

        function [node, pos] = parse_expr(tokens, pos)
        % Recursive-descent parser entry point: expr ::= term (('+'|'-') term)*
        %
        % INPUTS:
        % - tokens   [cell]     1×m array of token structs (output of tokenise)
        % - pos      [integer]  scalar, 1-based index of the next token to consume
        %
        % OUTPUTS:
        % - node     [ast]      parsed subtree
        % - pos      [integer]  scalar, index of the next unconsumed token after node
            [node, pos] = ast.parse_term(tokens, pos);
            while pos <= length(tokens) && (strcmp(tokens{pos}.type, 'plus') || strcmp(tokens{pos}.type, 'minus'))
                op = tokens{pos}.value;
                pos = pos + 1;
                [right, pos] = ast.parse_term(tokens, pos);
                node = ast('binop', op, {node, right});
            end
        end % function

        function [node, pos] = parse_term(tokens, pos)
        % Parse a multiplicative term: term ::= unary (('*'|'/') unary)*
        %
        % INPUTS:
        % - tokens   [cell]     1×m array of token structs (output of tokenise)
        % - pos      [integer]  scalar, 1-based index of the next token to consume
        %
        % OUTPUTS:
        % - node     [ast]      parsed subtree
        % - pos      [integer]  scalar, index of the next unconsumed token after node
            [node, pos] = ast.parse_unary(tokens, pos);
            while pos <= length(tokens) && (strcmp(tokens{pos}.type, 'times') || strcmp(tokens{pos}.type, 'divide'))
                op = tokens{pos}.value;
                pos = pos + 1;
                [right, pos] = ast.parse_unary(tokens, pos);
                node = ast('binop', op, {node, right});
            end
        end % function

        function [node, pos] = parse_unary(tokens, pos)
        % Parse an optional sign in front of a power: unary ::= '-' unary | '+' unary | power
        %
        % INPUTS:
        % - tokens   [cell]     1×m array of token structs (output of tokenise)
        % - pos      [integer]  scalar, 1-based index of the next token to consume
        %
        % OUTPUTS:
        % - node     [ast]      parsed subtree (wrapped in a 'uminus' node if a leading
        %                       minus was consumed; a leading plus is silently absorbed)
        % - pos      [integer]  scalar, index of the next unconsumed token after node
            if pos > length(tokens)
                error('ast:parse', 'Unexpected end of input.');
            end
            if strcmp(tokens{pos}.type, 'minus')
                % Recurse so that --x parses as uminus(uminus(x)); the recursion
                % bottoms out at parse_power (no extra uminus node otherwise).
                pos = pos + 1;
                [operand, pos] = ast.parse_unary(tokens, pos);
                node = ast('uminus', [], {operand});
            elseif strcmp(tokens{pos}.type, 'plus')
                % Leading '+' is absorbed silently: it would be a no-op uplus node.
                pos = pos + 1;
                [node, pos] = ast.parse_unary(tokens, pos);
            else
                [node, pos] = ast.parse_power(tokens, pos);
            end
        end % function

        function [node, pos] = parse_power(tokens, pos)
        % Parse a (right-associative) power expression: power ::= atom ('^' unary)?
        %
        % INPUTS:
        % - tokens   [cell]     1×m array of token structs (output of tokenise)
        % - pos      [integer]  scalar, 1-based index of the next token to consume
        %
        % OUTPUTS:
        % - node     [ast]      parsed subtree
        % - pos      [integer]  scalar, index of the next unconsumed token after node
        %
        % REMARKS:
        % - Right-associativity of '^' is realised by recursing through parse_unary on the
        %   right operand, so that a^b^c parses as a^(b^c).
            [node, pos] = ast.parse_atom(tokens, pos);
            if pos <= length(tokens) && strcmp(tokens{pos}.type, 'power')
                pos = pos + 1;
                % Right-associativity is realised by recursing through parse_unary
                % (rather than a left-folding while loop): a^b^c parses as a^(b^c).
                % This also lets a unary minus appear in the exponent (a^-b).
                [right, pos] = ast.parse_unary(tokens, pos);
                node = ast('binop', '^', {node, right});
            end
        end % function

        function [node, pos] = parse_atom(tokens, pos)
        % Parse a single atomic expression.
        %
        % INPUTS:
        % - tokens   [cell]     1×m array of token structs (output of tokenise)
        % - pos      [integer]  scalar, 1-based index of the next token to consume
        %
        % OUTPUTS:
        % - node     [ast]      parsed atom: 'num', 'sym', 'tsym', 'ss', 'call', or a
        %                       parenthesised sub-expression
        % - pos      [integer]  scalar, index of the next unconsumed token after node
        %
        % REMARKS:
        % - Grammar:
        %     atom ::= NUMBER
        %            | SYMBOL
        %            | SYMBOL '(' signed_int ')'
        %            | FNAME '(' expr (',' expr)* ')'
        %            | 'STEADY_STATE' '(' SYMBOL ')'
        %            | '(' expr ')'
        % - An identifier followed by '(' is disambiguated by name: 'STEADY_STATE' takes
        %   a bare symbol; names listed in ast.RESERVED_FNAMES become 'call' nodes; any
        %   other identifier expects a signed integer (the time subscript).
        % - A time subscript of 0 collapses to a plain 'sym' node (so x(0) and x are
        %   identical in the resulting tree).
            if pos > length(tokens)
                error('ast:parse', 'Unexpected end of input.');
            end
            tok = tokens{pos};
            switch tok.type
                case 'number'
                    node = ast('num', tok.value, {});
                    pos = pos + 1;
                case 'lparen'
                    % Parenthesised sub-expression: parens are a parsing aid and do not
                    % produce a node of their own — the inner tree stands in for them.
                    pos = pos + 1;
                    [node, pos] = ast.parse_expr(tokens, pos);
                    if pos > length(tokens) || ~strcmp(tokens{pos}.type, 'rparen')
                        error('ast:parse', 'Missing closing ")".');
                    end
                    pos = pos + 1;
                case 'symbol'
                    name = tok.value;
                    pos = pos + 1;
                    % An identifier with no following '(' is a bare symbol.
                    if pos > length(tokens) || ~strcmp(tokens{pos}.type, 'lparen')
                        node = ast('sym', name, {});
                        return
                    end
                    pos = pos + 1;
                    % Identifier followed by '(' has three possible meanings, resolved by
                    % the identifier name (lexically, no semantic table needed):
                    %   1. STEADY_STATE: dedicated 'ss' node, takes a single bare symbol.
                    %   2. Reserved function name: 'call' node, takes one or more expr args.
                    %   3. User identifier: 'tsym' node, takes a signed integer time subscript.
                    if strcmp(name, 'STEADY_STATE')
                        if pos > length(tokens) || ~strcmp(tokens{pos}.type, 'symbol')
                            error('ast:parse', 'STEADY_STATE expects a symbol argument.');
                        end
                        sname = tokens{pos}.value;
                        pos = pos + 1;
                        if pos > length(tokens) || ~strcmp(tokens{pos}.type, 'rparen')
                            error('ast:parse', 'STEADY_STATE: missing ")".');
                        end
                        pos = pos + 1;
                        node = ast('ss', sname, {});
                    elseif ismember(name, ast.RESERVED_FNAMES)
                        % Function call: collect at least one argument, then any
                        % comma-separated extras (for multi-arg calls like max(a, b)).
                        args = {};
                        [arg, pos] = ast.parse_expr(tokens, pos);
                        args{end+1} = arg;
                        while pos <= length(tokens) && strcmp(tokens{pos}.type, 'comma')
                            pos = pos + 1;
                            [arg, pos] = ast.parse_expr(tokens, pos);
                            args{end+1} = arg;
                        end
                        if pos > length(tokens) || ~strcmp(tokens{pos}.type, 'rparen')
                            error('ast:parse', '%s: missing ")".', name);
                        end
                        pos = pos + 1;
                        node = ast('call', name, args);
                    else
                        % Time subscript: optional explicit sign followed by an integer.
                        % We absorb the sign here (instead of letting parse_expr handle it
                        % via uminus) because the grammar requires a literal integer, not
                        % an arbitrary expression.
                        sign_mult = 1;
                        if pos <= length(tokens) && strcmp(tokens{pos}.type, 'plus')
                            pos = pos + 1;
                        elseif pos <= length(tokens) && strcmp(tokens{pos}.type, 'minus')
                            sign_mult = -1;
                            pos = pos + 1;
                        end
                        if pos > length(tokens) || ~strcmp(tokens{pos}.type, 'number')
                            error('ast:parse', 'Time subscript for "%s" must be an integer.', name);
                        end
                        lag_val = sign_mult * tokens{pos}.value;
                        if lag_val ~= round(lag_val)
                            error('ast:parse', 'Time subscript for "%s" must be an integer.', name);
                        end
                        pos = pos + 1;
                        if pos > length(tokens) || ~strcmp(tokens{pos}.type, 'rparen')
                            error('ast:parse', 'Missing closing ")" after time subscript.');
                        end
                        pos = pos + 1;
                        % Normalise x(0) → x so the renderer never has to emit a useless
                        % zero lag, and so structural equality treats them as the same.
                        if lag_val == 0
                            node = ast('sym', name, {});
                        else
                            node = ast('tsym', {name, lag_val}, {});
                        end
                    end
                otherwise
                    error('ast:parse', 'Unexpected token "%s".', tok.value);
            end
        end % function

        function b = ast_equal(a, c)
        % Test structural (syntactic) equality of two AST nodes.
        %
        % INPUTS:
        % - a   [ast]      first tree
        % - c   [ast]      second tree
        %
        % OUTPUTS:
        % - b   [logical]  scalar, true iff a and c are structurally equal
        %
        % REMARKS:
        % - Equality is purely syntactic: types, values, and children are compared
        %   recursively. Mathematically equivalent but syntactically different trees
        %   (e.g. a + b vs b + a) compare as unequal.
        % - Useful for round-trip tests and for the cancellation rules in the follow-up
        %   simplify pass that detects identical subtrees (e.g. f - f → 0).
            b = false;
            if ~strcmp(a.type, c.type), return; end
            if ~isequal(a.value, c.value), return; end
            if numel(a.children) ~= numel(c.children), return; end
            for i = 1:numel(a.children)
                if ~ast.ast_equal(a.children{i}, c.children{i}), return; end
            end
            b = true;
        end % function

        function p = op_precedence(op)
        % Operator precedence used by the renderer to decide on parenthesisation.
        %
        % INPUTS:
        % - op   [char]     operator name: '', '+', '-', '*', '/', 'uminus', '^'
        %
        % OUTPUTS:
        % - p    [integer]  scalar precedence level: 0 (no parent / atomic), 1 (additive),
        %                   2 (multiplicative), 3 (unary minus), 4 (power)
        %
        % REMARKS:
        % - Higher precedence binds tighter. Within additive (1) and multiplicative (2)
        %   operators, parent association is left; '^' (4) is right-associative.
        % - Used by string only; this table need not be extended for new node types
        %   unless they introduce a new infix operator.
            switch op
                case {'+', '-'}
                    p = 1;
                case {'*', '/'}
                    p = 2;
                case 'uminus'
                    p = 3;
                case '^'
                    p = 4;
                otherwise
                    p = 0;
            end
        end % function

        function o = replace_subtree_helper(o, target, replacement)
        % Recursive walk used by replace_subtree; assumes target and o are already
        % in canonical form so that ast.ast_equal captures commutative equivalence.
            if ast.ast_equal(o, target)
                o = replacement;
                return
            end
            for i = 1:numel(o.children)
                o.children{i} = ast.replace_subtree_helper(o.children{i}, target, replacement);
            end
        end % function

        function operands = flatten(o, op)
        % Flatten a chain of binop(op, ...) into a flat cell of operands.
        %
        % INPUTS:
        % - o    [ast]    tree to flatten
        % - op   [char]   binary operator to flatten ('+' or '*')
        %
        % OUTPUTS:
        % - operands  [cell]  1×k cell of subtrees that, combined with op, reproduce o
        %                     (up to commutativity).
        %
        % REMARKS:
        % - Used by canonicalise and simplify on commutative operators ('+', '*') to
        %   normalise the chain shape and detect identical / cancelling subtrees.
        % - For '+' chains, the function pushes a unary minus through inner '+' chains
        %   (uminus(a + b + c) → [-a, -b, -c]) so that pair-cancellation can find
        %   inverse operands across nested structure.
        % - For '*' chains, the function similarly pushes ^(-1) through inner '*' chains
        %   ((a · b · c)^(-1) → [a^(-1), b^(-1), c^(-1)]).
            if strcmp(o.type, 'binop') && strcmp(o.value, op)
                operands = [ast.flatten(o.children{1}, op), ast.flatten(o.children{2}, op)];
                return
            end
            if strcmp(op, '+') && strcmp(o.type, 'uminus') && strcmp(o.children{1}.type, 'binop') && strcmp(o.children{1}.value, '+')
                inner = ast.flatten(o.children{1}, '+');
                operands = cell(1, numel(inner));
                for i = 1:numel(inner)
                    operands{i} = ast.negate(inner{i});
                end
                return
            end
            if strcmp(op, '*') && strcmp(o.type, 'binop') && strcmp(o.value, '^') && ast.is_neg_one(o.children{2}) && strcmp(o.children{1}.type, 'binop') && strcmp(o.children{1}.value, '*')
                inner = ast.flatten(o.children{1}, '*');
                operands = cell(1, numel(inner));
                for i = 1:numel(inner)
                    operands{i} = ast.invert(inner{i});
                end
                return
            end
            operands = {o};
        end % function

        function n = negate(x)
        % Return the canonical negation of x: uminus(x), with double-negation removed.
            if strcmp(x.type, 'uminus')
                n = x.children{1};
            else
                n = ast('uminus', [], {x});
            end
        end % function

        function n = invert(x)
        % Return the canonical multiplicative inverse of x: x^(-1), or x.children{1}
        % when x is already y^(-1) (so applying invert twice is the identity).
            if strcmp(x.type, 'binop') && strcmp(x.value, '^') && ast.is_neg_one(x.children{2})
                n = x.children{1};
            else
                n = ast('binop', '^', {x, ast('num', -1, {})});
            end
        end % function

        function b = is_inverse_pair(x, y, op)
        % True iff x and y are inverse operands under op:
        %   '+': y is uminus(x) or x is uminus(y) (additive inverses)
        %   '*': y is x^(-1) or x is y^(-1)        (multiplicative inverses)
            switch op
                case '+'
                    b = (strcmp(y.type, 'uminus') && ast.ast_equal(x, y.children{1})) || ...
                        (strcmp(x.type, 'uminus') && ast.ast_equal(y, x.children{1}));
                case '*'
                    b = (strcmp(y.type, 'binop') && strcmp(y.value, '^') && ast.is_neg_one(y.children{2}) && ast.ast_equal(x, y.children{1})) || ...
                        (strcmp(x.type, 'binop') && strcmp(x.value, '^') && ast.is_neg_one(x.children{2}) && ast.ast_equal(y, x.children{1}));
                otherwise
                    b = false;
            end
        end % function

        function operands = cancel_pairs(operands, op)
        % Remove inverse pairs from a flat operand list of a '+' or '*' chain.
        % A linear scan with one-shot pairing per element; commutativity is exploited
        % by treating the operand list as a multiset.
            n = numel(operands);
            canceled = false(1, n);
            for i = 1:n
                if canceled(i), continue; end
                for j = i+1:n
                    if canceled(j), continue; end
                    if ast.is_inverse_pair(operands{i}, operands{j}, op)
                        canceled(i) = true;
                        canceled(j) = true;
                        break
                    end
                end
            end
            operands = operands(~canceled);
        end % function

        function [base, exp] = power_components(o)
        % Decompose o as base^exp.
        % - For binop('^', b, e), returns (b, e).
        % - Otherwise treats o as o^1 and returns (o, num(1)).
            if strcmp(o.type, 'binop') && strcmp(o.value, '^')
                base = o.children{1};
                exp = o.children{2};
            else
                base = o;
                exp = ast('num', 1, {});
            end
        end % function

        function [coef, monomial] = decompose_term(o)
        % Decompose o as coef · monomial, where coef is a numeric scalar pulled
        % out of any leading numeric factors (and any uminus contributes -1) and
        % monomial is the residual product of non-numeric factors.
        % - uminus(X)             →  -1 · X
        % - num · X · ...         →  num · (rest)
        % - X (no leading num)    →   1 · X
            if strcmp(o.type, 'uminus')
                [c, m] = ast.decompose_term(o.children{1});
                coef = -c;
                monomial = m;
                return
            end
            factors = ast.flatten(o, '*');
            coef = 1;
            monomial_factors = {};
            for i = 1:numel(factors)
                if strcmp(factors{i}.type, 'num')
                    coef = coef * factors{i}.value;
                else
                    monomial_factors{end+1} = factors{i}; %#ok<AGROW>
                end
            end
            if isempty(monomial_factors)
                monomial = ast('num', 1, {});
            else
                monomial = ast.product_of(monomial_factors);
            end
        end % function

        function [coef, monomial_factors] = decompose_factors(o)
        % Decompose o as coef · monomial_factors, where coef is a numeric scalar
        % collected from any leading numeric factors (and any uminus contributes
        % a -1) and monomial_factors is a cell-array list of the residual,
        % non-numeric factors. Used by factor for both the structural multiset
        % intersection and the numeric-GCD pass.
            if strcmp(o.type, 'uminus')
                [c, mf] = ast.decompose_factors(o.children{1});
                coef = -c;
                monomial_factors = mf;
                return
            end
            factors = ast.flatten(o, '*');
            coef = 1;
            monomial_factors = {};
            for i = 1:numel(factors)
                if strcmp(factors{i}.type, 'num')
                    coef = coef * factors{i}.value;
                else
                    monomial_factors{end+1} = factors{i}; %#ok<AGROW>
                end
            end
        end % function

        function operands = collect_like_terms(operands)
        % Combine like terms in a flattened '+' chain by summing the numeric
        % coefficients of operands that share a structurally equal monomial part.
        % Zero-total terms are dropped.
            n = numel(operands);
            if n < 2, return; end
            coefs = zeros(1, n);
            monomials = cell(1, n);
            for i = 1:n
                [coefs(i), monomials{i}] = ast.decompose_term(operands{i});
            end
            used = false(1, n);
            new_operands = {};
            for i = 1:n
                if used(i), continue; end
                c = coefs(i);
                for j = i+1:n
                    if used(j), continue; end
                    if ast.ast_equal(monomials{i}, monomials{j})
                        c = c + coefs(j);
                        used(j) = true;
                    end
                end
                used(i) = true;
                if c == 0
                    continue
                end
                m = monomials{i};
                if ast.is_one(m)
                    new_operands{end+1} = ast('num', c, {}); %#ok<AGROW>
                elseif c == 1
                    new_operands{end+1} = m; %#ok<AGROW>
                elseif c == -1
                    new_operands{end+1} = ast.negate(m); %#ok<AGROW>
                else
                    new_operands{end+1} = ast('binop', '*', {ast('num', c, {}), m}); %#ok<AGROW>
                end
            end
            operands = new_operands;
        end % function

        function operands = collect_powers(operands)
        % Combine powers in a flattened '*' chain by grouping operands with a
        % structurally equal base and summing their exponents (treating a bare X
        % as X^1). Zero-total exponents drop the operand (X^0 = 1).
            n = numel(operands);
            if n < 2, return; end
            bases = cell(1, n);
            exps = cell(1, n);
            for i = 1:n
                [bases{i}, exps{i}] = ast.power_components(operands{i});
            end
            used = false(1, n);
            new_operands = {};
            for i = 1:n
                if used(i), continue; end
                total = exps{i};
                for j = i+1:n
                    if used(j), continue; end
                    if ast.ast_equal(bases{i}, bases{j})
                        total = ast('binop', '+', {total, exps{j}});
                        used(j) = true;
                    end
                end
                used(i) = true;
                total_s = total.simplify();
                if ast.is_zero(total_s)
                    continue
                elseif ast.is_one(total_s)
                    new_operands{end+1} = bases{i}; %#ok<AGROW>
                else
                    new_operands{end+1} = ast('binop', '^', {bases{i}, total_s}); %#ok<AGROW>
                end
            end
            operands = new_operands;
        end % function

        function f = factors_of(o)
        % Return the multiplicative factors of o as a flat cell array.
        % - For a '*' chain, returns its flattened operand list.
        % - For uminus(x), returns [num(-1), factors_of(x)] so that the (-1) becomes
        %   visible to factor analysis.
        % - For anything else, returns {o}.
            if strcmp(o.type, 'uminus')
                f = [{ast('num', -1, {})}, ast.factors_of(o.children{1})];
                return
            end
            f = ast.flatten(o, '*');
        end % function

        function c = multiset_intersect(a, b)
        % Multiset intersection of two cell-array operand lists, using ast.ast_equal
        % for structural equality. Each element of b is consumed at most once.
            c = {};
            bcopy = b;
            for i = 1:numel(a)
                x = a{i};
                for j = 1:numel(bcopy)
                    if ast.ast_equal(x, bcopy{j})
                        c{end+1} = x; %#ok<AGROW>
                        bcopy(j) = [];
                        break
                    end
                end
            end
        end % function

        function d = multiset_difference(a, b)
        % Multiset difference a \ b: each element of b consumes at most one matching
        % element of a. Used to compute residuals after extracting a common factor.
            bcopy = b;
            d = {};
            for i = 1:numel(a)
                x = a{i};
                found = false;
                for j = 1:numel(bcopy)
                    if ast.ast_equal(x, bcopy{j})
                        bcopy(j) = [];
                        found = true;
                        break
                    end
                end
                if ~found
                    d{end+1} = x; %#ok<AGROW>
                end
            end
        end % function

        function p = product_of(factors)
        % Build a '*' chain from a cell of factors.
        % An empty list returns num(1) (the multiplicative identity).
            if isempty(factors)
                p = ast('num', 1, {});
                return
            end
            p = factors{1};
            for i = 2:numel(factors)
                p = ast('binop', '*', {p, factors{i}});
            end
        end % function

        function indices = multi_indices(k, n)
        % Generate all non-negative integer vectors (m1, ..., m_k) summing to n.
        %
        % Used by expand to apply the multinomial theorem directly without going
        % through k^n raw products.
        %
        % INPUTS:
        % - k        [integer]  scalar, number of slots (>= 1)
        % - n        [integer]  scalar, target sum (>= 0)
        %
        % OUTPUTS:
        % - indices  [integer]  C(n+k-1, k-1) × k matrix; each row is a valid
        %                       multi-index.
            if k == 1
                indices = n;
                return
            end
            indices = zeros(0, k);
            for i = 0:n
                sub = ast.multi_indices(k-1, n-i);
                col = repmat(i, size(sub, 1), 1);
                indices = [indices; [col, sub]]; %#ok<AGROW>
            end
        end % function

        function s = sum_of(terms)
        % Build a '+' chain from a cell of terms.
        % An empty list returns num(0) (the additive identity).
            if isempty(terms)
                s = ast('num', 0, {});
                return
            end
            s = terms{1};
            for i = 2:numel(terms)
                s = ast('binop', '+', {s, terms{i}});
            end
        end % function

        function k = sort_key(o)
        % Return a stable string sort key used to order operands of commutative chains.
        %
        % INPUTS:
        % - o   [ast]    node to key
        %
        % OUTPUTS:
        % - k   [char]   1×n string. Lexicographic order on these keys gives the canonical
        %                operand order: numbers first, then symbols, then steady-state, then
        %                negations, then function calls, then compound binops.
            switch o.type
                case 'num'
                    k = sprintf('0_num_%.17g', o.value);
                case 'sym'
                    k = sprintf('1_sym_%s', o.value);
                case 'tsym'
                    k = sprintf('1_sym_%s_%d', o.value{1}, o.value{2});
                case 'ss'
                    k = sprintf('2_ss_%s', o.value);
                case 'uminus'
                    k = sprintf('3_neg_%s', ast.sort_key(o.children{1}));
                case 'call'
                    parts = '';
                    for i = 1:numel(o.children)
                        parts = [parts '_' ast.sort_key(o.children{i})]; %#ok<AGROW>
                    end
                    k = sprintf('4_call_%s%s', o.value, parts);
                case 'binop'
                    k = sprintf('5_binop_%s_%s_%s', o.value, ast.sort_key(o.children{1}), ast.sort_key(o.children{2}));
                otherwise
                    k = '9_unknown';
            end
        end % function

        function b = is_zero(o)
        % True iff o is the numeric literal 0.
            b = strcmp(o.type, 'num') && o.value == 0;
        end % function

        function b = is_one(o)
        % True iff o is the numeric literal 1.
            b = strcmp(o.type, 'num') && o.value == 1;
        end % function

        function b = is_neg_one(o)
        % True iff o is the numeric literal -1.
            b = strcmp(o.type, 'num') && o.value == -1;
        end % function

        function o = simplify_pass(o)
        % Bottom-up application of local simplification rules. One pass; simplify()
        % wraps this in a fixed-point loop alternating with canonicalise.
            for i = 1:numel(o.children)
                o.children{i} = ast.simplify_pass(o.children{i});
            end
            o = ast.simplify_node(o);
        end % function

        function o = simplify_node(o)
        % Apply simplification rules at a single node (children assumed already simplified).
            switch o.type
                case 'uminus'
                    c = o.children{1};
                    if strcmp(c.type, 'num')
                        % -num → numeric negation
                        o = ast('num', -c.value, {});
                        return
                    end
                    if strcmp(c.type, 'uminus')
                        % --x → x
                        o = c.children{1};
                        return
                    end
                case 'binop'
                    L = o.children{1};
                    R = o.children{2};
                    % Constant folding (both children numeric)
                    if strcmp(L.type, 'num') && strcmp(R.type, 'num')
                        try
                            v = ast.eval_binop(o.value, L.value, R.value);
                            if isfinite(v) && isreal(v)
                                o = ast('num', v, {});
                                return
                            end
                        catch
                            % swallow domain errors (0^0, division by zero...) — leave as-is
                        end
                    end
                    switch o.value
                        case '+'
                            if ast.is_zero(L), o = R; return; end
                            if ast.is_zero(R), o = L; return; end
                            if strcmp(R.type, 'uminus') && ast.ast_equal(L, R.children{1})
                                % f + (-f) → 0
                                o = ast('num', 0, {}); return
                            end
                            if strcmp(L.type, 'uminus') && ast.ast_equal(R, L.children{1})
                                % (-f) + f → 0
                                o = ast('num', 0, {}); return
                            end
                            if ast.ast_equal(L, R)
                                % f + f → 2*f
                                o = ast('binop', '*', {ast('num', 2, {}), L}); return
                            end
                        case '-'
                            if ast.is_zero(R), o = L; return; end
                            if ast.is_zero(L), o = ast('uminus', [], {R}); return; end
                            if ast.ast_equal(L, R)
                                % f - f → 0
                                o = ast('num', 0, {}); return
                            end
                        case '*'
                            if ast.is_zero(L) || ast.is_zero(R)
                                o = ast('num', 0, {}); return
                            end
                            if ast.is_one(L), o = R; return; end
                            if ast.is_one(R), o = L; return; end
                            % (-1) · x  →  -x   (and x · (-1) → -x for safety; canonicalise
                            % normally puts the num on the left, so the first arm dominates).
                            if ast.is_neg_one(L), o = ast.negate(R); return; end
                            if ast.is_neg_one(R), o = ast.negate(L); return; end
                            % Propagate uminus out of '*' so that a sign always sits on top
                            % of its product:  L · (-R)  →  -(L · R),  (-L) · R  →  -(L · R).
                            if strcmp(L.type, 'uminus')
                                o = ast.negate(ast('binop', '*', {L.children{1}, R}));
                                return
                            end
                            if strcmp(R.type, 'uminus')
                                o = ast.negate(ast('binop', '*', {L, R.children{1}}));
                                return
                            end
                            % f * f^(-1) → 1
                            if strcmp(R.type, 'binop') && strcmp(R.value, '^') && ast.is_neg_one(R.children{2}) && ast.ast_equal(L, R.children{1})
                                o = ast('num', 1, {}); return
                            end
                            if strcmp(L.type, 'binop') && strcmp(L.value, '^') && ast.is_neg_one(L.children{2}) && ast.ast_equal(R, L.children{1})
                                o = ast('num', 1, {}); return
                            end
                            if ast.ast_equal(L, R)
                                % f * f → f^2
                                o = ast('binop', '^', {L, ast('num', 2, {})}); return
                            end
                        case '/'
                            if ast.is_zero(L), o = ast('num', 0, {}); return; end
                            if ast.is_one(R), o = L; return; end
                            if ast.ast_equal(L, R)
                                o = ast('num', 1, {}); return
                            end
                        case '^'
                            if ast.is_zero(R), o = ast('num', 1, {}); return; end
                            if ast.is_one(R), o = L; return; end
                            if ast.is_one(L), o = ast('num', 1, {}); return; end
                    end
            end
        end % function

        function v = eval_binop(op, a, b)
        % Evaluate a numeric-only binop. Used for constant folding inside simplify.
            switch op
                case '+', v = a + b;
                case '-', v = a - b;
                case '*', v = a * b;
                case '/', v = a / b;
                case '^', v = a ^ b;
                otherwise
                    error('ast:eval_binop', 'Unknown operator "%s".', op);
            end
        end % function

    end % methods (Static)

end % classdef
