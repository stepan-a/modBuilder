% The macro expression engine: parsing, evaluation, and MATLAB rendering.

addpath ../utils

env = macro.environment(struct('N', 3, 'Countries', {{'US', 'EA'}}, 'Open', true));

value = @(expr) macro.tostring(macro(expr).eval(env));
kind  = @(expr) macro(expr).eval(env).kind;

% --- Arithmetic and precedence ---------------------------------------------------------
assert(strcmp(value('1 + 2*3'), '7'), 'Multiplication should bind tighter than addition.');
assert(strcmp(value('(1 + 2)*3'), '9'), 'Parentheses should group.');
assert(strcmp(value('2^3^2'), '512'), 'Exponentiation should be right-associative.');
assert(strcmp(value('-2^2'), '-4'), 'Unary minus should bind looser than exponentiation.');
assert(strcmp(value('7/2'), '3.5'), 'Division should be exact.');

% --- Ranges ----------------------------------------------------------------------------
assert(strcmp(value('1:5'), '[1, 2, 3, 4, 5]'), 'Two-bound range.');
assert(strcmp(value('1:2:7'), '[1, 3, 5, 7]'), 'Three-bound range.');

% --- The type system -------------------------------------------------------------------
assert(strcmp(kind('1'), 'real'), 'A number is a real.');
assert(strcmp(kind('true'), 'bool'), 'true is a boolean, not a real.');
assert(strcmp(kind('"x"'), 'string'), 'A quoted literal is a string.');
assert(strcmp(kind('[1, 2]'), 'array'), 'Brackets build an array.');
assert(strcmp(kind('(1, 2)'), 'tuple'), 'A parenthesised list with a comma is a tuple.');
assert(strcmp(kind('(1)'), 'real'), 'A parenthesised single value is grouping, not a tuple.');

% Booleans render as true and false, which is why they cannot be carried as doubles.
assert(strcmp(value('true'), 'true'), 'A boolean should render as true.');
assert(strcmp(value('1 == 1'), 'true'), 'A comparison yields a boolean.');

% --- Set operations, per Dynare's Expressions.cc ----------------------------------------
assert(strcmp(value('["US","EA"] + ["JP"]'), '[US, EA, JP]'), '+ concatenates arrays.');
assert(strcmp(value('["US","EA"] - ["EA"]'), '[US]'), '- is the set difference.');
assert(strcmp(value('["US","EA"] | ["EA","JP"]'), '[US, EA, JP]'), '| is the union.');
assert(strcmp(value('["US","EA"] & ["EA","JP"]'), '[EA]'), '& is the intersection.');
assert(strcmp(value('[1,2] * ["a","b"]'), '[(1, a), (1, b), (2, a), (2, b)]'), '* is the Cartesian product.');
assert(strcmp(value('[1,2]^2'), '[(1, 1), (1, 2), (2, 1), (2, 2)]'), '^ is the Cartesian power.');
assert(strcmp(value('[1,2]^3'), '[(1, 1, 1), (1, 1, 2), (1, 2, 1), (1, 2, 2), (2, 1, 1), (2, 1, 2), (2, 2, 1), (2, 2, 2)]'), 'A Cartesian power flattens its tuples, as the product does.');
assert(strcmp(value('[1,2]^1'), '[1, 2]'), 'The first Cartesian power is the array itself.');
assert(strcmp(value('"EA" in Countries'), 'true'), 'in tests membership.');
assert(strcmp(value('"JP" in Countries'), 'false'), 'in tests membership.');

% --- Strings ---------------------------------------------------------------------------
assert(strcmp(value('"y_" + "US"'), 'y_US'), '+ concatenates strings.');
assert(strcmp(value('"a" < "b"'), 'true'), 'Strings compare lexicographically.');

% --- Indexing, from 1 ------------------------------------------------------------------
assert(strcmp(value('Countries[1]'), 'US'), 'Indexing starts at 1.');
assert(strcmp(value('[1,2,3][2:3]'), '[2, 3]'), 'An array of indices selects a sub-array.');

