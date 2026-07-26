classdef macro

% Abstract syntax tree for the expressions of the Dynare macro language.

% Copyright © 2026 Dynare Team
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

% The macro language is a separate language from the model language, and this class is
% deliberately separate from ast. It has a type system ast has no use for (strings,
% booleans, tuples, arrays), operators ast does not know ('|' and '&' as set operations,
% 'in', ranges), and no notion of a lead or a lag. Its structure mirrors ast's all the
% same: a character-level tokeniser followed by one static method per level of the
% grammar, so that anyone who has read ast.m can read this.
%
% A tree serves two purposes, which is why there are two output methods:
%   * eval(env)   gives the compile-time value, needed to resolve loop index sets,
%                 conditions and @{...} substitutions;
%   * to_matlab() renders MATLAB source, so that a @#define becomes a readable local
%                 variable and a @#if becomes a readable condition in the generated
%                 script. It is best effort: whatever it cannot render faithfully, the
%                 caller emits as the evaluated literal instead.
%
% Values are tagged structs, struct('kind', k, 'data', d), with kind one of 'real',
% 'bool', 'string', 'array' or 'tuple'. Bare MATLAB values cannot carry the distinctions
% the language makes: isboolean against isreal, and istuple against isarray. A class
% would be the other option, and was rejected because value dispatch in a recursive
% evaluator costs far more than a struct field read.

    properties
        % Node kind: 'num', 'str', 'bool', 'sym', 'arr', 'tup', 'binop', 'unop',
        % 'call', 'index', 'range' or 'comp'.
        type

        % Payload, whose shape depends on type: the number for 'num', the text for
        % 'str', the logical for 'bool', the name for 'sym' and 'call', the operator
        % for 'binop' and 'unop', and [] for the rest.
        value

        % Child nodes, as a cell array. Empty for the leaves.
        children
    end

    properties (Constant)
        % Functions of one argument that the macro language provides and that MATLAB
        % spells the same way.
        UNARY_FUNCTIONS = {'exp', 'log', 'log10', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sqrt', 'sign', 'floor', 'ceil', 'round', 'erf', 'erfc', 'gamma'}

        % Casts, which are also written as calls.
        CASTS = {'bool', 'real', 'string', 'tuple', 'array'}

        % Predicates on the kind of a value.
        PREDICATES = {'isempty', 'isboolean', 'isreal', 'isstring', 'istuple', 'isarray'}
    end

    methods

        function o = macro(varargin)
        % Construct a macro expression tree.
        %
        % USAGE:
        % - o = macro()                          empty node
        % - o = macro(str)                       parse an expression
        % - o = macro(type, value, children)     build a single node
        %
        % INPUTS:
        % - varargin{1}   [char]   expression to parse, or the node type
        % - varargin{2}            node payload
        % - varargin{3}   [cell]   child nodes
        %
        % OUTPUTS:
        % - o             [macro]  the tree
        %
        % EXAMPLES:
        % t = macro('[1, 2, 3]');
        % t = macro('Countries | ["US"]');
            if nargin == 0
                return
            end
            if nargin == 1
                str = char(varargin{1});
                tokens = macro.tokenise(str);
                if isempty(tokens)
                    error('macro:parse:empty', 'Empty macro expression.')
                end
                [o, pos] = macro.parse_expr(tokens, 1);
                if pos <= numel(tokens)
                    error('macro:parse:trailingToken', 'Unexpected token "%s" in macro expression "%s".', macro.token_text(tokens{pos}), str)
                end
                return
            end
            if nargin == 3
                o.type = varargin{1};
                o.value = varargin{2};
                o.children = varargin{3};
                return
            end
            error('macro:macro:badType', 'Wrong number of arguments.')
        end % function

        function v = eval(o, env)
        % Evaluate the expression against a macro environment.
        %
        % INPUTS:
        % - o     [macro]    the tree
        % - env   [struct]   fields 'vars' and 'funcs', both dictionaries
        %
        % OUTPUTS:
        % - v     [struct]   a tagged value, struct('kind', ..., 'data', ...)
            switch o.type
              case 'num'
                v = macro.mkreal(o.value);
              case 'str'
                v = macro.mkstring(o.value);
              case 'bool'
                v = macro.mkbool(o.value);
              case 'sym'
                if ~isKey(env.vars, string(o.value))
                    error('macro:eval:undefinedVariable', 'Macro variable "%s" is not defined.', o.value)
                end
                v = env.vars(string(o.value));
              case 'arr'
                v = macro.mkarray(cellfun(@(c) c.eval(env), o.children, 'UniformOutput', false));
              case 'tup'
                v = macro.mktuple(cellfun(@(c) c.eval(env), o.children, 'UniformOutput', false));
              case 'unop'
                v = macro.eval_unop(o.value, o.children{1}.eval(env));
              case 'binop'
                v = macro.eval_binop(o.value, o.children{1}.eval(env), o.children{2}.eval(env));
              case 'range'
                v = macro.eval_range(cellfun(@(c) c.eval(env), o.children, 'UniformOutput', false));
              case 'index'
                v = macro.eval_index(o.children{1}.eval(env), o.children{2}.eval(env));
              case 'call'
                v = macro.eval_call(o, env);
              case 'comp'
                v = macro.eval_comprehension(o, env);
              otherwise
                error('macro:eval:badType', 'Unknown macro node type "%s".', o.type)
            end
        end % function

        function [str, ok] = to_matlab(o, env)
        % Render the expression as MATLAB source.
        %
        % INPUTS:
        % - o     [macro]      the tree
        % - env   [struct]     the environment the expression will be evaluated in, used
        %                      to learn the kind of each subexpression (default empty)
        %
        % OUTPUTS:
        % - str   [char]       MATLAB source for the expression, meaningful only when ok
        % - ok    [logical]    scalar, false when some node has no faithful rendering
        %
        % REMARKS:
        % - Best effort by design. Macro values are compile-time constants, so a caller
        %   that gets ok=false can always emit the evaluated literal instead; rendering
        %   exists to keep the generated script readable, not to make every expression
        %   re-runnable.
        % - The kinds are needed, not merely helpful: several operators mean different
        %   things in MATLAB depending on them. '+' is addition on reals but concatenation
        %   on strings and arrays, and MATLAB's '+' on two char arrays is arithmetic on
        %   their code points, which would be silently wrong. Anything whose kind cannot
        %   be established is declined rather than guessed.
        % - Declined outright: tuples, the type predicates, and defined(), none of which
        %   has a MATLAB counterpart that would mean the same thing.
            arguments
                o   macro
                env struct = macro.environment()
            end

            try
                kind = o.eval(env).kind;
            catch
                str = '';
                ok = false;
                return
            end

            ok = true;
            switch o.type
              case 'num'
                str = macro.render_real(o.value);
              case 'str'
                str = macro.quote(o.value);
              case 'bool'
                str = macro.ternary(o.value, 'true', 'false');
              case 'sym'
                str = o.value;
              case {'arr', 'tup'}
                [parts, ok] = macro.children_to_matlab(o.children, env);
                str = macro.render_list(o, parts, env);
              case 'range'
                [parts, ok] = macro.children_to_matlab(o.children, env);
                str = strjoin(parts, ':');
              case 'unop'
                [inner, ok] = o.children{1}.to_matlab(env);
                switch o.value
                  case '!'
                    str = sprintf('~%s', macro.parenthesise(inner));
                  otherwise
                    str = sprintf('-%s', macro.parenthesise(inner));
                end
              case 'binop'
                [str, ok] = macro.binop_to_matlab(o, env);
              case 'call'
                [str, ok] = macro.call_to_matlab(o, env);
              case 'index'
                [str, ok] = macro.index_to_matlab(o, env);
              case 'comp'
                [str, ok] = macro.comprehension_to_matlab(o, env);
              otherwise
                str = '';
                ok = false;
            end
        end % function

        function disp(o)
        % Print the tree as MATLAB source, or as its type when it cannot be rendered.
            [str, ok] = o.to_matlab();
            if ok
                fprintf('%s\n', str);
            else
                fprintf('<macro %s>\n', o.type);
            end
        end % function

    end % methods

    methods (Static)

        function v = mkreal(x)
        % Build a real value.
            v = struct('kind', 'real', 'data', double(x));
        end % function

        function v = mkbool(x)
        % Build a boolean value.
            v = struct('kind', 'bool', 'data', logical(x));
        end % function

        function v = mkstring(x)
        % Build a string value.
            v = struct('kind', 'string', 'data', char(x));
        end % function

        function v = mkarray(items)
        % Build an array value from a cell array of values.
            v = struct('kind', 'array', 'data', {items(:)'});
        end % function

        function v = mktuple(items)
        % Build a tuple value from a cell array of values.
            v = struct('kind', 'tuple', 'data', {items(:)'});
        end % function

        function str = tostring(v)
        % Render a value the way @{...} substitutes it into the surrounding text.
        %
        % INPUTS:
        % - v     [struct]   a tagged value
        %
        % OUTPUTS:
        % - str   [char]     1×n array
        %
        % REMARKS:
        % - Strings render bare, without their quotes: that is what makes @{c} usable
        %   inside an identifier such as y_@{c}. Booleans render as true and false, which
        %   is why they cannot be carried as plain doubles.
            switch v.kind
              case 'real'
                str = macro.render_real(v.data);
              case 'bool'
                str = macro.ternary(v.data, 'true', 'false');
              case 'string'
                str = v.data;
              case 'array'
                str = sprintf('[%s]', strjoin(cellfun(@macro.tostring, v.data, 'UniformOutput', false), ', '));
              case 'tuple'
                str = sprintf('(%s)', strjoin(cellfun(@macro.tostring, v.data, 'UniformOutput', false), ', '));
              otherwise
                error('macro:tostring:badType', 'Unknown value kind "%s".', v.kind)
            end
        end % function

        function tf = truth(v)
        % Interpret a value as a condition.
            switch v.kind
              case 'bool'
                tf = v.data;
              case 'real'
                tf = v.data ~= 0;
              otherwise
                error('macro:truth:typeError', 'A %s cannot be used as a condition.', v.kind)
            end
        end % function

        function env = environment(defines)
        % Build a macro environment, optionally seeded with command-line style defines.
        %
        % INPUTS:
        % - defines   [struct]   scalar struct whose fields become macro variables; the
        %                        value of each field is converted with macro.fromnative
        %
        % OUTPUTS:
        % - env       [struct]   fields 'vars' and 'funcs', both dictionaries
            arguments
                defines struct = struct()
            end
            env = struct('vars', configureDictionary('string', 'struct'), ...
                         'funcs', configureDictionary('string', 'struct'));
            keys = fieldnames(defines);
            for i = 1:numel(keys)
                env.vars(string(keys{i})) = macro.fromnative(defines.(keys{i}));
            end
        end % function

        function name = list_class(o, env)
        % The MATLAB class an array or a tuple renders through.
            name = 'macroarray';
            try
                if strcmp(o.eval(env).kind, 'tuple')
                    name = 'macrotuple';
                end
            catch
                if strcmp(o.type, 'tup')
                    name = 'macrotuple';
                end
            end
        end % function

        function tf = renders_as_cell(v)
        % Whether a value renders as a MATLAB cell array rather than a numeric one.
        %
        % An array of two or more reals renders as [a, b, ...]; everything else that holds
        % elements renders as {a, b, ...}. The one-element and empty cases go to a cell on
        % purpose: [7] would otherwise be the same MATLAB value as the real 7, and no test
        % could tell an array from a scalar. Tuples render as cells too, which is what
        % lets an array of tuples, the usual way of writing a multi-index @#for, survive
        % into the generated script.
            tf = false;
            if ~ismember(v.kind, {'array', 'tuple'})
                return
            end
            tf = numel(v.data) < 2 || strcmp(v.kind, 'tuple') || ~all(cellfun(@(x) strcmp(x.kind, 'real'), v.data));
        end % function

        function v = fromnative(x)
        % Convert a MATLAB value into a macro value.
        %
        % INPUTS:
        % - x   [double, logical, char or cell]
        %
        % OUTPUTS:
        % - v   [struct]   a tagged value
            if isstruct(x) && isfield(x, 'kind')
                v = x;
            elseif islogical(x) && isscalar(x)
                v = macro.mkbool(x);
            elseif isnumeric(x) && isscalar(x)
                v = macro.mkreal(x);
            elseif ischar(x)
                v = macro.mkstring(x);
            elseif isstring(x) && isscalar(x)
                v = macro.mkstring(char(x));
            elseif iscell(x)
                v = macro.mkarray(cellfun(@macro.fromnative, x(:)', 'UniformOutput', false));
            elseif isnumeric(x)
                v = macro.mkarray(arrayfun(@macro.mkreal, x(:)', 'UniformOutput', false));
            else
                error('macro:fromnative:badType', 'Cannot use a value of class "%s" as a macro variable.', class(x))
            end
        end % function

    end % methods

    methods (Static)

        function tokens = tokenise(str)
        % Split a macro expression into tokens.
        %
        % INPUTS:
        % - str      [char]   1×n array, a macro expression
        %
        % OUTPUTS:
        % - tokens   [cell]   1×m array of struct('type', ..., 'value', ...)
        %
        % REMARKS:
        % - Keywords such as 'in', 'true' and the function names come out as 'identifier'
        %   and are told apart by the parser, exactly as ast.tokenise leaves STEADY_STATE
        %   and the reserved function names to ast.parse_atom.
        % - Quoted strings use double quotes in the macro language, unlike the model
        %   language, and admit the \\ and \" escapes.
            tokens = {};
            n = length(str);
            i = 1;
            while i <= n
                c = str(i);
                two = '';
                if i < n
                    two = str(i:i+1);
                end
                if isspace(c)
                    i = i + 1;
                    continue
                end
                switch two
                  case '=='
                    tokens{end+1} = struct('type', 'eq', 'value', '=='); %#ok<AGROW>
                    i = i + 2;
                    continue
                  case '!='
                    tokens{end+1} = struct('type', 'ne', 'value', '!='); %#ok<AGROW>
                    i = i + 2;
                    continue
                  case '<='
                    tokens{end+1} = struct('type', 'le', 'value', '<='); %#ok<AGROW>
                    i = i + 2;
                    continue
                  case '>='
                    tokens{end+1} = struct('type', 'ge', 'value', '>='); %#ok<AGROW>
                    i = i + 2;
                    continue
                  case '&&'
                    tokens{end+1} = struct('type', 'and', 'value', '&&'); %#ok<AGROW>
                    i = i + 2;
                    continue
                  case '||'
                    tokens{end+1} = struct('type', 'or', 'value', '||'); %#ok<AGROW>
                    i = i + 2;
                    continue
                end
                if c == '"'
                    [text, i] = macro.scan_string(str, i);
                    tokens{end+1} = struct('type', 'string', 'value', text); %#ok<AGROW>
                    continue
                end
                if c == '.' || (c >= '0' && c <= '9')
                    [number, i] = macro.scan_number(str, i);
                    tokens{end+1} = struct('type', 'number', 'value', number); %#ok<AGROW>
                    continue
                end
                if isletter(c) || c == '_'
                    j = i;
                    while j <= n && (isletter(str(j)) || (str(j) >= '0' && str(j) <= '9') || str(j) == '_')
                        j = j + 1;
                    end
                    tokens{end+1} = struct('type', 'identifier', 'value', str(i:j-1)); %#ok<AGROW>
                    i = j;
                    continue
                end
                type = macro.punctuation(c);
                if isempty(type)
                    error('macro:tokenise:badCharacter', 'Unexpected character "%c" at position %d of a macro expression.', c, i)
                end
                tokens{end+1} = struct('type', type, 'value', c); %#ok<AGROW>
                i = i + 1;
            end
        end % function

        function [node, pos] = parse_expr(tokens, pos)
        % expr ::= and_expr ('||' and_expr)*
            [node, pos] = macro.parse_and(tokens, pos);
            while pos <= numel(tokens) && strcmp(tokens{pos}.type, 'or')
                pos = pos + 1;
                [right, pos] = macro.parse_and(tokens, pos);
                node = macro('binop', '||', {node, right});
            end
        end % function

        function [node, pos] = parse_and(tokens, pos)
        % and_expr ::= equality_expr ('&&' equality_expr)*
            [node, pos] = macro.parse_equality(tokens, pos);
            while pos <= numel(tokens) && strcmp(tokens{pos}.type, 'and')
                pos = pos + 1;
                [right, pos] = macro.parse_equality(tokens, pos);
                node = macro('binop', '&&', {node, right});
            end
        end % function

        function [node, pos] = parse_equality(tokens, pos)
        % equality_expr ::= relational_expr (('=='|'!=') relational_expr)*
            [node, pos] = macro.parse_relational(tokens, pos);
            while pos <= numel(tokens) && ismember(tokens{pos}.type, {'eq', 'ne'})
                op = tokens{pos}.value;
                pos = pos + 1;
                [right, pos] = macro.parse_relational(tokens, pos);
                node = macro('binop', op, {node, right});
            end
        end % function

        function [node, pos] = parse_relational(tokens, pos)
        % relational_expr ::= in_expr (('<'|'>'|'<='|'>=') in_expr)*
            [node, pos] = macro.parse_in(tokens, pos);
            while pos <= numel(tokens) && ismember(tokens{pos}.type, {'lt', 'gt', 'le', 'ge'})
                op = tokens{pos}.value;
                pos = pos + 1;
                [right, pos] = macro.parse_in(tokens, pos);
                node = macro('binop', op, {node, right});
            end
        end % function

        function [node, pos] = parse_in(tokens, pos)
        % in_expr ::= colon_expr ['in' colon_expr]   (non-associative)
            [node, pos] = macro.parse_colon(tokens, pos);
            if macro.keyword(tokens, pos, 'in')
                pos = pos + 1;
                [right, pos] = macro.parse_colon(tokens, pos);
                node = macro('binop', 'in', {node, right});
            end
        end % function

        function [node, pos] = parse_colon(tokens, pos)
        % colon_expr ::= union_expr [':' union_expr [':' union_expr]]
            [node, pos] = macro.parse_union(tokens, pos);
            if pos <= numel(tokens) && strcmp(tokens{pos}.type, 'colon')
                pos = pos + 1;
                [second, pos] = macro.parse_union(tokens, pos);
                bounds = {node, second};
                if pos <= numel(tokens) && strcmp(tokens{pos}.type, 'colon')
                    pos = pos + 1;
                    [third, pos] = macro.parse_union(tokens, pos);
                    bounds{end+1} = third;
                end
                node = macro('range', [], bounds);
            end
        end % function

        function [node, pos] = parse_union(tokens, pos)
        % union_expr ::= intersection_expr ('|' intersection_expr)*
            [node, pos] = macro.parse_intersection(tokens, pos);
            while pos <= numel(tokens) && strcmp(tokens{pos}.type, 'union')
                pos = pos + 1;
                [right, pos] = macro.parse_intersection(tokens, pos);
                node = macro('binop', '|', {node, right});
            end
        end % function

        function [node, pos] = parse_intersection(tokens, pos)
        % intersection_expr ::= additive_expr ('&' additive_expr)*
            [node, pos] = macro.parse_additive(tokens, pos);
            while pos <= numel(tokens) && strcmp(tokens{pos}.type, 'intersection')
                pos = pos + 1;
                [right, pos] = macro.parse_additive(tokens, pos);
                node = macro('binop', '&', {node, right});
            end
        end % function

        function [node, pos] = parse_additive(tokens, pos)
        % additive_expr ::= multiplicative_expr (('+'|'-') multiplicative_expr)*
            [node, pos] = macro.parse_multiplicative(tokens, pos);
            while pos <= numel(tokens) && ismember(tokens{pos}.type, {'plus', 'minus'})
                op = tokens{pos}.value;
                pos = pos + 1;
                [right, pos] = macro.parse_multiplicative(tokens, pos);
                node = macro('binop', op, {node, right});
            end
        end % function

        function [node, pos] = parse_multiplicative(tokens, pos)
        % multiplicative_expr ::= unary_expr (('*'|'/') unary_expr)*
            [node, pos] = macro.parse_unary(tokens, pos);
            while pos <= numel(tokens) && ismember(tokens{pos}.type, {'times', 'divide'})
                op = tokens{pos}.value;
                pos = pos + 1;
                [right, pos] = macro.parse_unary(tokens, pos);
                node = macro('binop', op, {node, right});
            end
        end % function

        function [node, pos] = parse_unary(tokens, pos)
        % unary_expr ::= ('-'|'+'|'!') unary_expr | power_expr
            if pos <= numel(tokens)
                switch tokens{pos}.type
                  case 'minus'
                    [operand, pos] = macro.parse_unary(tokens, pos+1);
                    node = macro('unop', '-', {operand});
                    return
                  case 'plus'
                    [node, pos] = macro.parse_unary(tokens, pos+1);
                    return
                  case 'not'
                    [operand, pos] = macro.parse_unary(tokens, pos+1);
                    node = macro('unop', '!', {operand});
                    return
                end
            end
            [node, pos] = macro.parse_power(tokens, pos);
        end % function

        function [node, pos] = parse_power(tokens, pos)
        % power_expr ::= postfix_expr ['^' unary_expr]
            [node, pos] = macro.parse_postfix(tokens, pos);
            if pos <= numel(tokens) && strcmp(tokens{pos}.type, 'power')
                pos = pos + 1;
                [exponent, pos] = macro.parse_unary(tokens, pos);
                node = macro('binop', '^', {node, exponent});
            end
        end % function

        function [node, pos] = parse_postfix(tokens, pos)
        % postfix_expr ::= atom ('[' expr ']')*
            [node, pos] = macro.parse_atom(tokens, pos);
            while pos <= numel(tokens) && strcmp(tokens{pos}.type, 'lbracket')
                pos = pos + 1;
                [idx, pos] = macro.parse_expr(tokens, pos);
                pos = macro.expect(tokens, pos, 'rbracket', ']');
                node = macro('index', [], {node, idx});
            end
        end % function

        function [node, pos] = parse_atom(tokens, pos)
        % atom ::= NUMBER | STRING | 'true' | 'false' | IDENT | IDENT '(' args ')'
        %        | '(' expr (',' expr)* ')' | bracket
            if pos > numel(tokens)
                error('macro:parse:unexpectedEnd', 'Unexpected end of a macro expression.')
            end
            token = tokens{pos};
            switch token.type
              case 'number'
                node = macro('num', token.value, {});
                pos = pos + 1;
              case 'string'
                node = macro('str', token.value, {});
                pos = pos + 1;
              case 'identifier'
                switch token.value
                  case 'true'
                    node = macro('bool', true, {});
                    pos = pos + 1;
                  case 'false'
                    node = macro('bool', false, {});
                    pos = pos + 1;
                  otherwise
                    if pos < numel(tokens) && strcmp(tokens{pos+1}.type, 'lparen')
                        [args, pos] = macro.parse_list(tokens, pos+2, 'rparen', ')');
                        node = macro('call', token.value, args);
                    else
                        node = macro('sym', token.value, {});
                        pos = pos + 1;
                    end
                end
              case 'lparen'
                [items, pos] = macro.parse_list(tokens, pos+1, 'rparen', ')');
                if isscalar(items)
                    % Plain grouping; a tuple needs at least a comma.
                    node = items{1};
                else
                    node = macro('tup', [], items);
                end
              case 'lbracket'
                [node, pos] = macro.parse_bracket(tokens, pos+1);
              otherwise
                error('macro:parse:unexpectedToken', 'Unexpected token "%s" in a macro expression.', macro.token_text(token))
            end
        end % function

        function [node, pos] = parse_bracket(tokens, pos)
        % What an opening bracket starts, an array or a comprehension:
        %
        %   bracket ::= '[' [expr (',' expr)*] ']'
        %             | '[' expr 'for' indices 'in' expr ['when' expr] ']'
        %             | '[' indices 'in' expr 'when' expr ']'
        %
        % The three are told apart by what follows the first expression, which is where
        % they first differ: a comma or the closing bracket for an array, 'for' for a
        % comprehension that maps, 'when' for one that only filters.
        %
        % The filtering form is the mapping one with the index itself as the output
        % expression. Dynare yields the element the index was bound to, and evaluating the
        % index gives that same element back, a destructured tuple included, so the two
        % agree; normalising here leaves one form to evaluate and one to render.
            if pos <= numel(tokens) && strcmp(tokens{pos}.type, 'rbracket')
                node = macro('arr', [], {});
                pos = pos + 1;
                return
            end

            [first, pos] = macro.parse_expr(tokens, pos);

            if macro.keyword(tokens, pos, 'for')
                [indices, pos] = macro.parse_indices(tokens, pos+1);
                pos = macro.expect_keyword(tokens, pos, 'in');
                [set, pos] = macro.parse_expr(tokens, pos);
                children = {first, indices, set};
            elseif macro.keyword(tokens, pos, 'when')
                if ~strcmp(first.type, 'binop') || ~strcmp(first.value, 'in')
                    error('macro:parse:badComprehension', 'A comprehension with no "for" must read "[index in set when condition]".')
                end
                indices = macro.as_indices(first.children{1});
                children = {indices, indices, first.children{2}};
            else
                items = {first};
                while pos <= numel(tokens) && strcmp(tokens{pos}.type, 'comma')
                    [item, pos] = macro.parse_expr(tokens, pos+1);
                    items{end+1} = item; %#ok<AGROW>
                end
                pos = macro.expect(tokens, pos, 'rbracket', ']');
                node = macro('arr', [], items);
                return
            end

            if macro.keyword(tokens, pos, 'when')
                [guard, pos] = macro.parse_expr(tokens, pos+1);
                children{end+1} = guard;
            end
            pos = macro.expect(tokens, pos, 'rbracket', ']');
            node = macro('comp', [], children);
        end % function

    end % methods

    methods (Static, Access = private)

        function [items, pos] = parse_list(tokens, pos, closing, symbol)
        % Parse a comma-separated list up to its closing bracket, which may be empty.
            items = {};
            if pos <= numel(tokens) && strcmp(tokens{pos}.type, closing)
                pos = pos + 1;
                return
            end
            while true
                [item, pos] = macro.parse_expr(tokens, pos);
                items{end+1} = item; %#ok<AGROW>
                if pos <= numel(tokens) && strcmp(tokens{pos}.type, 'comma')
                    pos = pos + 1;
                    continue
                end
                break
            end
            pos = macro.expect(tokens, pos, closing, symbol);
        end % function

        function pos = expect(tokens, pos, type, symbol)
        % Consume the expected closing token, or report what is missing.
            if pos > numel(tokens) || ~strcmp(tokens{pos}.type, type)
                error('macro:parse:missingToken', 'Expected "%s" in a macro expression.', symbol)
            end
            pos = pos + 1;
        end % function

        function tf = keyword(tokens, pos, word)
        % Whether the token at pos is a given keyword. The tokeniser leaves 'in', 'for' and
        % 'when' as identifiers, exactly as it leaves the function names, and the parser
        % tells them apart from where they stand.
            tf = pos <= numel(tokens) && strcmp(tokens{pos}.type, 'identifier') && strcmp(tokens{pos}.value, word);
        end % function

        function pos = expect_keyword(tokens, pos, word)
        % Consume the expected keyword, or report what is missing.
            if ~macro.keyword(tokens, pos, word)
                error('macro:parse:missingToken', 'Expected "%s" in a macro expression.', word)
            end
            pos = pos + 1;
        end % function

        function [node, pos] = parse_indices(tokens, pos)
        % The index of a comprehension: a name, or a parenthesised tuple of names.
        %
        % Parsed on its own rather than as an expression, because "c in A" would otherwise
        % read as the membership operator and swallow the input set with it.
            if pos <= numel(tokens) && strcmp(tokens{pos}.type, 'lparen')
                names = {};
                pos = pos + 1;
                while true
                    [name, pos] = macro.parse_name(tokens, pos);
                    names{end+1} = name; %#ok<AGROW>
                    if pos <= numel(tokens) && strcmp(tokens{pos}.type, 'comma')
                        pos = pos + 1;
                        continue
                    end
                    break
                end
                pos = macro.expect(tokens, pos, 'rparen', ')');
                % A single parenthesised name is grouping, not a tuple, as everywhere else.
                node = macro.ternary(isscalar(names), names{1}, macro('tup', [], names));
                return
            end
            [node, pos] = macro.parse_name(tokens, pos);
        end % function

        function [node, pos] = parse_name(tokens, pos)
        % A bare name, which is all an index may be.
            if pos > numel(tokens) || ~strcmp(tokens{pos}.type, 'identifier') || ismember(tokens{pos}.value, {'true', 'false'})
                error('macro:parse:badIndex', 'The index of a comprehension must be a name, or a tuple of names.')
            end
            node = macro('sym', tokens{pos}.value, {});
            pos = pos + 1;
        end % function

        function node = as_indices(node)
        % Accept an already parsed expression as an index, which the filtering form of a
        % comprehension needs: its index is on the left of an 'in' and has been read as an
        % expression before there was any way to know it was one.
            switch node.type
              case 'sym'
                return
              case 'tup'
                if all(cellfun(@(c) strcmp(c.type, 'sym'), node.children))
                    return
                end
            end
            error('macro:parse:badIndex', 'The index of a comprehension must be a name, or a tuple of names.')
        end % function

        function type = punctuation(c)
        % Token type of a single-character operator, empty when it is not one.
            switch c
              case '+',  type = 'plus';
              case '-',  type = 'minus';
              case '*',  type = 'times';
              case '/',  type = 'divide';
              case '^',  type = 'power';
              case '(',  type = 'lparen';
              case ')',  type = 'rparen';
              case '[',  type = 'lbracket';
              case ']',  type = 'rbracket';
              case ',',  type = 'comma';
              case ':',  type = 'colon';
              case '|',  type = 'union';
              case '&',  type = 'intersection';
              case '!',  type = 'not';
              case '<',  type = 'lt';
              case '>',  type = 'gt';
              case '=',  type = 'assign';
              otherwise, type = '';
            end
        end % function

        function [text, i] = scan_string(str, i)
        % Read a double-quoted string, honouring the \\ and \" escapes.
            n = length(str);
            text = '';
            i = i + 1;
            while i <= n && str(i) ~= '"'
                if str(i) == '\' && i < n && ismember(str(i+1), '\"')
                    text(end+1) = str(i+1); %#ok<AGROW>
                    i = i + 2;
                else
                    text(end+1) = str(i); %#ok<AGROW>
                    i = i + 1;
                end
            end
            if i > n
                error('macro:tokenise:unterminatedString', 'Unterminated string in a macro expression.')
            end
            i = i + 1;
        end % function

        function [number, i] = scan_number(str, i)
        % Read a numeric literal, in decimal or scientific notation.
            n = length(str);
            j = i;
            seen_dot = false;
            while j <= n && ((str(j) >= '0' && str(j) <= '9') || (str(j) == '.' && ~seen_dot))
                if str(j) == '.'
                    seen_dot = true;
                end
                j = j + 1;
            end
            if j <= n && ismember(str(j), 'eEdD')
                k = j + 1;
                if k <= n && ismember(str(k), '+-')
                    k = k + 1;
                end
                if k <= n && str(k) >= '0' && str(k) <= '9'
                    j = k;
                    while j <= n && (str(j) >= '0' && str(j) <= '9')
                        j = j + 1;
                    end
                end
            end
            text = strrep(str(i:j-1), 'd', 'e');
            number = str2double(text);
            if isnan(number) || ~any(text >= '0' & text <= '9')
                error('macro:tokenise:badNumber', 'Invalid number "%s" in a macro expression.', text)
            end
            i = j;
        end % function

        function s = ternary(condition, yes, no)
        % Small helper keeping the renderers to one line each.
            if condition
                s = yes;
            else
                s = no;
            end
        end % function

        function str = render_real(x)
        % Render a real the way Dynare's macro processor does: an integer without a
        % decimal point, anything else with enough digits to survive a round trip.
            if x == fix(x) && abs(x) < 1e15
                str = sprintf('%d', x);
            else
                str = sprintf('%.15g', x);
            end
        end % function

        function str = quote(text)
        % Render a char array as a MATLAB single-quoted literal.
            str = sprintf('''%s''', strrep(text, '''', ''''''));
        end % function

        function str = parenthesise(str)
        % Wrap in parentheses unless the rendering is already a single atom or group.
            if isempty(regexp(str, '^[\w.]+$', 'once')) && ~(str(1) == '(' && str(end) == ')')
                str = sprintf('(%s)', str);
            end
        end % function

        function str = render_list(o, parts, env)
        % Render an array or a tuple through the class that carries its kind.
        %
        % A plain cell could not: an array of one real is the same double as the real, and
        % a tuple is the same cell as an array of the same elements, so isreal, isarray and
        % istuple would answer wrongly on values the macro language treats as different.
            str = sprintf('%s(%s)', macro.list_class(o, env), strjoin(parts, ', '));
        end % function

        function [parts, ok] = children_to_matlab(children, env)
        % Render every child, reporting whether all of them could be rendered.
            ok = true;
            parts = cell(1, numel(children));
            for i = 1:numel(children)
                [parts{i}, childok] = children{i}.to_matlab(env);
                ok = ok && childok;
            end
        end % function

        function kinds = children_kinds(children, env)
        % Kind of each child, or '' for a child that cannot be evaluated.
            kinds = cell(1, numel(children));
            for i = 1:numel(children)
                try
                    kinds{i} = children{i}.eval(env).kind;
                catch
                    kinds{i} = '';
                end
            end
        end % function

        function [str, ok] = binop_to_matlab(o, env)
        % Render a binary operator. Several of them mean different things depending on the
        % kinds of their operands, so the rendering is chosen from those rather than from
        % the operator alone.
            [parts, ok] = macro.children_to_matlab(o.children, env);
            kinds = macro.children_kinds(o.children, env);
            both = @(k) all(strcmp(kinds, k));

            switch o.value
              case '+'
                if both('real')
                    str = sprintf('(%s + %s)', parts{1}, parts{2});
                elseif both('string')
                    % Concatenation. MATLAB's '+' on two char arrays adds their code
                    % points instead, so it cannot be used.
                    str = sprintf('[%s, %s]', parts{1}, parts{2});
                elseif both('array')
                    % macroarray overloads '+' as concatenation.
                    str = sprintf('(%s + %s)', parts{1}, parts{2});
                else
                    [str, ok] = macro.decline();
                end
              case '-'
                if both('real')
                    str = sprintf('(%s - %s)', parts{1}, parts{2});
                elseif both('array')
                    str = sprintf('(%s - %s)', parts{1}, parts{2});
                else
                    [str, ok] = macro.decline();
                end
              case {'*', '/', '^'}
                if both('real')
                    str = sprintf('(%s %s %s)', parts{1}, o.value, parts{2});
                elseif strcmp(o.value, '*') && both('array')
                    % macroarray overloads '*' as the Cartesian product.
                    str = sprintf('(%s * %s)', parts{1}, parts{2});
                else
                    [str, ok] = macro.decline();
                end
              case {'<', '>', '<=', '>='}
                if both('real')
                    str = sprintf('(%s %s %s)', parts{1}, o.value, parts{2});
                else
                    [str, ok] = macro.decline();
                end
              case '=='
                if both('real') || both('bool') || both('array') || both('tuple')
                    % macrolist overloads eq as structural equality.
                    str = sprintf('(%s == %s)', parts{1}, parts{2});
                elseif both('string')
                    str = sprintf('strcmp(%s, %s)', parts{1}, parts{2});
                else
                    [str, ok] = macro.decline();
                end
              case '!='
                if both('real') || both('bool') || both('array') || both('tuple')
                    str = sprintf('(%s ~= %s)', parts{1}, parts{2});
                elseif both('string')
                    str = sprintf('~strcmp(%s, %s)', parts{1}, parts{2});
                else
                    [str, ok] = macro.decline();
                end
              case '&&'
                str = sprintf('(%s && %s)', parts{1}, parts{2});
              case '||'
                str = sprintf('(%s || %s)', parts{1}, parts{2});
              case 'in'
                str = sprintf('ismember(%s, %s)', parts{1}, parts{2});
              case '|'
                str = sprintf('(%s | %s)', parts{1}, parts{2});
              case '&'
                str = sprintf('(%s & %s)', parts{1}, parts{2});
              otherwise
                [str, ok] = macro.decline();
            end
        end % function

        function [str, ok] = index_to_matlab(o, env)
        % Render an indexing expression, braces for a cell container and parentheses for
        % a numeric one.
            [parts, ok] = macro.children_to_matlab(o.children, env);
            kinds = macro.children_kinds(o.children, env);
            if ~ok || ~strcmp(kinds{1}, 'array')
                [str, ok] = macro.decline();
                return
            end
            if isempty(regexp(parts{1}, '^[A-Za-z_]\w*$', 'once'))
                % MATLAB cannot index a literal, only a variable.
                [str, ok] = macro.decline();
                return
            end
            try
                container = o.children{1}.eval(env);
            catch
                [str, ok] = macro.decline();
                return
            end
            if strcmp(kinds{2}, 'real')
                str = sprintf('%s{%s}', parts{1}, parts{2});
            else
                % A range of indices gives back a list, not its contents.
                str = sprintf('%s(%s)', parts{1}, parts{2});
            end
        end % function

        function [str, ok] = call_to_matlab(o, env)
        % Render a function call when MATLAB spells it the same way or nearly so.
            name = o.value;

            % defined() is settled before the argument is rendered: its whole point is to
            % ask about a variable that may not be bound, and rendering an unbound one
            % fails.
            if strcmp(name, 'defined')
                if isscalar(o.children) && strcmp(o.children{1}.type, 'sym')
                    str = sprintf('exist(''%s'', ''var'') == 1', o.children{1}.value);
                    ok = true;
                else
                    [str, ok] = macro.decline();
                end
                return
            end

            [parts, ok] = macro.children_to_matlab(o.children, env);
            if ~ok
                [str, ok] = macro.decline();
                return
            end
            if ismember(name, macro.UNARY_FUNCTIONS) || ismember(name, {'min', 'max', 'mod', 'sum', 'normpdf', 'normcdf'})
                str = sprintf('%s(%s)', name, strjoin(parts, ', '));
                return
            end
            switch name
              case 'ln'
                str = sprintf('log(%s)', parts{1});
              case 'cbrt'
                str = sprintf('nthroot(%s, 3)', parts{1});
              case 'trunc'
                str = sprintf('fix(%s)', parts{1});
              case 'lgamma'
                str = sprintf('gammaln(%s)', parts{1});
              case 'length'
                str = sprintf('length(%s)', parts{1});
              case 'isempty'
                str = sprintf('isempty(%s)', parts{1});
              case 'real'
                str = sprintf('double(%s)', parts{1});
              case 'bool'
                str = sprintf('logical(%s)', parts{1});
              case {'isboolean', 'isreal', 'isstring', 'isarray', 'istuple'}
                [str, ok] = macro.predicate_to_matlab(name, parts{1}, o.children{1}, env);
              case 'string'
                % The cast renders a value as text, which depends on what it is.
                switch macro.kind_of(o.children{1}, env)
                  case 'real'
                    str = sprintf('num2str(%s)', parts{1});
                  case 'string'
                    str = parts{1};
                  otherwise
                    [str, ok] = macro.decline();
                end
              otherwise
                % The casts to tuple and array have no MATLAB counterpart: a macro tuple
                % has no rendering at all, and array(x) of a scalar would be indist-
                % inguishable from the scalar itself.
                [str, ok] = macro.decline();
            end
        end % function

        function [str, ok] = predicate_to_matlab(name, rendered, node, env)
        % Render one of the kind predicates.
        %
        % These need care, because MATLAB spells two of them the same way and means
        % something else by them: isreal asks whether a number has no imaginary part, and
        % is true of a char array, while the macro isreal asks whether a value is a
        % number; and MATLAB's isstring is about the string class, and is false of the
        % char array a macro string renders to. Using either directly would be quietly
        % wrong, so each predicate maps to the MATLAB idiom that matches its meaning.
            ok = true;
            switch name
              case 'isboolean'
                str = sprintf('(islogical(%s) && isscalar(%s))', rendered, rendered);
              case 'isreal'
                str = sprintf('(isnumeric(%s) && isscalar(%s))', rendered, rendered);
              case 'isstring'
                str = sprintf('ischar(%s)', rendered);
              case 'isarray'
                str = sprintf('isa(%s, ''macroarray'')', rendered);
              case 'istuple'
                str = sprintf('isa(%s, ''macrotuple'')', rendered);
            end
        end % function

        function [kind, n] = kind_of(node, env)
        % The kind a subexpression evaluates to, and how many elements it holds.
            kind = '';
            n = 0;
            try
                v = node.eval(env);
            catch
                return
            end
            kind = v.kind;
            if ismember(kind, {'array', 'tuple'})
                n = numel(v.data);
            end
        end % function

        function [str, ok] = decline()
        % Report that a node has no faithful MATLAB rendering.
            str = '';
            ok = false;
        end % function

        function v = eval_unop(op, a)
        % Evaluate a unary operator.
            switch op
              case '-'
                macro.require(a, {'real'}, op);
                v = macro.mkreal(-a.data);
              case '+'
                macro.require(a, {'real'}, op);
                v = a;
              case '!'
                v = macro.mkbool(~macro.truth(a));
              otherwise
                error('macro:eval_unop:badType', 'Unknown unary macro operator "%s".', op)
            end
        end % function

        function v = eval_binop(op, a, b)
        % Evaluate a binary operator, following the semantics of Dynare's Expressions.cc:
        % on arrays '+' concatenates, '-' is the set difference, '*' is the Cartesian
        % product, '|' is the union and '&' the intersection.
            switch op
              case '+'
                if strcmp(a.kind, 'real') && strcmp(b.kind, 'real')
                    v = macro.mkreal(a.data + b.data);
                elseif strcmp(a.kind, 'string') && strcmp(b.kind, 'string')
                    v = macro.mkstring([a.data b.data]);
                elseif strcmp(a.kind, 'array') && strcmp(b.kind, 'array')
                    v = macro.mkarray([a.data, b.data]);
                else
                    error('macro:eval_binop:typeError', 'Cannot apply "+" to a %s and a %s.', a.kind, b.kind)
                end
              case '-'
                if strcmp(a.kind, 'real') && strcmp(b.kind, 'real')
                    v = macro.mkreal(a.data - b.data);
                elseif strcmp(a.kind, 'array') && strcmp(b.kind, 'array')
                    keep = cellfun(@(x) ~macro.contains(b, x), a.data);
                    v = macro.mkarray(a.data(keep));
                else
                    error('macro:eval_binop:typeError', 'Cannot apply "-" to a %s and a %s.', a.kind, b.kind)
                end
              case '*'
                if strcmp(a.kind, 'real') && strcmp(b.kind, 'real')
                    v = macro.mkreal(a.data * b.data);
                elseif strcmp(a.kind, 'array') && strcmp(b.kind, 'array')
                    items = {};
                    for i = 1:numel(a.data)
                        for j = 1:numel(b.data)
                            items{end+1} = macro.mktuple([macro.astuple(a.data{i}), macro.astuple(b.data{j})]); %#ok<AGROW>
                        end
                    end
                    v = macro.mkarray(items);
                else
                    error('macro:eval_binop:typeError', 'Cannot apply "*" to a %s and a %s.', a.kind, b.kind)
                end
              case '/'
                macro.require(a, {'real'}, op);
                macro.require(b, {'real'}, op);
                v = macro.mkreal(a.data / b.data);
              case '^'
                macro.require(a, {'real'}, op);
                macro.require(b, {'real'}, op);
                v = macro.mkreal(a.data ^ b.data);
              case {'<', '>', '<=', '>='}
                v = macro.mkbool(macro.compare(op, a, b));
              case '=='
                v = macro.mkbool(macro.equal(a, b));
              case '!='
                v = macro.mkbool(~macro.equal(a, b));
              case '&&'
                v = macro.mkbool(macro.truth(a) && macro.truth(b));
              case '||'
                v = macro.mkbool(macro.truth(a) || macro.truth(b));
              case 'in'
                macro.require(b, {'array'}, op);
                v = macro.mkbool(macro.contains(b, a));
              case '|'
                macro.require(a, {'array'}, op);
                macro.require(b, {'array'}, op);
                items = a.data;
                for i = 1:numel(b.data)
                    if ~macro.contains(macro.mkarray(items), b.data{i})
                        items{end+1} = b.data{i}; %#ok<AGROW>
                    end
                end
                v = macro.mkarray(items);
              case '&'
                macro.require(a, {'array'}, op);
                macro.require(b, {'array'}, op);
                keep = cellfun(@(x) macro.contains(b, x), a.data);
                v = macro.mkarray(a.data(keep));
              otherwise
                error('macro:eval_binop:badType', 'Unknown binary macro operator "%s".', op)
            end
        end % function

        function items = astuple(v)
        % Flatten a value into the cell of components a Cartesian product concatenates.
            if strcmp(v.kind, 'tuple')
                items = v.data;
            else
                items = {v};
            end
        end % function

        function v = eval_range(bounds)
        % Evaluate a range, in its two-bound and three-bound forms.
            for i = 1:numel(bounds)
                macro.require(bounds{i}, {'real'}, ':');
            end
            switch numel(bounds)
              case 2
                values = bounds{1}.data:bounds{2}.data;
              case 3
                values = bounds{1}.data:bounds{2}.data:bounds{3}.data;
              otherwise
                error('macro:eval_range:badType', 'A range takes two or three bounds.')
            end
            v = macro.mkarray(arrayfun(@macro.mkreal, values, 'UniformOutput', false));
        end % function

        function v = eval_index(base, idx)
        % Evaluate an indexing expression. Dynare indexes from 1, and accepts an array of
        % indices as well as a single one.
            if ~ismember(base.kind, {'array', 'tuple', 'string'})
                error('macro:eval_index:typeError', 'A %s cannot be indexed.', base.kind)
            end
            switch idx.kind
              case 'real'
                positions = idx.data;
              case 'array'
                positions = cellfun(@(x) x.data, idx.data);
              otherwise
                error('macro:eval_index:typeError', 'An index must be a real or an array of reals, not a %s.', idx.kind)
            end
            if strcmp(base.kind, 'string')
                macro.check_bounds(positions, length(base.data));
                v = macro.mkstring(base.data(positions));
                return
            end
            macro.check_bounds(positions, numel(base.data));
            if isscalar(positions)
                v = base.data{positions};
            else
                v = macro.mkarray(base.data(positions));
            end
        end % function

        function v = eval_comprehension(o, env)
        % Evaluate a comprehension, following Dynare's Expressions.cc: the index runs over
        % the input set, the guard decides which iterations contribute, and the output
        % expression is what each of them contributes.
        %
        % The index is bound in a copy of the environment and does not outlive the
        % comprehension. Dynare binds it in the enclosing one and leaves it there, which
        % only tells the two apart in a file reading the index afterwards -- where the
        % value would be whatever the last iteration happened to bind.
            set = o.children{3}.eval(env);
            if ~strcmp(set.kind, 'array')
                error('macro:eval_comprehension:typeError', 'The input set of a comprehension must be an array, not a %s.', set.kind)
            end
            items = {};
            for i = 1:numel(set.data)
                inner = macro.bind_index(o.children{2}, set.data{i}, env);
                if numel(o.children) > 3 && ~macro.truth(o.children{4}.eval(inner))
                    continue
                end
                items{end+1} = o.children{1}.eval(inner); %#ok<AGROW>
            end
            v = macro.mkarray(items);
        end % function

        function env = bind_index(indices, value, env)
        % Bind the index of a comprehension to one element of the input set, destructuring
        % a tuple when there are several indices.
            if strcmp(indices.type, 'sym')
                env.vars(string(indices.value)) = value;
                return
            end
            if ~strcmp(value.kind, 'tuple') || numel(value.data) ~= numel(indices.children)
                error('macro:eval_comprehension:typeError', 'A comprehension over %u indices needs an input set of tuples of %u element(s).', numel(indices.children), numel(indices.children))
            end
            for i = 1:numel(indices.children)
                env.vars(string(indices.children{i}.value)) = value.data{i};
            end
        end % function

        function [str, ok] = comprehension_to_matlab(o, env)
        % Render a comprehension as a call to filter, to map, or to both.
        %
        % Worth doing rather than declining, because the evaluated literal would freeze the
        % relation between the two settings: a script where the input set is a variable
        % should still answer the comprehension when that variable is edited.
        %
        % The body renders in an environment where the index is bound to the first element
        % of the input set, since what a subexpression renders to depends on the kinds it
        % works on. That is only sound when the elements all have the same kind, and a set
        % mixing kinds is declined rather than rendered from whichever came first.
            indices = o.children{2};
            if ~strcmp(indices.type, 'sym')
                % Destructuring would have to rewrite the components of the index into the
                % components of the argument of the anonymous function.
                [str, ok] = macro.decline();
                return
            end

            [set, ok] = o.children{3}.to_matlab(env);
            inner = macro.bind_first(indices, o.children{3}, env);
            if ~ok || isempty(inner)
                [str, ok] = macro.decline();
                return
            end

            str = set;
            if numel(o.children) > 3
                [guard, ok] = o.children{4}.to_matlab(inner);
                if ~ok
                    [str, ok] = macro.decline();
                    return
                end
                str = sprintf('filter(%s, @(%s) %s)', str, indices.value, guard);
            end

            % The filtering form gives back the elements themselves, so it is a filter and
            % nothing else; anything else the index maps to is a map on top.
            if strcmp(o.children{1}.type, 'sym') && strcmp(o.children{1}.value, indices.value)
                return
            end
            [body, ok] = o.children{1}.to_matlab(inner);
            if ~ok
                [str, ok] = macro.decline();
                return
            end
            str = sprintf('map(%s, @(%s) %s)', str, indices.value, body);
        end % function

        function env = bind_first(indices, set, env)
        % The environment the body of a comprehension renders in, or empty when there is
        % nothing sound to render it from.
            try
                values = set.eval(env);
            catch
                env = [];
                return
            end
            if ~strcmp(values.kind, 'array') || isempty(values.data) || ~all(cellfun(@(x) strcmp(x.kind, values.data{1}.kind), values.data))
                env = [];
                return
            end
            env.vars(string(indices.value)) = values.data{1};
        end % function

        function check_bounds(positions, n)
        % Reject an out-of-range or non-integer index.
            if any(positions < 1) || any(positions > n) || any(positions ~= fix(positions))
                error('macro:eval_index:outOfBounds', 'Index out of the range 1..%u.', n)
            end
        end % function

        function v = eval_call(o, env)
        % Evaluate a function call: a user-defined macro function, a cast, a predicate,
        % or one of the built-in mathematical functions.
            name = o.value;

            if isKey(env.funcs, string(name))
                fn = env.funcs(string(name));
                if numel(fn.args) ~= numel(o.children)
                    error('macro:eval_call:badArity', 'Macro function "%s" takes %u argument(s), %u given.', name, numel(fn.args), numel(o.children))
                end
                % Dynare's function macros are dynamically scoped: the body sees the
                % caller's variables, with the formals bound on top. dictionary is a
                % value type, so this copy is cheap.
                child = env;
                for i = 1:numel(fn.args)
                    child.vars(string(fn.args{i})) = o.children{i}.eval(env);
                end
                v = fn.body.eval(child);
                return
            end

            if strcmp(name, 'defined')
                if ~isscalar(o.children) || ~strcmp(o.children{1}.type, 'sym')
                    error('macro:eval_call:badArity', 'defined() takes the name of a macro variable.')
                end
                v = macro.mkbool(isKey(env.vars, string(o.children{1}.value)));
                return
            end

            args = cellfun(@(c) c.eval(env), o.children, 'UniformOutput', false);

            if ismember(name, macro.CASTS)
                v = macro.eval_cast(name, args);
                return
            end
            if ismember(name, macro.PREDICATES)
                v = macro.eval_predicate(name, args);
                return
            end

            v = macro.eval_builtin(name, args);
        end % function

        function v = eval_cast(name, args)
        % Evaluate one of the bool, real, string, tuple and array casts.
            if ~isscalar(args)
                error('macro:eval_cast:badArity', 'The cast "%s" takes one argument.', name)
            end
            a = args{1};
            switch name
              case 'bool'
                v = macro.mkbool(macro.truth(a));
              case 'real'
                switch a.kind
                  case 'real'
                    v = a;
                  case 'bool'
                    v = macro.mkreal(double(a.data));
                  case 'string'
                    number = str2double(a.data);
                    if isnan(number)
                        error('macro:eval_cast:typeError', '"%s" cannot be converted to a real.', a.data)
                    end
                    v = macro.mkreal(number);
                  otherwise
                    error('macro:eval_cast:typeError', 'A %s cannot be converted to a real.', a.kind)
                end
              case 'string'
                v = macro.mkstring(macro.tostring(a));
              case 'tuple'
                v = macro.mktuple(macro.aslist(a));
              case 'array'
                v = macro.mkarray(macro.aslist(a));
            end
        end % function

        function items = aslist(v)
        % View a value as the list of its components, wrapping a scalar in a singleton.
            if ismember(v.kind, {'array', 'tuple'})
                items = v.data;
            else
                items = {v};
            end
        end % function

        function v = eval_predicate(name, args)
        % Evaluate one of the kind predicates.
            if ~isscalar(args)
                error('macro:eval_predicate:badArity', 'The predicate "%s" takes one argument.', name)
            end
            a = args{1};
            switch name
              case 'isempty'
                switch a.kind
                  case {'array', 'tuple'}
                    v = macro.mkbool(isempty(a.data));
                  case 'string'
                    v = macro.mkbool(isempty(a.data));
                  otherwise
                    v = macro.mkbool(false);
                end
              case 'isboolean'
                v = macro.mkbool(strcmp(a.kind, 'bool'));
              case 'isreal'
                v = macro.mkbool(strcmp(a.kind, 'real'));
              case 'isstring'
                v = macro.mkbool(strcmp(a.kind, 'string'));
              case 'istuple'
                v = macro.mkbool(strcmp(a.kind, 'tuple'));
              case 'isarray'
                v = macro.mkbool(strcmp(a.kind, 'array'));
            end
        end % function

        function v = eval_builtin(name, args)
        % Evaluate one of the built-in mathematical functions.
            switch name
              case 'length'
                if ~isscalar(args)
                    error('macro:eval_builtin:badArity', 'length() takes one argument.')
                end
                switch args{1}.kind
                  case {'array', 'tuple'}
                    v = macro.mkreal(numel(args{1}.data));
                  case 'string'
                    v = macro.mkreal(length(args{1}.data));
                  otherwise
                    error('macro:eval_builtin:typeError', 'length() does not apply to a %s.', args{1}.kind)
                end
                return
              case 'sum'
                if ~isscalar(args)
                    error('macro:eval_builtin:badArity', 'sum() takes one argument.')
                end
                macro.require(args{1}, {'array'}, name);
                total = 0;
                for i = 1:numel(args{1}.data)
                    macro.require(args{1}.data{i}, {'real'}, name);
                    total = total + args{1}.data{i}.data;
                end
                v = macro.mkreal(total);
                return
            end

            for i = 1:numel(args)
                macro.require(args{i}, {'real'}, name);
            end
            x = cellfun(@(a) a.data, args);

            if ismember(name, macro.UNARY_FUNCTIONS)
                if ~isscalar(x)
                    error('macro:eval_builtin:badArity', '%s() takes one argument.', name)
                end
                v = macro.mkreal(feval(name, x));
                return
            end

            switch name
              case 'ln'
                v = macro.mkreal(log(x));
              case 'cbrt'
                v = macro.mkreal(nthroot(x, 3));
              case 'trunc'
                v = macro.mkreal(fix(x));
              case 'lgamma'
                v = macro.mkreal(gammaln(x));
              case {'min', 'max', 'mod'}
                if numel(x) ~= 2
                    error('macro:eval_builtin:badArity', '%s() takes two arguments.', name)
                end
                v = macro.mkreal(feval(name, x(1), x(2)));
              case {'normpdf', 'normcdf'}
                switch numel(x)
                  case 1
                    v = macro.mkreal(feval(name, x));
                  case 3
                    v = macro.mkreal(feval(name, x(1), x(2), x(3)));
                  otherwise
                    error('macro:eval_builtin:badArity', '%s() takes one or three arguments.', name)
                end
              otherwise
                error('macro:eval_builtin:unknownFunction', '"%s" is not a macro function.', name)
            end
        end % function

        function require(v, kinds, context)
        % Reject a value whose kind is not one of the expected ones.
            if ~ismember(v.kind, kinds)
                error('macro:eval:typeError', '"%s" does not apply to a %s.', context, v.kind)
            end
        end % function

        function tf = equal(a, b)
        % Structural equality of two values.
            if ~strcmp(a.kind, b.kind)
                tf = false;
                return
            end
            switch a.kind
              case {'real', 'bool'}
                tf = isequal(a.data, b.data);
              case 'string'
                tf = strcmp(a.data, b.data);
              otherwise
                tf = numel(a.data) == numel(b.data);
                if tf
                    for i = 1:numel(a.data)
                        if ~macro.equal(a.data{i}, b.data{i})
                            tf = false;
                            return
                        end
                    end
                end
            end
        end % function

        function tf = contains(container, item)
        % Membership of a value in an array or tuple.
            tf = false;
            for i = 1:numel(container.data)
                if macro.equal(container.data{i}, item)
                    tf = true;
                    return
                end
            end
        end % function

        function tf = compare(op, a, b)
        % Ordering of two reals or two strings.
            if strcmp(a.kind, 'real') && strcmp(b.kind, 'real')
                left = a.data;
                right = b.data;
            elseif strcmp(a.kind, 'string') && strcmp(b.kind, 'string')
                order = [{a.data}; {b.data}];
                [~, rank] = sort(order);
                left = rank(1);
                right = rank(2);
                if strcmp(a.data, b.data)
                    left = 1;
                    right = 1;
                end
            else
                error('macro:eval_binop:typeError', 'Cannot compare a %s with a %s.', a.kind, b.kind)
            end
            switch op
              case '<'
                tf = left < right;
              case '>'
                tf = left > right;
              case '<='
                tf = left <= right;
              case '>='
                tf = left >= right;
            end
        end % function

        function str = token_text(token)
        % Render a token for an error message.
            if ischar(token.value)
                str = token.value;
            else
                str = num2str(token.value);
            end
        end % function

    end % methods

end % classdef
