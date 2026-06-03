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
            arguments
                o
                parent_op = ''
                is_right  = false
            end
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
            arguments
                o
                target_name
                replacement
                parameter_names = {}
            end
            if ischar(replacement) || isstring(replacement)
                replacement = ast(char(replacement));
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
            arguments
                o
                k
                parameter_names = {}
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

        function o = rename(o, oldname, newname)
        % Rename every reference to a symbol, preserving lag for tsym and the
        % steady-state operator wrapping for ss.
        %
        % INPUTS:
        % - o          [ast]    tree to rewrite
        % - oldname    [char]   1×n array, name to replace
        % - newname    [char]   1×m array, replacement name
        %
        % OUTPUTS:
        % - o          [ast]    new tree with every matching leaf renamed
        %
        % REMARKS:
        % - Matches 'sym' (sym(oldname) → sym(newname)), 'tsym' (the lag is
        %   preserved: tsym(oldname, k) → tsym(newname, k)) and 'ss'
        %   (STEADY_STATE(oldname) → STEADY_STATE(newname)).
        % - Distinct from substitute: that primitive replaces the whole symbol
        %   node with an arbitrary subtree (and lag-shifts the replacement);
        %   rename only swaps a name and is the right tool when the user wants
        %   to relabel a variable everywhere it appears.
        % - Function-call names (e.g. 'exp', 'log') are not touched.
            switch o.type
                case 'sym'
                    if strcmp(o.value, oldname)
                        o = ast('sym', newname, {});
                    end
                case 'tsym'
                    if strcmp(o.value{1}, oldname)
                        o = ast('tsym', {newname, o.value{2}}, {});
                    end
                case 'ss'
                    if strcmp(o.value, oldname)
                        o = ast('ss', newname, {});
                    end
                otherwise
                    for i = 1:numel(o.children)
                        o.children{i} = o.children{i}.rename(oldname, newname);
                    end
            end
        end % function

        function v = eval(o, values)
        % Evaluate the tree numerically given a struct mapping symbol names to scalar values.
        %
        % INPUTS:
        % - o        [ast]      tree to evaluate
        % - values   [struct]   one field per symbol; values.(name) is the scalar to substitute
        %                       for any 'sym', 'tsym' or 'ss' node carrying that name
        %
        % OUTPUTS:
        % - v        [double]   numeric value of the expression
        %
        % REMARKS:
        % - 'tsym' nodes are evaluated by their static value: the lag is ignored. This matches
        %   the modBuilder convention that residuals are computed at the steady state.
        % - 'ss' nodes look up the same field as 'sym' / 'tsym' (STEADY_STATE(x) and the static
        %   value of x are identical when values carries steady-state calibrations).
        % - 'call' nodes dispatch via feval; the function name has already been validated by the
        %   parser against ast.RESERVED_FNAMES.
            switch o.type
                case 'num'
                    v = o.value;
                case 'sym'
                    v = ast.lookup_value(o.value, values);
                case 'tsym'
                    v = ast.lookup_value(o.value{1}, values);
                case 'ss'
                    v = ast.lookup_value(o.value, values);
                case 'uminus'
                    v = -o.children{1}.eval(values);
                case 'binop'
                    a = o.children{1}.eval(values);
                    b = o.children{2}.eval(values);
                    v = ast.eval_binop(o.value, a, b);
                case 'call'
                    args = cell(1, numel(o.children));
                    for i = 1:numel(o.children)
                        args{i} = o.children{i}.eval(values);
                    end
                    v = feval(o.value, args{:});
                otherwise
                    error('ast:eval', 'Cannot evaluate node of type "%s".', o.type);
            end
        end % function

        function o = diff_ast(o, target_name, target_lag)
        % Symbolic derivative of the tree with respect to a symbol at a given period.
        %
        % INPUTS:
        % - o            [ast]      tree to differentiate
        % - target_name  [char]     1×n array, name of the symbol to differentiate w.r.t.
        % - target_lag   [integer]  (optional) period of the target, default 0. 0 targets the
        %                           current-period variable (the bare 'sym'); a non-zero value
        %                           targets that lead/lag (the matching 'tsym'), e.g.
        %                           diff_ast('K', -1) differentiates w.r.t. K(-1).
        %
        % OUTPUTS:
        % - o            [ast]      simplified derivative ∂o/∂target_name(target_lag)
        %
        % REMARKS:
        % - Differentiation is period-specific. With the default target_lag = 0, only bare
        %   'sym' nodes named target_name carry a non-zero derivative; a 'tsym' lead/lag such
        %   as K(-1) is an independent variable, so diff_ast(K(-1), 'K') is 0. Pass the lag
        %   explicitly (diff_ast('K', -1)) to differentiate w.r.t. that lead/lag instead; or
        %   staticise() first for steady-state (all-periods aggregated) semantics.
        % - 'ss' nodes (STEADY_STATE(x)) are constants and differentiate to 0.
        % - The result is passed through simplify() before returning; the raw chain-rule
        %   output is unreadable.
        % - Higher-order and mixed partials chain: t.diff_ast('x').diff_ast('y').
        % - abs, sign, min and max follow the autoDiff1 kink conventions: abs(u)' =
        %   sign(u)*u', sign(u)' = 0, and min/max are differentiated through the identity
        %   max(u,v) = (u+v+|u-v|)/2 (averaged sub-gradient at the tie u=v). Only the
        %   Dynare time-series operators diff, adl and EXPECTATIONS have no pointwise
        %   derivative and raise 'ast:diff_ast:noRule'. The Method='auto' solver path uses
        %   that as the signal to fall back to automatic differentiation.
            target_name = char(target_name);
            if nargin < 3
                target_lag = 0;
            end
            o = ast.diff_node(o, target_name, target_lag).simplify();
        end % function

        function str = to_latex(o, texname_map, dated, parent_op, is_right)
        % Render the tree as a LaTeX math expression.
        %
        % INPUTS:
        % - o            [ast]      node to render
        % - texname_map  [struct]   (optional) map from symbol name to its LaTeX form, e.g.
        %                           struct('alpha', '\alpha', 'K', 'K'). Names absent from the
        %                           map render literally. Defaults to an empty struct.
        % - dated        [cell]     (optional) names of dated (time-varying) variables. A bare
        %                           'sym' whose name is in this set is rendered with a current-
        %                           period subscript (y → y_t), so that current and lagged uses
        %                           read consistently (y_t, k_{t-1}). Parameters — names not in
        %                           the set — stay bare. Defaults to {} (no subscripts added).
        % - parent_op    [char]     (optional) parent operator, used internally by the recursion
        %                           to decide on parenthesisation; outside callers omit it.
        % - is_right     [logical]  (optional) true iff this node is the right child of its parent;
        %                           also internal.
        %
        % OUTPUTS:
        % - str          [char]     1×n array, the rendered LaTeX (math-mode contents, no $ … $)
        %
        % REMARKS:
        % - Outside callers use t.to_latex(), t.to_latex(map) or t.to_latex(map, dated);
        %   parent_op / is_right are passed by recursive invocations on children.
        % - Renders whatever tree it is given. Canonical-form patterns are pretty-printed the way
        %   string() does: a + (-b) → "a - b", and a · b^(-1) → \frac{a}{b}. A lone negative power
        %   (e.g. x^(-1)) is kept as x^{-1} rather than rewritten to a fraction, preserving the
        %   readability the steady-state forms rely on.
        % - tsym lags render as time subscripts (K(-1) → K_{t-1}); a bare sym listed in `dated`
        %   gets the current-period subscript (K → K_t); ss nodes as ·^{\star}
        %   (STEADY_STATE(K) → K^{\star}); exp as e^{·}; sqrt as \sqrt{·}; division as
        %   \frac{·}{·}; abs as \left|·\right|. Grouping uses \left( … \right) so tall content
        %   (fractions, powers) brackets correctly; a base that merely ends in a superscript
        %   (K^{\star}, e^{·}) raised to a power uses invisible \left. … \right. delimiters
        %   instead, e.g. STEADY_STATE(K)^2 → \left. K^{\star} \right.^{2}.
            arguments
                o
                texname_map = struct()
                dated = {}
                parent_op = ''
                is_right  = false
            end
            switch o.type
                case 'num'
                    str = ast.latex_num(o.value);
                case 'sym'
                    str = ast.latex_name(o.value, texname_map);
                    if ismember(o.value, dated)
                        str = [str '_t'];   % current-period subscript for a dated variable
                    end
                case 'tsym'
                    base = ast.latex_name(o.value{1}, texname_map);
                    if o.value{2} == 0
                        str = base;
                    else
                        str = sprintf('%s_{t%+d}', base, o.value{2});
                    end
                case 'ss'
                    % Steady-state variable: postfix superscript star, e.g. K^{\star}.
                    str = [ast.latex_name(o.value, texname_map) '^{\star}'];
                case 'call'
                    str = ast.latex_call(o, texname_map, dated);
                case 'uminus'
                    child = o.children{1};
                    cs = child.to_latex(texname_map, dated, '', false);
                    % Only an additive child needs parentheses under unary minus: -(a+b).
                    % A product or power does not (-a\,b and -x^{2} are unambiguous), so we
                    % drop string()'s round-trip parentheses here for cleaner paper output.
                    if strcmp(child.type, 'binop') && (strcmp(child.value, '+') || strcmp(child.value, '-'))
                        cs = ['\left(' cs '\right)'];
                    end
                    str = ['-' cs];
                    % Wrap the whole -… when the parent binds tighter than unary minus ('^').
                    if ast.op_precedence(parent_op) > 3
                        str = ['\left(' str '\right)'];
                    end
                case 'binop'
                    str = ast.latex_binop(o, texname_map, dated, parent_op, is_right);
                otherwise
                    error('ast:to_latex', 'Unknown node type "%s".', o.type);
            end
        end % function

        function tf = is_linear_in(o, x)
        % Test whether the tree is linear in symbol x.
        %
        % INPUTS:
        % - o   [ast]    tree to test
        % - x   [char]   1×n array, symbol name
        %
        % OUTPUTS:
        % - tf  [logical] true iff o = a · x + b structurally, with a and b independent of x.
        %
        % REMARKS:
        % - Canonicalises and simplifies the tree first, so a/b is rewritten as a·b^(-1),
        %   constants are folded, and obvious cancellations are removed.
        % - x is matched against 'sym' and 'tsym' leaves (lag is ignored, as expected
        %   for a static-equation analysis); 'ss' nodes are constants and never count
        %   as a use of x.
        % - x inside a 'call' (e.g. exp(x)), in a denominator, raised to a non-1 exponent,
        %   or appearing more than once in any single multiplicative chain, breaks linearity.
            o = o.canonicalise().simplify();
            [tf, ~] = ast.linear_walk(o, x);
        end % function

        function [a, b] = split_linear(o, x)
        % Split the tree into (a, b) such that o = a · x + b, with a and b independent of x.
        %
        % INPUTS:
        % - o   [ast]    tree (must be linear in x; check with is_linear_in first)
        % - x   [char]   1×n array, symbol name
        %
        % OUTPUTS:
        % - a   [ast]    coefficient tree (independent of x)
        % - b   [ast]    constant-term tree (independent of x)
        %
        % REMARKS:
        % - Errors with id 'ast:split_linear' if o is not linear in x.
        % - Both a and b are simplified before returning.
        % - Used by modBuilder.steady_plan to generate closed-form steady-state assignments
        %   for trivial / self-recursive blocks: from f(x) = LHS - RHS = 0, x = -b/a.
            if ~o.is_linear_in(x)
                error('ast:split_linear', 'Expression is not linear in "%s".', x);
            end
            o = o.canonicalise().simplify();
            % Use the substitution identity for an expression that is linear in x:
            %   b = expr at x = 0
            %   a = expr at x = 1 minus b
            % This is robust against any structure that passes is_linear_in (where x cannot
            % appear inside a call, in a denominator, or with a non-1 exponent — so x = 0
            % is always a valid evaluation point). Cleaner than a structural extraction
            % that assumes x sits at the top of a multiplicative chain, which can fail
            % after substitution + simplify pushes x deeper into a sub-expression.
            zero = ast('num', 0, {});
            one = ast('num', 1, {});
            b = o.substitute(x, zero).simplify();
            expr_at_one = o.substitute(x, one).simplify();
            a = ast('binop', '-', {expr_at_one, b}).simplify();
        end % function

        function tf = is_linear_in_set(o, vars)
        % Test whether the tree is jointly linear in the set of variable names vars.
        %
        % INPUTS:
        % - o      [ast]    tree to test
        % - vars   [cell]   1×n cell of char arrays, symbol names treated as unknowns
        %
        % OUTPUTS:
        % - tf     [logical] true iff every term of the canonical sum-of-products form
        %                    contains at most one occurrence of one of the vars (at the
        %                    top of its multiplicative chain, exponent 1, not inside a
        %                    call or denominator), with the rest of the term v-free.
        %
        % REMARKS:
        % - This is the multi-variable extension of is_linear_in: the same predicate
        %   applied to a *set*. A bilinear term like a·b is rejected when both a and b
        %   are in vars (whereas is_linear_in(a) would accept a·b, treating b as a
        %   constant coefficient).
        % - Used to recognise small linear systems in simultaneous SCCs and pass them
        %   to ast.linearise_system / ast.solve_linear_system for closed-form Cramer.
            o = o.canonicalise().simplify();
            [tf, ~] = ast.linear_set_walk(o, vars);
        end % function

        function tf = is_monomial_in(o, x)
        % Test whether the tree has the form α·x^d + β with α, β, d independent of x,
        % and at least one term containing x (so the split is meaningful).
        %
        % INPUTS:
        % - o   [ast]    tree to test
        % - x   [char]   symbol name
        %
        % OUTPUTS:
        % - tf  [logical] true iff o = α·x^d + β with α and d both x-free, x present.
        %
        % REMARKS:
        % - Canonicalises and simplifies first, so x · x^n → x^(n+1) and constant-folding
        %   are applied before the structural check.
        % - Each x-bearing term must be of the form coef · x or coef · x^d (possibly with
        %   uminus). All x-bearing terms must share the SAME exponent d.
        % - The d=1 case overlaps with is_linear_in; both return true for that case.
        % - x inside a 'call' (e.g. exp(x)), in a denominator, or appearing more than
        %   once in a single term breaks the monomial structure.
            o = o.canonicalise().simplify();
            terms = ast.flatten(o, '+');
            d_seen = [];
            has_x = false;
            for i = 1:numel(terms)
                t = terms{i};
                nx = ast.count_occurrences(t, x);
                if nx == 0
                    continue
                end
                if nx > 1
                    tf = false; return
                end
                [ok, ~, d_t] = ast.extract_monomial(t, x);
                if ~ok
                    tf = false; return
                end
                if isempty(d_seen)
                    d_seen = d_t;
                    has_x = true;
                elseif ~ast.ast_equal(d_seen, d_t)
                    tf = false; return
                end
            end
            tf = has_x;
        end % function

        function [a, d, b] = split_monomial(o, x)
        % Decompose o = a · x^d + b. Errors if not monomial in x.
        %
        % OUTPUTS:
        % - a   [ast]    coefficient of x^d (independent of x)
        % - d   [ast]    exponent (independent of x)
        % - b   [ast]    x-free additive constant
        %
        % REMARKS:
        % - The closed form for o = 0 is x = (-b/a)^(1/d).
        % - When several x-bearing terms share the same exponent (e.g. 2·x^d + 3·x^d),
        %   their coefficients are summed into a; this matches what split_linear does
        %   for d = 1.
            if ~o.is_monomial_in(x)
                error('ast:split_monomial', 'Expression is not monomial in "%s".', x);
            end
            o = o.canonicalise().simplify();
            terms = ast.flatten(o, '+');
            a_terms = {};
            b_terms = {};
            d = [];
            for i = 1:numel(terms)
                t = terms{i};
                if ast.count_occurrences(t, x) == 0
                    b_terms{end+1} = t; %#ok<AGROW>
                else
                    [~, coef, d_t] = ast.extract_monomial(t, x);
                    a_terms{end+1} = coef; %#ok<AGROW>
                    if isempty(d)
                        d = d_t;
                    end
                end
            end
            a = ast.sum_of(a_terms).simplify();
            b = ast.sum_of(b_terms).simplify();
        end % function

        function tf = is_invertible_call_in(o, x)
        % Test whether the tree has the form coef · f(P(x)) + rest with f ∈ {exp, log},
        % P(x) linear or monomial in x, and x not appearing elsewhere.
        %
        % REMARKS:
        % - The allowlist is intentionally small; multi-branch transcendentals (sin, cos)
        %   are excluded because their inverses are set-valued.
        % - Used by ast.isolate to unwrap exp/log wrappers around the unknown before
        %   delegating to the linear or monomial recogniser on the inverted equation.
            o = o.canonicalise().simplify();
            terms = ast.flatten(o, '+');
            x_term = [];
            for i = 1:numel(terms)
                t = terms{i};
                if ast.count_occurrences(t, x) > 0
                    if ~isempty(x_term)
                        tf = false; return
                    end
                    x_term = t;
                end
            end
            if isempty(x_term)
                tf = false; return
            end
            [tf, ~, ~, ~] = ast.extract_call_factor(x_term, x);
        end % function

        function [fname, P, coef, rest] = split_invertible_call(o, x)
        % Decompose o into (fname, P, coef, rest) such that o = coef · fname(P) + rest,
        % where fname ∈ {exp, log}, P is linear or monomial in x, and x appears nowhere
        % else. Errors if no such decomposition exists.
        %
        % REMARKS:
        % - Setting o = 0 gives fname(P) = -rest/coef, hence P = fname^{-1}(-rest/coef);
        %   ast.isolate then recurses on P - fname^{-1}(-rest/coef) to extract x.
            if ~o.is_invertible_call_in(x)
                error('ast:split_invertible_call', 'Expression is not in invertible-call form for "%s".', x);
            end
            o = o.canonicalise().simplify();
            terms = ast.flatten(o, '+');
            x_term = [];
            rest_terms = {};
            for i = 1:numel(terms)
                t = terms{i};
                if ast.count_occurrences(t, x) > 0
                    x_term = t;
                else
                    rest_terms{end+1} = t; %#ok<AGROW>
                end
            end
            [~, fname, P, coef] = ast.extract_call_factor(x_term, x);
            rest = ast.sum_of(rest_terms).simplify();
        end % function

        function rhs = isolate(o, x)
        % Try to isolate x from the equation o = 0, returning an AST tree for x or [].
        %
        % INPUTS:
        % - o   [ast]    tree representing the static residual; the equation is o = 0
        % - x   [char]   symbol name of the variable to isolate
        %
        % OUTPUTS:
        % - rhs [ast]    AST such that x = rhs is structurally equivalent, or [] if no
        %                recogniser applies.
        %
        % REMARKS:
        % - Tries the invertible-call recogniser first; if it succeeds, recurses on the
        %   inverted equation. Then the linear recogniser, then the monomial one. The
        %   order matters: unwrapping a call often exposes a linear or monomial pattern
        %   that the next recogniser then handles.
        % - Returns [] when the variable's coefficient folds to 0 (the equation does not
        %   actually pin x) or when none of the recognisers apply.
            o = o.canonicalise().simplify();

            % Invertible-call recogniser
            if o.is_invertible_call_in(x)
                [fname, P, coef, rest] = o.split_invertible_call(x);
                target = ast.neg_div(rest, coef);
                switch fname
                    case 'exp'
                        inv_target = ast('call', 'log', {target});
                    case 'log'
                        inv_target = ast('call', 'exp', {target});
                    otherwise
                        rhs = []; return
                end
                residual = ast('binop', '-', {P, inv_target});
                rhs = residual.isolate(x);
                return
            end

            % Linear recogniser
            if o.is_linear_in(x)
                [a, b] = o.split_linear(x);
                if ~(strcmp(a.type, 'num') && a.value == 0)
                    rhs = ast.neg_div(b, a).simplify();
                    return
                end
            end

            % Monomial recogniser
            if o.is_monomial_in(x)
                [a, d, b] = o.split_monomial(x);
                if ~(strcmp(a.type, 'num') && a.value == 0)
                    base = ast.neg_div(b, a);
                    inv_d = ast('binop', '/', {ast('num', 1, {}), d});
                    rhs = ast('binop', '^', {base, inv_d}).simplify();
                    return
                end
            end

            rhs = [];
        end % function

        function names = symbol_names(o)
        % Return the unique set of symbol names referenced in the tree.
        %
        % OUTPUTS:
        % - names   [cell]   1×k cell of unique char arrays, in encounter order
        %
        % REMARKS:
        % - Includes 'sym' (the name), 'tsym' (the variable name, lag dropped) and 'ss'
        %   (the wrapped name) leaves.
        % - Does NOT include 'call' function names (e.g. 'exp', 'log').
        % - Used by modBuilder.steady_plan to discover which endogenous variables a
        %   given equation depends on, regardless of lag.
            accum = {};
            accum = walk(o, accum);
            names = unique(accum, 'stable');

            function acc = walk(node, acc)
                switch node.type
                    case 'sym'
                        acc{end+1} = node.value;
                    case 'tsym'
                        acc{end+1} = node.value{1};
                    case 'ss'
                        acc{end+1} = node.value;
                    otherwise
                        for j = 1:numel(node.children)
                            acc = walk(node.children{j}, acc);
                        end
                end
            end
        end % function

        function lags = lags_of(o, name)
        % Return the sorted distinct periods at which symbol `name` appears: 0 for a bare
        % 'sym' (current period), the signed lag for each matching 'tsym'. Empty if `name`
        % does not appear. 'ss' (STEADY_STATE) nodes are constants and are not counted.
        % Used by the FOC builders to know which period-specific partials to take.
            acc = [];
            acc = walk(o, acc);
            lags = unique(acc);

            function acc = walk(node, acc)
                switch node.type
                    case 'sym'
                        if strcmp(node.value, name)
                            acc(end+1) = 0; %#ok<AGROW>
                        end
                    case 'tsym'
                        if strcmp(node.value{1}, name)
                            acc(end+1) = node.value{2}; %#ok<AGROW>
                        end
                    case {'num', 'ss'}
                        % no children to recurse / not counted
                    otherwise
                        for j = 1:numel(node.children)
                            acc = walk(node.children{j}, acc);
                        end
                end
            end
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

        function n = negate_sum(x)
        % Negate x. If x is a '+' chain, negate each term individually (so that
        % uminus is absorbed into already-uminus terms via ast.negate); otherwise
        % delegate to ast.negate. Used by callers that build "-b" from a b that
        % has the canonical form sum-of-(possibly-uminus) terms — a configuration
        % the local simplify pass cannot reduce further on its own.
            if strcmp(x.type, 'binop') && strcmp(x.value, '+')
                terms = ast.flatten(x, '+');
                negated = cell(1, numel(terms));
                for i = 1:numel(terms)
                    negated{i} = ast.negate(terms{i});
                end
                n = ast.sum_of(negated);
            else
                n = ast.negate(x);
            end
        end % function

        function r = neg_div(num, denom)
        % Build -num/denom with sign normalisation: when denom is uminus(d'), the two
        % minuses cancel and the result is num/d'. Otherwise this returns negate_sum(num)/denom.
        % The local simplify pass cannot reduce (-num)/(-d') because (-d')^(-1) does not fold to
        % -(d'^(-1)) in general — so callers that compute "-num/denom" need this helper to keep
        % the rendered closed form clean.
            if strcmp(denom.type, 'uminus')
                r = ast('binop', '/', {num, denom.children{1}});
            else
                r = ast('binop', '/', {ast.negate_sum(num), denom});
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
        % Implemented as a thin wrapper over decompose_factors that rebuilds the
        % residual factors into a product AST.
            [coef, monomial_factors] = ast.decompose_factors(o);
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
        % non-numeric factors. Canonical low-level implementation shared with
        % decompose_term and used directly by factor for both the structural
        % multiset intersection and the numeric-GCD pass.
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

        function [ok, n] = linear_walk(o, x)
        % Recursive walker used by ast.is_linear_in. Returns (ok, n):
        %   ok is true if the subtree is acceptable in a linear-in-x context.
        %   n  is the count of x occurrences (only meaningful when ok = true).
        % Caller is expected to have canonicalised the tree first, so a/b appears
        % as a·b^(-1) and uminus has been propagated upward where possible.
        % Thin wrapper over linear_walk_impl with a single-target predicate.
            [ok, n] = ast.linear_walk_impl(o, @(name) strcmp(name, x));
        end % function

        function [ok, n] = linear_set_walk(o, vars)
        % Multi-variable companion of linear_walk. Returns (ok, n) where n is the count
        % of leaves matching ANY name in vars; a term is rejected if it contains more
        % than one such leaf (bilinear) or has any of those leaves in a non-linear
        % position (inside a call, in a denominator, raised to a non-1 exponent).
        % Thin wrapper over linear_walk_impl with a set-membership predicate.
            [ok, n] = ast.linear_walk_impl(o, @(name) any(strcmp(name, vars)));
        end % function

        function [ok, n] = linear_walk_impl(o, is_target)
        % Shared implementation behind linear_walk and linear_set_walk.
        % is_target is a function handle name → logical that decides whether
        % a sym / tsym leaf counts as an occurrence of the target. All other
        % node-type handling is identical for the single-target and
        % set-membership variants — see the wrappers for the contract.
            switch o.type
                case 'num'
                    ok = true; n = 0;
                case 'sym'
                    ok = true; n = double(is_target(o.value));
                case 'tsym'
                    ok = true; n = double(is_target(o.value{1}));
                case 'ss'
                    ok = true; n = 0;
                case 'call'
                    n = 0;
                    for i = 1:numel(o.children)
                        [c_ok, c_n] = ast.linear_walk_impl(o.children{i}, is_target);
                        if ~c_ok || c_n > 0
                            ok = false; n = 0; return
                        end
                    end
                    ok = true;
                case 'uminus'
                    [ok, n] = ast.linear_walk_impl(o.children{1}, is_target);
                case 'binop'
                    L = o.children{1};
                    R = o.children{2};
                    switch o.value
                        case {'+', '-'}
                            [okL, nL] = ast.linear_walk_impl(L, is_target);
                            [okR, nR] = ast.linear_walk_impl(R, is_target);
                            ok = okL && okR; n = nL + nR;
                        case '*'
                            [okL, nL] = ast.linear_walk_impl(L, is_target);
                            [okR, nR] = ast.linear_walk_impl(R, is_target);
                            if ~okL || ~okR || (nL > 0 && nR > 0)
                                ok = false; n = 0;
                            else
                                ok = true; n = nL + nR;
                            end
                        case '/'
                            [okL, nL] = ast.linear_walk_impl(L, is_target);
                            [okR, nR] = ast.linear_walk_impl(R, is_target);
                            if ~okL || ~okR || nR > 0
                                ok = false; n = 0;
                            else
                                ok = true; n = nL;
                            end
                        case '^'
                            [okB, nB] = ast.linear_walk_impl(L, is_target);
                            [okE, nE] = ast.linear_walk_impl(R, is_target);
                            if ~okB || ~okE || nE > 0
                                ok = false; n = 0; return
                            end
                            if nB == 0
                                ok = true; n = 0;
                            elseif strcmp(R.type, 'num') && R.value == 1
                                ok = true; n = nB;
                            else
                                ok = false; n = 0;
                            end
                        otherwise
                            ok = false; n = 0;
                    end
                otherwise
                    ok = false; n = 0;
            end
        end % function

        function [coefs, const] = split_linear_set(o, vars)
        % Per-equation extractor for the multi-variable linear case. Returns coefs (a
        % 1×n cell of ASTs, one per var) and const (an AST) such that o equals
        % sum_j coefs{j}·vars{j} + const. Caller is expected to have verified the
        % expression is linear in the set via is_linear_in_set.
            o = o.canonicalise().simplify();
            terms = ast.flatten(o, '+');
            coef_terms_per = cell(1, numel(vars));
            for j = 1:numel(vars)
                coef_terms_per{j} = {};
            end
            const_terms = {};
            for i = 1:numel(terms)
                t = terms{i};
                which_var = -1;
                for j = 1:numel(vars)
                    if ast.count_occurrences(t, vars{j}) > 0
                        which_var = j;
                        break
                    end
                end
                if which_var == -1
                    const_terms{end+1} = t; %#ok<AGROW>
                else
                    coef = ast.peel_x(t, vars{which_var});
                    coef_terms_per{which_var}{end+1} = coef; %#ok<AGROW>
                end
            end
            coefs = cell(1, numel(vars));
            for j = 1:numel(vars)
                coefs{j} = ast.sum_of(coef_terms_per{j}).simplify();
            end
            const = ast.sum_of(const_terms).simplify();
        end % function

        function [ok, A, b] = linearise_system(residuals, vars)
        % Express the system { residuals{i} = 0 } as A · x + b = 0, with x the column
        % vector of vars.
        %
        % INPUTS:
        % - residuals  [cell]  1×n cell of ASTs (one per equation)
        % - vars       [cell]  1×n cell of variable names
        %
        % OUTPUTS:
        % - ok  [logical] true iff every residual is jointly linear in vars
        % - A   [cell]    n×n cell of ASTs; A{i,j} is the coefficient of vars{j} in residuals{i}
        % - b   [cell]    n×1 cell of ASTs; b{i} is the constant term of residuals{i}
        %
        % REMARKS:
        % - System must be square: numel(residuals) must equal numel(vars).
        % - On failure (any residual not jointly linear), returns ok = false and A, b = {}.
            n = numel(residuals);
            if n ~= numel(vars)
                error('ast:linearise_system', 'System must be square: %d residuals, %d variables.', ...
                      n, numel(vars));
            end
            A = cell(n, n);
            b = cell(n, 1);
            for i = 1:n
                if ~residuals{i}.is_linear_in_set(vars)
                    ok = false; A = {}; b = {}; return
                end
                [coefs, const] = ast.split_linear_set(residuals{i}, vars);
                for j = 1:n
                    A{i, j} = coefs{j};
                end
                b{i} = const;
            end
            ok = true;
        end % function

        function [U, sign_flip, singular] = bareiss_triangulate(M)
        % Fraction-free Gaussian elimination (Bareiss 1968) on an n×k cell matrix of
        % ASTs (k ≥ n; passing an augmented matrix [A | c] eliminates A and transforms c
        % in the same pass).
        %
        % OUTPUTS:
        % - U          [cell]    n×k cell matrix; the leading n×n block is upper-triangular
        % - sign_flip  [logical] true iff an odd number of row swaps were used (so that
        %                        det(A) = (-1)^sign_flip · U{n,n})
        % - singular   [logical] true iff a column had no non-zero pivot — the leading
        %                        n×n block is then structurally singular and U is left in
        %                        its partially-eliminated state
        %
        % The recurrence for entry (i,j), i,j > k, after k elimination steps:
        %   a_{ij}^{(k)} = (a_{kk}^{(k-1)} · a_{ij}^{(k-1)} − a_{ik}^{(k-1)} · a_{kj}^{(k-1)})
        %                  / a_{k-1,k-1}^{(k-2)}     with a_{0,0}^{(-1)} = 1.
        % The numerator is exactly divisible by the previous pivot by Bareiss's invariant;
        % at the AST level the division is delegated to simplify's pair-cancellation
        % across multiplicative chains. Partial row pivoting handles structurally-zero
        % diagonal entries (the swap flips sign_flip). Below-diagonal entries are zeroed
        % to mark elimination explicitly.
        %
        % Complexity: O(n^3) elimination steps; intermediate entries stay polynomial.
            n = size(M, 1);
            U = M;
            sign_flip = false;
            singular = false;
            if n <= 1
                return
            end
            prev_pivot = ast('num', 1, {});
            for k = 1:n-1
                pivot = U{k, k};
                if strcmp(pivot.type, 'num') && pivot.value == 0
                    swap_row = 0;
                    for r = k+1:n
                        cand = U{r, k};
                        if ~(strcmp(cand.type, 'num') && cand.value == 0)
                            swap_row = r;
                            break
                        end
                    end
                    if swap_row == 0
                        singular = true;
                        return
                    end
                    tmp = U(k, :); U(k, :) = U(swap_row, :); U(swap_row, :) = tmp;
                    sign_flip = ~sign_flip;
                    pivot = U{k, k};
                end
                for i = k+1:n
                    for j = k+1:size(U, 2)
                        num = ast('binop', '-', { ...
                            ast('binop', '*', {pivot, U{i, j}}), ...
                            ast('binop', '*', {U{i, k}, U{k, j}})});
                        if strcmp(prev_pivot.type, 'num') && prev_pivot.value == 1
                            U{i, j} = num.simplify();
                        else
                            U{i, j} = ast('binop', '/', {num, prev_pivot}).simplify();
                        end
                    end
                    U{i, k} = ast('num', 0, {});
                end
                prev_pivot = pivot;
            end
        end % function

        function d = symbolic_det(A)
        % Symbolic determinant via fraction-free Gaussian elimination (Bareiss 1968).
        % Calls ast.bareiss_triangulate(A) and reads ±U{n,n}.
        % Returns ast('num', 0, {}) when the matrix is structurally singular.
            n = size(A, 1);
            if n == 0
                d = ast('num', 1, {});
                return
            end
            [U, sign_flip, singular] = ast.bareiss_triangulate(A);
            if singular
                d = ast('num', 0, {});
                return
            end
            d = U{n, n};
            if sign_flip
                d = ast.negate(d);
            end
            d = d.simplify();
        end % function

        function rhs_list = solve_linear_system(A, b)
        % Solve A · x + b = 0 (i.e. A · x = -b) symbolically via Bareiss-triangulate
        % followed by back-substitution.
        %
        % INPUTS:
        % - A   [cell]   n×n cell matrix of ASTs
        % - b   [cell]   n×1 cell vector of ASTs
        %
        % OUTPUTS:
        % - rhs_list   [cell]   1×n cell of ASTs; rhs_list{i} is the closed form for
        %                       x_i, expressed in terms of:
        %                         - the original entries of A and -b,
        %                         - the symbol names vars{i+1}, …, vars{n} when the
        %                           caller wires this through (here we use the
        %                           triangular entries inline; modBuilder.steady_plan
        %                           rewires using vars_block to reference variables by
        %                           name in the generated steady_state_model block).
        %
        % REMARKS:
        % - The augmented matrix [A | -b] is triangulated in one Bareiss pass: U is the
        %   upper-triangular block and the (n+1)-th column is the transformed RHS c̃.
        % - Back-substitution: x_n = c̃_n / U_nn, x_i = (c̃_i − sum_{j>i} U_ij · x_j) / U_ii.
        %   The x_j substituted into x_i's expression is the AST for x_j (so the result
        %   is a single closed-form expression per variable, with no helper variables).
        % - When the system is structurally singular, returns a cell of empty arrays —
        %   caller is responsible for checking via ast.symbolic_det.
            n = numel(b);
            if n == 0
                rhs_list = {};
                return
            end
            M = [A, cell(n, 1)];
            for i = 1:n
                M{i, n+1} = ast.negate(b{i});
            end
            [U, ~, singular] = ast.bareiss_triangulate(M);
            if singular
                rhs_list = repmat({[]}, 1, n);
                return
            end
            rhs_list = cell(1, n);
            for i = n:-1:1
                rhs_i = U{i, n+1};
                for j = i+1:n
                    term = ast('binop', '*', {U{i, j}, rhs_list{j}});
                    rhs_i = ast('binop', '-', {rhs_i, term});
                end
                rhs_list{i} = ast('binop', '/', {rhs_i, U{i, i}}).simplify();
            end
        end % function

        function cf_list = iterated_elimination(residuals, vars, parameter_names)
        % Iterated symbolic elimination on a simultaneous block: try to isolate one
        % variable at a time via the linear / monomial / invertible-call recognisers
        % (ast.isolate), substitute the closed form into every other equation,
        % simplify, and repeat until the block is either fully resolved or no more
        % isolations succeed.
        %
        % INPUTS:
        % - residuals        [cell]   1×n cell of static-residual ASTs (one per
        %                             equation, paired with vars{i} = the variable
        %                             the equation pins in matchequations)
        % - vars             [cell]   1×n cell of variable name strings
        % - parameter_names  [cell]   (optional) names treated as time-invariant
        %                             during substitution; defaults to {}
        %
        % OUTPUTS:
        % - cf_list  [struct array]   .var (char), .expr (ast) for each variable that
        %                             got isolated, in *evaluation order*: the variable
        %                             eliminated last appears first in the array
        %                             (because its closed form does not reference any
        %                             other unresolved variable in the block).
        %
        % REMARKS:
        % - Greedy selection per iteration: prefer the (var, eq) pair that, on success,
        %   eliminates the most other-equation occurrences of var (highest "gain"); break
        %   ties on shorter rendered closed-form length.
        % - The closed form for an early-eliminated variable may reference other vars in
        %   the block that are eliminated later. The output ordering ensures the
        %   evaluation chain is well-defined: for steady_state_model emission, write the
        %   entries in the returned order so each assignment refers only to already-
        %   computed values.
        % - When some variables remain unresolved (no recogniser fires after any
        %   substitution), they are simply absent from cf_list. The caller can compare
        %   cf_list against the input vars to find the residual sub-block.
            arguments
                residuals
                vars
                parameter_names = {}
            end
            n = numel(residuals);
            cf_list = struct('var', {}, 'expr', {});
            if n == 0
                return
            end

            active = true(1, n);
            elim = struct('var', {}, 'expr', {});

            while any(active)
                active_idx = find(active);
                best_score = -inf;
                best_pos = -1;
                best_rhs = [];
                for ii = 1:numel(active_idx)
                    pos = active_idx(ii);
                    v = vars{pos};
                    f = residuals{pos};
                    if ast.count_occurrences(f, v) == 0
                        continue
                    end
                    rhs = f.isolate(v);
                    if isempty(rhs)
                        continue
                    end
                    gain = 0;
                    for jj = 1:numel(active_idx)
                        other = active_idx(jj);
                        if other ~= pos && ast.count_occurrences(residuals{other}, v) > 0
                            gain = gain + 1;
                        end
                    end
                    score = gain * 1e6 - length(rhs.string());
                    if score > best_score
                        best_score = score;
                        best_pos = pos;
                        best_rhs = rhs;
                    end
                end

                if best_pos == -1
                    break
                end

                v = vars{best_pos};
                for ii = 1:numel(active_idx)
                    other = active_idx(ii);
                    if other ~= best_pos
                        residuals{other} = residuals{other}.substitute(v, best_rhs, parameter_names).simplify();
                    end
                end
                elim(end+1).var = v; %#ok<AGROW>
                elim(end).expr = best_rhs;
                active(best_pos) = false;
            end

            for i = numel(elim):-1:1
                cf_list(end+1).var = elim(i).var; %#ok<AGROW>
                cf_list(end).expr = elim(i).expr;
            end
        end % function


        function n = count_occurrences(o, x)
        % Count occurrences of name x as a 'sym' or 'tsym' leaf in the tree.
        % 'ss' leaves are NOT counted (STEADY_STATE(x) is a constant w.r.t. x).
            switch o.type
                case 'sym'
                    n = double(strcmp(o.value, x));
                case 'tsym'
                    n = double(strcmp(o.value{1}, x));
                case {'num', 'ss'}
                    n = 0;
                otherwise
                    n = 0;
                    for i = 1:numel(o.children)
                        n = n + ast.count_occurrences(o.children{i}, x);
                    end
            end
        end % function

        function [ok, coef, d] = extract_monomial(t, x)
        % From a term containing x at most once, identify the structure t = coef · x^d.
        % Returns ok = false when the term cannot be matched (e.g. x inside a 'call',
        % x in a non-constant exponent, more than one x-bearing factor in a '*' chain).
            switch t.type
                case 'sym'
                    if strcmp(t.value, x)
                        ok = true; coef = ast('num', 1, {}); d = ast('num', 1, {});
                    else
                        ok = false; coef = []; d = [];
                    end
                case 'tsym'
                    if strcmp(t.value{1}, x)
                        ok = true; coef = ast('num', 1, {}); d = ast('num', 1, {});
                    else
                        ok = false; coef = []; d = [];
                    end
                case 'uminus'
                    [ok, inner_coef, d] = ast.extract_monomial(t.children{1}, x);
                    if ok
                        coef = ast.negate(inner_coef);
                    else
                        coef = [];
                    end
                case 'binop'
                    switch t.value
                        case '*'
                            factors = ast.flatten(t, '*');
                            nonx = {};
                            x_factor = [];
                            for k = 1:numel(factors)
                                f = factors{k};
                                if ast.count_occurrences(f, x) > 0
                                    if ~isempty(x_factor)
                                        ok = false; coef = []; d = []; return
                                    end
                                    x_factor = f;
                                else
                                    nonx{end+1} = f; %#ok<AGROW>
                                end
                            end
                            if isempty(x_factor)
                                ok = false; coef = []; d = []; return
                            end
                            [ok_inner, inner_coef, d_inner] = ast.extract_monomial(x_factor, x);
                            if ~ok_inner
                                ok = false; coef = []; d = []; return
                            end
                            coef_factors = nonx;
                            if ~(strcmp(inner_coef.type, 'num') && inner_coef.value == 1)
                                coef_factors{end+1} = inner_coef; %#ok<AGROW>
                            end
                            coef = ast.product_of(coef_factors);
                            d = d_inner;
                            ok = true;
                        case '^'
                            base = t.children{1};
                            exp_node = t.children{2};
                            if ast.count_occurrences(exp_node, x) > 0 || ast.count_occurrences(base, x) ~= 1
                                ok = false; coef = []; d = []; return
                            end
                            if (strcmp(base.type, 'sym') && strcmp(base.value, x)) || ...
                               (strcmp(base.type, 'tsym') && strcmp(base.value{1}, x))
                                ok = true; coef = ast('num', 1, {}); d = exp_node;
                            else
                                ok = false; coef = []; d = [];
                            end
                        otherwise
                            ok = false; coef = []; d = [];
                    end
                otherwise
                    ok = false; coef = []; d = [];
            end
        end % function

        function [ok, fname, P, coef] = extract_call_factor(t, x)
        % Identify a term as coef · f(P(x)) with f ∈ {exp, log} and x appearing only
        % inside f. Returns ok = false otherwise.
            switch t.type
                case 'call'
                    if (strcmp(t.value, 'exp') || strcmp(t.value, 'log')) && numel(t.children) == 1 && ...
                       ast.count_occurrences(t.children{1}, x) > 0
                        ok = true; fname = t.value; P = t.children{1}; coef = ast('num', 1, {});
                    else
                        ok = false; fname = ''; P = []; coef = [];
                    end
                case 'uminus'
                    [ok_inner, fname, P, inner_coef] = ast.extract_call_factor(t.children{1}, x);
                    if ok_inner
                        coef = ast.negate(inner_coef);
                        ok = true;
                    else
                        ok = false; coef = [];
                    end
                case 'binop'
                    if ~strcmp(t.value, '*')
                        ok = false; fname = ''; P = []; coef = []; return
                    end
                    factors = ast.flatten(t, '*');
                    nonx = {};
                    x_factor = [];
                    for k = 1:numel(factors)
                        f = factors{k};
                        if ast.count_occurrences(f, x) > 0
                            if ~isempty(x_factor)
                                ok = false; fname = ''; P = []; coef = []; return
                            end
                            x_factor = f;
                        else
                            nonx{end+1} = f; %#ok<AGROW>
                        end
                    end
                    if isempty(x_factor) || ~strcmp(x_factor.type, 'call') || ...
                       ~(strcmp(x_factor.value, 'exp') || strcmp(x_factor.value, 'log')) || ...
                       numel(x_factor.children) ~= 1
                        ok = false; fname = ''; P = []; coef = []; return
                    end
                    ok = true;
                    fname = x_factor.value;
                    P = x_factor.children{1};
                    coef = ast.product_of(nonx);
                otherwise
                    ok = false; fname = ''; P = []; coef = [];
            end
        end % function

        function c = peel_x(t, x)
        % Extract the coefficient of x from a term that contains x exactly once at the
        % top of its multiplicative chain (i.e. the term is a · x for some x-free a).
        %
        % This is the per-term extractor used inside ast.split_linear; the caller is
        % expected to have already verified the term is linear in x.
            switch t.type
                case 'sym'
                    if strcmp(t.value, x)
                        c = ast('num', 1, {});
                    else
                        error('ast:peel_x', 'Term has no x.');
                    end
                case 'tsym'
                    if strcmp(t.value{1}, x)
                        c = ast('num', 1, {});
                    else
                        error('ast:peel_x', 'Term has no x.');
                    end
                case 'uminus'
                    c = ast('uminus', [], {ast.peel_x(t.children{1}, x)});
                case 'binop'
                    switch t.value
                        case '*'
                            factors = ast.flatten(t, '*');
                            nonx = {};
                            found = 0;
                            for k = 1:numel(factors)
                                f = factors{k};
                                if (strcmp(f.type, 'sym') && strcmp(f.value, x)) || ...
                                   (strcmp(f.type, 'tsym') && strcmp(f.value{1}, x))
                                    found = found + 1;
                                else
                                    nonx{end+1} = f; %#ok<AGROW>
                                end
                            end
                            if found ~= 1
                                error('ast:peel_x', 'Expected exactly 1 x factor, got %d.', found);
                            end
                            c = ast.product_of(nonx);
                        case '/'
                            % After canonicalise this should not appear in well-formed input;
                            % defensive branch: extract from numerator, keep denominator (must be x-free).
                            L = t.children{1};
                            R = t.children{2};
                            if ast.count_occurrences(R, x) > 0
                                error('ast:peel_x', 'x in denominator — not linear.');
                            end
                            c = ast('binop', '/', {ast.peel_x(L, x), R});
                        otherwise
                            error('ast:peel_x', 'Unsupported binop "%s" in linear term.', t.value);
                    end
                otherwise
                    error('ast:peel_x', 'Unexpected node type "%s" in linear term.', t.type);
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

        function d = diff_node(node, target, target_lag)
        % Recursive symbolic differentiation of node w.r.t. the symbol target at period
        % target_lag (0 = current period / bare sym, non-zero = the matching tsym lead/lag).
        % Returns an UNSIMPLIFIED ast; the public diff_ast wrapper simplifies the result.
            switch node.type
                case 'num'
                    d = ast('num', 0, {});
                case 'sym'
                    % A bare symbol is the current-period (lag 0) variable.
                    if target_lag == 0 && strcmp(node.value, target)
                        d = ast('num', 1, {});
                    else
                        d = ast('num', 0, {});
                    end
                case 'tsym'
                    % A lead/lag matches only when both the name and the period agree.
                    if node.value{2} == target_lag && strcmp(node.value{1}, target)
                        d = ast('num', 1, {});
                    else
                        d = ast('num', 0, {});
                    end
                case 'ss'
                    % STEADY_STATE(x) is a constant w.r.t. the dynamic variable x.
                    d = ast('num', 0, {});
                case 'uminus'
                    d = ast('uminus', [], {ast.diff_node(node.children{1}, target, target_lag)});
                case 'binop'
                    d = ast.diff_binop(node, target, target_lag);
                case 'call'
                    d = ast.diff_call(node, target, target_lag);
                otherwise
                    error('ast:diff_ast:badNode', 'Cannot differentiate node of type "%s".', node.type);
            end
        end % function

        function d = diff_binop(node, target, target_lag)
        % Differentiate a binary-operator node by the standard calculus rules.
            op = node.value;
            u = node.children{1};
            v = node.children{2};
            du = ast.diff_node(u, target, target_lag);
            dv = ast.diff_node(v, target, target_lag);
            switch op
                case '+'
                    d = ast('binop', '+', {du, dv});
                case '-'
                    d = ast('binop', '-', {du, dv});
                case '*'
                    % Product rule: du*v + u*dv.
                    d = ast('binop', '+', {ast('binop', '*', {du, v}), ast('binop', '*', {u, dv})});
                case '/'
                    % Quotient rule: (du*v - u*dv) / v^2.
                    numerator = ast('binop', '-', {ast('binop', '*', {du, v}), ast('binop', '*', {u, dv})});
                    denominator = ast('binop', '^', {v, ast('num', 2, {})});
                    d = ast('binop', '/', {numerator, denominator});
                case '^'
                    d = ast.diff_power(u, v, du, dv, target);
                otherwise
                    error('ast:diff_ast:badOp', 'Cannot differentiate operator "%s".', op);
            end
        end % function

        function d = diff_power(u, v, du, dv, target)
        % Differentiate u^v, branching on which of base/exponent depends on target.
            u_const = ast.is_constant_wrt(u, target);
            v_const = ast.is_constant_wrt(v, target);
            if u_const && v_const
                d = ast('num', 0, {});
            elseif v_const
                % u^v with v constant: v * u^(v-1) * du.
                exponent = ast('binop', '-', {v, ast('num', 1, {})});
                power = ast('binop', '^', {u, exponent});
                d = ast('binop', '*', {ast('binop', '*', {v, power}), du});
            elseif u_const
                % a^v with a constant: a^v * log(a) * dv.
                power = ast('binop', '^', {u, v});
                d = ast('binop', '*', {ast('binop', '*', {power, ast('call', 'log', {u})}), dv});
            else
                % General u^v: u^v * (dv*log(u) + v*du/u).
                power = ast('binop', '^', {u, v});
                term1 = ast('binop', '*', {dv, ast('call', 'log', {u})});
                term2 = ast('binop', '*', {v, ast('binop', '/', {du, u})});
                bracket = ast('binop', '+', {term1, term2});
                d = ast('binop', '*', {power, bracket});
            end
        end % function

        function d = diff_call(node, target, target_lag)
        % Differentiate a single-argument function call by the chain rule: f'(g) * g'.
        % Raises 'ast:diff_ast:noRule' for functions without a differentiation rule.
            fname = node.value;
            arg = node.children{1};
            if strcmp(fname, 'sign')
                % sign is piecewise-constant: derivative is 0 wherever it is defined,
                % independent of the argument. (It is non-differentiable at the argument's
                % zeros — autoDiff1 errors there; the symbolic form returns 0, matching the
                % derivative value autoDiff1 gives everywhere else.) Short-circuit so a
                % non-differentiable argument does not need a rule.
                d = ast('num', 0, {});
                return
            end
            if strcmp(fname, 'max') || strcmp(fname, 'min')
                % max(u,v) = (u + v + |u-v|)/2 and min(u,v) = (u + v - |u-v|)/2, so via
                % the abs rule (abs(w)' = sign(w)*w'):
                %   max(u,v)' = (u'+v')/2 + sign(u-v)*(u'-v')/2
                %   min(u,v)' = (u'+v')/2 - sign(u-v)*(u'-v')/2
                % At the tie u=v the result is the averaged sub-gradient (sign(0)=0),
                % the same kink convention abs/sign use (see autoDiff1.abs and ad/t36).
                u = node.children{1};
                v = node.children{2};
                du = ast.diff_node(u, target, target_lag);
                dv = ast.diff_node(v, target, target_lag);
                avg = ast('binop', '/', {ast('binop', '+', {du, dv}), ast('num', 2, {})});
                s = ast('call', 'sign', {ast('binop', '-', {u, v})});
                half_diff = ast('binop', '/', {ast('binop', '-', {du, dv}), ast('num', 2, {})});
                correction = ast('binop', '*', {s, half_diff});
                if strcmp(fname, 'max')
                    d = ast('binop', '+', {avg, correction});
                else
                    d = ast('binop', '-', {avg, correction});
                end
                return
            end
            darg = ast.diff_node(arg, target, target_lag);
            one = ast('num', 1, {});
            two = ast('num', 2, {});
            switch fname
                case 'abs'
                    % abs(u)' = sign(u)*u'. The sub-gradient choice at u = 0 is sign(0) = 0,
                    % matching autoDiff1.abs and Dynare's sign(0) = 0 convention.
                    outer = ast('call', 'sign', {arg});
                case {'log', 'ln'}
                    outer = ast('binop', '/', {one, arg});
                case 'log10'
                    outer = ast('binop', '/', {one, ast('binop', '*', {arg, ast('call', 'log', {ast('num', 10, {})})})});
                case 'exp'
                    outer = ast('call', 'exp', {arg});
                case 'sqrt'
                    outer = ast('binop', '/', {one, ast('binop', '*', {two, ast('call', 'sqrt', {arg})})});
                case 'cbrt'
                    % 1/(3*cbrt(x)^2).
                    outer = ast('binop', '/', {one, ast('binop', '*', {ast('num', 3, {}), ast('binop', '^', {ast('call', 'cbrt', {arg}), two})})});
                case 'sin'
                    outer = ast('call', 'cos', {arg});
                case 'cos'
                    outer = ast('uminus', [], {ast('call', 'sin', {arg})});
                case 'tan'
                    % 1/cos(x)^2.
                    outer = ast('binop', '/', {one, ast('binop', '^', {ast('call', 'cos', {arg}), two})});
                case 'asin'
                    % 1/sqrt(1-x^2).
                    outer = ast('binop', '/', {one, ast('call', 'sqrt', {ast('binop', '-', {one, ast('binop', '^', {arg, two})})})});
                case 'acos'
                    % -1/sqrt(1-x^2).
                    outer = ast('uminus', [], {ast('binop', '/', {one, ast('call', 'sqrt', {ast('binop', '-', {one, ast('binop', '^', {arg, two})})})})});
                case 'atan'
                    % 1/(1+x^2).
                    outer = ast('binop', '/', {one, ast('binop', '+', {one, ast('binop', '^', {arg, two})})});
                case 'sinh'
                    outer = ast('call', 'cosh', {arg});
                case 'cosh'
                    outer = ast('call', 'sinh', {arg});
                case 'tanh'
                    % 1 - tanh(x)^2.
                    outer = ast('binop', '-', {one, ast('binop', '^', {ast('call', 'tanh', {arg}), two})});
                case 'asinh'
                    % 1/sqrt(x^2+1).
                    outer = ast('binop', '/', {one, ast('call', 'sqrt', {ast('binop', '+', {ast('binop', '^', {arg, two}), one})})});
                case 'acosh'
                    % 1/sqrt(x^2-1).
                    outer = ast('binop', '/', {one, ast('call', 'sqrt', {ast('binop', '-', {ast('binop', '^', {arg, two}), one})})});
                case 'atanh'
                    % 1/(1-x^2).
                    outer = ast('binop', '/', {one, ast('binop', '-', {one, ast('binop', '^', {arg, two})})});
                case 'normcdf'
                    outer = ast('call', 'normpdf', {arg});
                case 'normpdf'
                    % -x*normpdf(x).
                    outer = ast('uminus', [], {ast('binop', '*', {arg, ast('call', 'normpdf', {arg})})});
                case 'erf'
                    % (2/sqrt(pi))*exp(-x^2).
                    coef = ast('binop', '/', {two, ast('call', 'sqrt', {ast('num', pi, {})})});
                    outer = ast('binop', '*', {coef, ast('call', 'exp', {ast('uminus', [], {ast('binop', '^', {arg, two})})})});
                otherwise
                    error('ast:diff_ast:noRule', 'No differentiation rule for function "%s".', fname);
            end
            d = ast('binop', '*', {outer, darg});
        end % function

        function tf = is_constant_wrt(node, target)
        % True iff target does not appear among the symbol names of node. Used by
        % diff_power to pick the applicable power rule. A 'tsym' lead/lag of target
        % counts as a use (symbol_names drops the lag), so the general / non-constant
        % branch is taken; the period-specific du/dv factor then zeroes it out anyway.
            tf = ~ismember(target, node.symbol_names());
        end % function

        function s = latex_num(v)
        % Render a numeric literal for LaTeX. %.16g drops trailing zeros and prints
        % integers without a decimal point, matching ast.string.
            s = num2str(v, '%.16g');
        end % function

        function s = latex_name(name, m)
        % Look up a symbol's LaTeX form in the texname map, or fall back to the literal name.
        % A user-supplied texname is LaTeX and used verbatim; the literal fallback escapes
        % underscores (_ → \_) so a name like c_h or a_b_c is valid math rather than an
        % unintended (or invalid, doubled) subscript. Underscore is the only LaTeX-special
        % character a valid symbol name can contain.
            if isfield(m, name)
                s = m.(name);
            else
                s = strrep(name, '_', '\_');
            end
        end % function

        function s = latex_fname(fname)
        % LaTeX command for a function name (used by latex_call for the parenthesised forms;
        % exp/sqrt/cbrt/abs are handled specially by latex_call and never reach this map).
            switch fname
                case 'log',     s = '\log';
                case 'ln',      s = '\ln';
                case 'log10',   s = '\log_{10}';
                case 'sin',     s = '\sin';
                case 'cos',     s = '\cos';
                case 'tan',     s = '\tan';
                case 'asin',    s = '\arcsin';
                case 'acos',    s = '\arccos';
                case 'atan',    s = '\arctan';
                case 'sinh',    s = '\sinh';
                case 'cosh',    s = '\cosh';
                case 'tanh',    s = '\tanh';
                case 'asinh',   s = '\operatorname{arsinh}';
                case 'acosh',   s = '\operatorname{arcosh}';
                case 'atanh',   s = '\operatorname{artanh}';
                case 'sign',    s = '\operatorname{sign}';
                case 'erf',     s = '\operatorname{erf}';
                case 'normcdf', s = '\Phi';
                case 'normpdf', s = '\phi';
                case 'min',     s = '\min';
                case 'max',     s = '\max';
                otherwise,      s = ['\operatorname{' fname '}'];
            end
        end % function

        function str = latex_call(node, m, dated)
        % Render a function-call node. exp, sqrt, cbrt and abs use dedicated LaTeX
        % constructs; everything else renders as <command>\left( arg, … \right).
            fname = node.value;
            a = node.children;
            switch fname
                case 'exp'
                    str = ['e^{' a{1}.to_latex(m, dated, '', false) '}'];
                case 'sqrt'
                    str = ['\sqrt{' a{1}.to_latex(m, dated, '', false) '}'];
                case 'cbrt'
                    str = ['\sqrt[3]{' a{1}.to_latex(m, dated, '', false) '}'];
                case 'abs'
                    str = ['\left|' a{1}.to_latex(m, dated, '', false) '\right|'];
                otherwise
                    parts = cell(1, numel(a));
                    for i = 1:numel(a)
                        parts{i} = a{i}.to_latex(m, dated, '', false);
                    end
                    str = [ast.latex_fname(fname) '\left(' strjoin(parts, ', ') '\right)'];
            end
        end % function

        function str = latex_binop(o, m, dated, parent_op, is_right)
        % Render a binary-operator node to LaTeX, applying the same canonical-form
        % pretty-printing as ast.string (a + (-b) → "a - b", a · b^(-1) → \frac{a}{b})
        % plus the LaTeX-specific constructs (\frac, ^{}). Division and power are
        % self-grouping, so only the inline operators (+, -, *) take precedence-based
        % \left( … \right) wrapping; a non-atomic power base is wrapped explicitly.
            op = o.value;
            L = o.children{1};
            R = o.children{2};
            if strcmp(op, '+') && strcmp(R.type, 'uminus')
                op = '-'; R = R.children{1};
            elseif strcmp(op, '+') && strcmp(R.type, 'num') && R.value < 0
                op = '-'; R = ast('num', -R.value, {});
            elseif strcmp(op, '*') && strcmp(R.type, 'binop') && strcmp(R.value, '^') && ast.is_neg_one(R.children{2})
                op = '/'; R = R.children{1};
            end
            boxed = false;
            switch op
                case '/'
                    % \frac groups numerator and denominator, so neither child needs parens.
                    str = ['\frac{' L.to_latex(m, dated, '', false) '}{' R.to_latex(m, dated, '', false) '}'];
                    boxed = true;
                case '^'
                    base = L.to_latex(m, dated, '', false);
                    if ast.latex_base_needs_invisible(L)
                        % Base already ends in a superscript (name^{\star}, e^{…}); a second
                        % superscript would be an invalid double superscript. Wrap in invisible
                        % \left. … \right. delimiters so the outer exponent attaches without
                        % showing parentheses the reader does not need.
                        base = ['\left. ' base ' \right.'];
                    elseif ast.latex_base_needs_parens(L)
                        base = ['\left(' base '\right)'];
                    end
                    str = [base '^{' R.to_latex(m, dated, '', false) '}'];
                    boxed = true;
                otherwise
                    lStr = L.to_latex(m, dated, op, false);
                    rStr = R.to_latex(m, dated, op, true);
                    if strcmp(op, '*')
                        str = [lStr ast.latex_mult_sep(rStr) rStr];
                    else
                        str = [lStr ' ' op ' ' rStr];
                    end
            end
            % Self-grouping constructs (\frac, x^{y}) never need outer parens from an
            % additive/multiplicative parent; inline operators do, by precedence.
            if ~boxed
                cp = ast.op_precedence(op);
                pp = ast.op_precedence(parent_op);
                if cp < pp || (cp == pp && is_right)
                    str = ['\left(' str '\right)'];
                end
            end
        end % function

        function s = latex_mult_sep(rStr)
        % Separator for a LaTeX product: \cdot when the right factor begins with a digit or
        % a minus sign (so juxtaposition would not misread as a single number), else a thin
        % space \, (the usual implicit-multiplication convention, e.g. \alpha\,K_{t-1}).
            if ~isempty(rStr) && (isstrprop(rStr(1), 'digit') || rStr(1) == '-')
                s = ' \cdot ';
            else
                s = '\,';
            end
        end % function

        function tf = latex_base_needs_parens(L)
        % True iff a power base must be wrapped in VISIBLE \left( … \right) because the
        % parentheses carry meaning: any binop (incl. \frac and a^b, where (a^b)^c must be
        % distinguished from a^{b^c}), a unary minus, or a negative literal. Bases that
        % merely end in a superscript (ss, exp) take invisible delimiters instead — see
        % latex_base_needs_invisible.
            tf = strcmp(L.type, 'binop') || strcmp(L.type, 'uminus') || ...
                 (strcmp(L.type, 'num') && L.value < 0);
        end % function

        function tf = latex_base_needs_invisible(L)
        % True iff a power base renders with a trailing superscript and so would form an
        % invalid double superscript under a further exponent, but carries no precedence
        % ambiguity: an ss node (name^{\star}) or exp (e^{…}). These take invisible
        % \left. … \right. delimiters rather than visible parentheses.
            tf = strcmp(L.type, 'ss') || (strcmp(L.type, 'call') && strcmp(L.value, 'exp'));
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

        function v = lookup_value(name, values)
        % Look up a symbol's numeric value in the values struct. Used by ast.eval.
            if ~isfield(values, name)
                error('ast:eval', 'No value provided for symbol "%s".', name);
            end
            v = values.(name);
        end % function

    end % methods (Static)

end % classdef