% --- Functions, casts and predicates ---------------------------------------------------
assert(strcmp(value('length(Countries)'), '2'), 'length of an array.');
assert(strcmp(value('sum([1,2,3])'), '6'), 'sum of an array.');
assert(strcmp(value('max(3, 7)'), '7'), 'max of two reals.');
assert(strcmp(value('mod(7, 3)'), '1'), 'mod of two reals.');
assert(strcmp(value('floor(2.7)'), '2'), 'floor.');
assert(strcmp(value('ln(1)'), '0'), 'ln is an alias for log.');
assert(strcmp(value('real("2.5")'), '2.5'), 'The real cast parses a string.');
assert(strcmp(value('string(3)'), '3'), 'The string cast renders a value.');
assert(strcmp(value('(string) 3'), '3'), 'A cast may be spelled C-style.');
assert(strcmp(value('(string) 2 + "x"'), '2x'), 'A C-style cast binds tighter than +.');
assert(strcmp(value('(real) "2" + 1'), '3'), 'The cast applies before the addition.');
assert(strcmp(value('(string) 2 ^ 2 + "x"'), '4x'), 'A C-style cast binds looser than ^.');
assert(strcmp(value('isarray(Countries)'), 'true'), 'isarray.');
assert(strcmp(value('istuple((1,2))'), 'true'), 'istuple distinguishes tuples from arrays.');
assert(strcmp(value('isarray((1,2))'), 'false'), 'A tuple is not an array.');
assert(strcmp(value('defined(N)'), 'true'), 'defined on a bound variable.');
assert(strcmp(value('defined(Missing)'), 'false'), 'defined on an unbound variable.');

% --- Function macros are dynamically scoped, as in Dynare ------------------------------
env.funcs("twice") = struct('args', {{'x'}}, 'body', macro('2*x'));
assert(strcmp(macro.tostring(macro('twice(N) + 1').eval(env)), '7'), 'A function macro should be applied.');
env.funcs("scaled") = struct('args', {{'x'}}, 'body', macro('x*N'));
assert(strcmp(macro.tostring(macro('scaled(2)').eval(env)), '6'), 'A function body should see the caller globals.');

% --- MATLAB rendering ------------------------------------------------------------------
% Rendering must be kind-aware: '+' is addition on reals but concatenation on strings,
% and MATLAB's '+' on two char arrays would silently add their code points instead.
render = @(expr) local_render(macro(expr), env);

assert(strcmp(render('N > 2 && Open'), '((N > 2) && Open)'), 'Comparison and conjunction.');
assert(strcmp(render('"y_" + "US"'), '[''y_'', ''US'']'), 'String concatenation must not become arithmetic.');
assert(strcmp(render('1 + 2'), '(1 + 2)'), 'Real addition stays addition.');
assert(strcmp(render('["a"] | ["b"]'), '(macroarray(''a'') | macroarray(''b''))'), 'Union goes through the overload.');
assert(strcmp(render('Countries[1]'), 'Countries{1}'), 'An element is taken with braces.');
assert(strcmp(render('length(Countries)'), 'length(Countries)'), 'length is overloaded.');

% --- The kind predicates -----------------------------------------------------------
% MATLAB spells two of these the same way and means something else by them: its isreal
% asks whether a number has no imaginary part and is TRUE of a char array, and its
% isstring is about the string class and is FALSE of the char array a macro string
% renders to. Each predicate therefore maps to the MATLAB idiom that matches its meaning,
% and the renderings are checked here against the macro answers rather than by eye.
probe = macro.environment(struct('R', 3, 'B', true, 'S', 'abc', 'A', {{'x', 'y'}}));
R = 3; B = true; S = 'abc'; A = macroarray('x', 'y'); %#ok<NASGU>

predicates = {'isreal(R)', 'isreal(S)', 'isreal(A)', 'isboolean(B)', 'isboolean(R)', ...
              'isstring(S)', 'isstring(R)', 'isstring(A)', ...
              'isarray(A)', 'isarray(R)', 'isarray(S)', 'istuple(A)', ...
              'isempty(A)', 'defined(R)', 'defined(Nowhere)'};

for i = 1:numel(predicates)
    tree = macro(predicates{i});
    [rendered, ok] = tree.to_matlab(probe);
    assert(ok, sprintf('"%s" should render.', predicates{i}));
    assert(isequal(logical(eval(rendered)), tree.eval(probe).data), ...
           sprintf('"%s" renders as "%s", which disagrees with the macro answer.', predicates{i}, rendered));
end

% Naive mappings would have been silently wrong, which is what the above guards against.
assert(isreal('abc'), 'MATLAB isreal is true of a char array, so it cannot spell the macro isreal.');
assert(~isstring('abc'), 'MATLAB isstring is false of a char array, so it cannot spell the macro isstring.');

% string() renders a value as text.
assert(strcmp(eval(local_render(macro('string(R)'), probe)), '3'), 'string() of a real.');
assert(strcmp(eval(local_render(macro('string(S)'), probe)), 'abc'), 'string() of a string.');

% --- Arrays and tuples carry their kind in the MATLAB type ------------------------------
% A plain cell could not keep them apart: an array of one real is the same double as the
% real, and a tuple is the same cell as an array of the same elements. macroarray and
% macrotuple exist so that a generated script answers the predicates as the macro
% language does.
assert(strcmp(render('[1, 2, 3]'), 'macroarray(1, 2, 3)'), 'An array renders through its class.');
assert(strcmp(render('(1, "a")'), 'macrotuple(1, ''a'')'), 'A tuple renders through its class.');
assert(strcmp(render('[(1, "a"), (2, "b")]'), 'macroarray(macrotuple(1, ''a''), macrotuple(2, ''b''))'), 'An array of tuples should render.');

% The three cases a plain cell would confuse are now all distinguished.
kinds = macro.environment(struct('One', {{7}}, 'Pair', macro.mktuple({macro.mkreal(1), macro.mkreal(2)}), 'R', 7));
One = macroarray(7); Pair = macrotuple(1, 2); R = 7; %#ok<NASGU>
assert(eval(local_render(macro('isarray(One)'), kinds)), 'A one-element array is an array.');
assert(~eval(local_render(macro('isreal(One)'), kinds)), 'A one-element array is not a real.');
assert(eval(local_render(macro('isreal(R)'), kinds)), 'A real is a real.');
assert(~eval(local_render(macro('isarray(R)'), kinds)), 'A real is not an array.');
assert(eval(local_render(macro('istuple(Pair)'), kinds)), 'A tuple is a tuple.');
assert(~eval(local_render(macro('isarray(Pair)'), kinds)), 'A tuple is not an array.');
assert(~eval(local_render(macro('istuple(One)'), kinds)), 'An array is not a tuple.');

% Every operator the macro language defines on arrays has an overload, so the rendered
% MATLAB computes what the macro engine computes.
ops = macro.environment(struct('A', {{'US', 'EA'}}, 'B', {{'EA', 'JP'}}, 'N', {{1, 2}}));
A = macroarray('US', 'EA'); B = macroarray('EA', 'JP'); N = macroarray(1, 2); %#ok<NASGU>

operations = {'A + B', 'A - B', 'A | B', 'A & B', 'N * A', 'A == A', 'A != B', ...
              '"EA" in A', 'length(A)', 'sum(N)', 'isempty(A)', 'A[1]', 'A[1:2]'};
for i = 1:numel(operations)
    tree = macro(operations{i});
    got = eval(local_render(tree, ops));
    if isa(got, 'macrolist')
        gotstr = string(got);
    elseif islogical(got)
        gotstr = macro.tostring(macro.mkbool(got));
    elseif ischar(got)
        gotstr = got;
    else
        gotstr = num2str(got);
    end
    assert(strcmp(gotstr, macro.tostring(tree.eval(ops))), ...
           sprintf('"%s" renders to MATLAB that computes something else.', operations{i}));
end

% --- Errors ----------------------------------------------------------------------------
assert_id(@() macro('1 +'), 'macro:parse:unexpectedEnd');
assert_id(@() macro('1 $ 2'), 'macro:tokenise:badCharacter');
assert_id(@() macro('[1, 2').eval(env), 'macro:parse:missingToken');
assert_id(@() macro('Missing').eval(env), 'macro:eval:undefinedVariable');
assert_id(@() macro('1 + "a"').eval(env), 'macro:eval_binop:typeError');
assert_id(@() macro('Countries[9]').eval(env), 'macro:eval_index:outOfBounds');

% --- What Dynare's own macro-processor self-test checks ---------------------------------
% inf and nan are numbers, rendered in lower case as the preprocessor does.
assert(strcmp(value('inf'), 'inf') && strcmp(value('-inf'), '-inf') && strcmp(value('nan'), 'nan'), 'inf and nan are literals.');
assert(strcmp(value('log(0) == -inf && 1/0 == inf'), 'true'), 'Arithmetic reaches the infinities.');
assert(strcmp(value('5 < nan || 5 >= inf'), 'false'), 'Comparisons with nan and inf.');

% Strings order by character code.
assert(strcmp(value('"Aaaaaaaa" > "B" || "AA" != "AA"'), 'false'), 'String ordering is lexicographic by code.');

% An index list may hold ranges, which are flattened into it.
env.vars("Phrase") = macro.mkstring('La crise economique');
value = @(expr) macro.tostring(macro(expr).eval(env)); % an anonymous function captures env when made
assert(strcmp(value('Phrase[1,8,3,7,4,10,13,2,5,16,12,9,11,14,15,6,17:19]'), 'Le scenario comique'), 'A comma list of indices, with a range inside.');
assert(strcmp(value('(1:5)[1:2, 4]'), '[1, 2, 4]'), 'A range in an index list is flattened.');

% && and || short-circuit, so the right operand may be anything when it is not needed.
assert(strcmp(value('true || "A"'), 'true') && strcmp(value('0 && "A"'), 'false'), 'Short-circuit evaluation.');

% The bool cast of a string reads true and false in any case, and a number otherwise.
assert(strcmp(value('(bool)"FaLse" || !(bool)"TRUE" || (bool)"0" || !(bool)"-3"'), 'false'), 'String to bool cast.');

% Casts chain, and a real turns into a one-element array.
assert(strcmp(value('[1] + (array)(real) "2"'), '[1, 2]'), 'Chained casts.');

% Ranges with a negative, zero or overshooting step.
assert(strcmp(value('-3:-1.5:3'), '[]') && strcmp(value('3:-1:-0.1'), '[3, 2, 1, 0]') && strcmp(value('1:0:1'), '[]') && strcmp(value('0:0'), '[0]') && strcmp(value('-1:5:-1'), '[-1]'), 'Range edge cases.');

% A range renders as an array of the language, a subscript as a MATLAB vector.
env.vars("N") = macro.mkreal(3);
env.vars("Arr") = macro.mkarray({macro.mkreal(10), macro.mkreal(20), macro.mkreal(30), macro.mkreal(40)});
render = @(expr) macro(expr).to_matlab(env);
assert(strcmp(render('1:N'), 'macroarray(1:N)'), sprintf('A range should render as a macroarray, got %s.', render('1:N')));
assert(strcmp(render('Arr[2:3]'), 'Arr(2:3)') && strcmp(render('Arr[1, 3:4]'), 'Arr([1, 3:4])') && strcmp(render('Arr[2]'), 'Arr{2}'), 'Subscripts render as MATLAB vectors.');

% The casts of a string: real reads the number, bool has no MATLAB form and is declined.
assert(strcmp(render('(real) "2"'), 'str2double(''2'')'), 'The real cast of a string reads it.');
[~, ok] = macro('(bool) "FaLse"').to_matlab(env);
assert(~ok, 'The bool cast of a string should be declined, so that the literal is emitted.');

fprintf('t06_expressions.m: All tests passed\n');

function str = local_render(tree, env)
    [str, ok] = tree.to_matlab(env);
    assert(ok, 'Expected a MATLAB rendering.');
end

function assert_id(fn, expected)
    thrown = '';
    try
        fn();
    catch ME
        thrown = ME.identifier;
    end
    assert(strcmp(thrown, expected), sprintf('Expected %s, got "%s".', expected, thrown));
end
