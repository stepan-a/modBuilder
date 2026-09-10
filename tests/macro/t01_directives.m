% The macro directives: @#define, @#if, @#for, @{...}, @#include.

addpath ../utils

% Several cases below are deliberately not templatable; the warning that says so is
% checked where it matters and silenced elsewhere.
ws = warning('off', 'modfile:expand_macros:loopNotTemplatable');
restore = onCleanup(@() warning(ws));

% --- @#define and @{...} ---------------------------------------------------------------
src = sprintf('@#define N = 3\n@#define Name = "growth"\nparameters p_@{Name} q_@{N};\n');
[out, info] = modfile.expand_macros(src);
assert(contains(out, 'parameters p_growth q_3;'), sprintf('Unexpected expansion: %s', out));
assert(info.used, 'The file uses the macro language.');
assert(isequal(info.defines(:,1)', {'N', 'Name'}), 'Both defines should be reported.');
assert(strcmp(info.defines{1,2}, '3') && strcmp(info.defines{2,2}, '''growth'''), 'Defines should render as MATLAB.');

% A define with no value is a flag set to true.
[~, info] = modfile.expand_macros(sprintf('@#define Flag\nvar y;\n'));
assert(strcmp(info.defines{1,2}, 'true'), 'A valueless define should be true.');

% Line count is preserved through a non-directive line, so @{...} cannot shift anything.
out = modfile.expand_macros(sprintf('@#define k = 2\nvar y_@{k};\nvarexo e;\n'));
assert(count(out, newline) == 2, 'Directive lines are removed, text lines are kept.');

% An @{...} may span lines. As in Dynare the newlines inside the braces are dropped, so
% the text after the closing brace continues the line the @{ opened.
[out, info] = modfile.expand_macros(sprintf('@#define C = ["US", "EA"]\nvar y_@{\n  C[1]\n} z_@{C[2]\n};\nvarexo e;\n'));
assert(strcmp(out, sprintf('var y_US z_EA;\nvarexo e;\n')), sprintf('Unexpected expansion of a multi-line @{...}: %s', out));
assert(numel(info.context) == 3, 'One context entry per output line, the joined line counting once.');

out = modfile.expand_macros(sprintf('@#define C = ["US", "EA"]\n@#for c in C\nvar y_@{\nc};\n@#endfor\n'));
assert(strcmp(strtrim(out), sprintf('var y_US;\nvar y_EA;')), 'A multi-line @{...} inside a loop body should expand per iteration.');

% The lines are gathered even in a branch that is not taken, and evaluated only in one
% that is.
out = modfile.expand_macros(sprintf('@#if false\nvar y_@{\nUndefined\n};\n@#endif\nvar y;\n'));
assert(strcmp(strtrim(out), 'var y;'), 'A multi-line @{...} in an inactive branch should be skipped whole.');

thrown = '';
message = '';
try
    modfile.expand_macros(sprintf('var y;\nvar z_@{\n1 +\n'));
catch ME
    thrown = ME.identifier;
    message = ME.message;
end
assert(strcmp(thrown, 'modfile:expand_macros:unterminatedEval'), sprintf('Expected expand_macros:unterminatedEval, got "%s".', thrown));
assert(contains(message, 'line 2'), 'The error should name the line that opened the @{.');

% One @{...} inside another is a syntax error for Dynare, and is reported rather than
% expanded.
thrown = '';
try
    modfile.expand_macros(sprintf('@#define C = ["US", "EA"]\n@#define i = 1\nvar y_@{C[@{i}]};\n'));
catch ME
    thrown = ME.identifier;
end
assert(strcmp(thrown, 'modfile:expand_macros:badEval'), sprintf('Expected expand_macros:badEval, got "%s".', thrown));

% A directive line may end with a // comment, which is dropped; a // inside a quoted
% string is not a comment.
src = sprintf('@#define N = 3 // three\n@#define S = "a//b" // path-like\n@#if N > 2 // big\nvar y_@{S}_@{N};\n@#else // small\nvar z;\n@#endif // done\n@#for i in [1, 2] // loop\nvar w_@{i};\n@#endfor // end\n');
[out, info] = modfile.expand_macros(src);
assert(strcmp(strtrim(out), sprintf('var y_a//b_3;\nvar w_1;\nvar w_2;')), sprintf('Unexpected expansion with commented directives: %s', out));
assert(strcmp(info.defines{1,2}, '3') && strcmp(info.defines{2,2}, '''a//b'''), 'The comment should not reach the rendered define.');
assert(strcmp(info.conditionals(1).conds{1}, '(N > 2)'), 'The comment should not reach the rendered condition.');

% A directive line ending with \\ continues on the next one, and a // comment may follow
% the backslashes.
out = modfile.expand_macros(sprintf('@#define L = [1, \\\\\n   2] // two\n@#if L != [1, 2] \\\\ // never\n   || false\n@#error "continuation"\n@#endif\nvar y_@{L[2]};\n'));
assert(strcmp(strtrim(out), 'var y_2;'), sprintf('Unexpected expansion with continued directives: %s', out));

% --- @#if / @#elseif / @#else / @#endif ------------------------------------------------
conditional = @(flag) modfile.expand_macros(sprintf('@#define Open = %s\n@#if Open\nyes\n@#else\nno\n@#endif\n', flag));
assert(contains(conditional('true'), 'yes') && ~contains(conditional('true'), 'no'), 'The taken branch should survive.');
assert(contains(conditional('false'), 'no') && ~contains(conditional('false'), 'yes'), 'The other branch should survive.');

out = modfile.expand_macros(sprintf('@#define n = 2\n@#if n == 1\none\n@#elseif n == 2\ntwo\n@#else\nother\n@#endif\n'));
assert(contains(out, 'two') && ~contains(out, 'one') && ~contains(out, 'other'), 'elseif should select its branch.');

% A branch that is not taken may mention variables only the other branch defines: its
% expressions must not be evaluated.
out = modfile.expand_macros(sprintf('@#if false\n@{Undefined}\n@#endif\nvar y;\n'));
assert(contains(out, 'var y;'), 'An inactive branch should not be evaluated.');

% ifdef and ifndef
assert(contains(modfile.expand_macros(sprintf('@#define X = 1\n@#ifdef X\nhere\n@#endif\n')), 'here'), 'ifdef on a bound variable.');
assert(contains(modfile.expand_macros(sprintf('@#ifndef X\nhere\n@#endif\n')), 'here'), 'ifndef on an unbound variable.');

% --- @#for -----------------------------------------------------------------------------
% Every expanded line carries the frames of the directives it came from, which is what
% lets the translator put the control flow back into the generated script.
[out, info] = modfile.expand_macros(sprintf('@#define C = ["US","EA"]\n@#for c in C\nvar y_@{c};\n@#endfor\n'));
lines = strsplit(out, newline);
assert(contains(out, 'var y_US;') && contains(out, 'var y_EA;'), 'The loop should expand.');
assert(numel(info.context) == numel(lines), 'Every output line should carry a context.');

body = find(contains(lines, 'var y_'));
for k = body
    frames = info.context{k};
    assert(isscalar(frames) && strcmp(frames.kind, 'for'), 'A loop body line should carry one for frame.');
    assert(isequal(frames.names, {'c'}), 'The frame should name the loop index.');
end
assert(isequal(info.context{body(1)}.values, {'US'}), 'The first iteration binds US.');
assert(isequal(info.context{body(2)}.values, {'EA'}), 'The second iteration binds EA.');
assert(info.context{body(1)}.iter == 1 && info.context{body(2)}.iter == 2, 'Iterations should be numbered.');

% Nested loops give a two-frame context, outermost first.
[out, info] = modfile.expand_macros(sprintf('@#for i in [1,2]\n@#for j in ["a","b"]\nx_@{i}_@{j}\n@#endfor\n@#endfor\n'));
lines = strsplit(out, newline);
assert(contains(out, 'x_1_a') && contains(out, 'x_2_b'), 'Nested loops should expand.');
first = find(contains(lines, 'x_1_a'), 1);
assert(numel(info.context{first}) == 2, 'A doubly nested line should carry two frames.');
assert(isequal(info.context{first}(1).values, {1}) && isequal(info.context{first}(2).values, {'a'}), 'Both indices should be recorded.');

% A range as the index set.
out = modfile.expand_macros(sprintf('@#for i in 1:3\nvar y_@{i};\n@#endfor\n'));
assert(contains(out, 'var y_1;') && contains(out, 'var y_3;'), 'A range should drive the loop.');

% Tuple destructuring.
out = modfile.expand_macros(sprintf('@#for (i, j) in [1,2] * ["a","b"]\nx_@{i}@{j}\n@#endfor\n'));
assert(contains(out, 'x_1a') && contains(out, 'x_2b'), 'Tuples should be destructured.');

% The when guard filters iterations. Only the ones that ran are recorded, so the guard
% shows up as a shorter list of values rather than as a case of its own.
[out, info] = modfile.expand_macros(sprintf('@#for i in 1:4 when mod(i, 2) == 0\nvar y_@{i};\n@#endfor\n'));
lines = strsplit(out, newline);
assert(contains(out, 'var y_2;') && contains(out, 'var y_4;') && ~contains(out, 'var y_1;'), 'The guard should filter.');
body = find(contains(lines, 'var y_'));
assert(numel(body) == 2, 'Two iterations should survive the guard.');
assert(isequal(info.context{body(1)}.values, {2}) && isequal(info.context{body(2)}.values, {4}), 'Only the iterations that ran are recorded.');

% Arithmetic inside @{} still expands; the values recorded are the loop indices, and the
% translator finds no template because they do not appear literally in the output.
out = modfile.expand_macros(sprintf('@#for i in [1,2]\nvar y_@{i+1};\n@#endfor\n'));
assert(contains(out, 'var y_2;') && contains(out, 'var y_3;'), 'Arithmetic in @{} should still expand.');

% The index keeps its last value after @#endfor, as in Dynare.
out = modfile.expand_macros(sprintf('@#for i in [1,2]\n@#endfor\nvar y_@{i};\n'));
assert(contains(out, 'var y_2;'), 'The loop index should stay bound after the loop.');

% --- @#echo and @#error ------------------------------------------------------------------
% Both take an expression, not a bare literal, and both are inert unless the branch they
% sit in is taken.
echoed = evalc('modfile.expand_macros(sprintf(''@#define N = 3\n@#echo "building with N = " + string(N)\nvar y;\n''))');
assert(contains(echoed, 'building with N = 3'), sprintf('@#echo should print its message, got: %s', echoed));

out = modfile.expand_macros(sprintf('@#define N = 3\n@#echo "noise"\nvar y;\n'));
assert(strcmp(strtrim(out), 'var y;'), '@#echo should contribute nothing to the expansion.');

thrown = '';
message = '';
try
    modfile.expand_macros(sprintf('@#define N = 3\n@#if N > 2\n@#error "N is too large: " + string(N)\n@#endif\n'));
catch ME
    thrown = ME.identifier;
    message = ME.message;
end
assert(strcmp(thrown, 'modfile:expand_macros:userError'), sprintf('Expected expand_macros:userError, got "%s".', thrown));
assert(contains(message, 'N is too large: 3'), 'The message should be the evaluated expression.');
assert(contains(message, 'line 3'), 'The message should name the line.');

% Neither fires from a branch that is not taken.
out = modfile.expand_macros(sprintf('@#define N = 1\n@#if N > 2\n@#error "boom"\n@#echo "noise"\n@#endif\nvar y;\n'));
assert(strcmp(strtrim(out), 'var y;'), 'An inactive branch should not run @#error or @#echo.');

% --- @#echomacrovars -------------------------------------------------------------------
% Accepted in both its forms, silently: the macro variables are locals of the generated
% script, so there is nothing to print and nothing to save.
shown = evalc('out = modfile.expand_macros(sprintf(''@#define A = 1\n@#define f(x) = 2*x\n@#echomacrovars\n@#echomacrovars A f\n@#echomacrovars(save)\n@#echomacrovars(save) A\nvar y;\n''));');
assert(isempty(shown), sprintf('@#echomacrovars should print nothing, got: %s', shown));
assert(strcmp(strtrim(out), 'var y;'), '@#echomacrovars should contribute nothing to the expansion.');

% --- Function macros -------------------------------------------------------------------
out = modfile.expand_macros(sprintf('@#define f(x) = 2*x\n@#define n = f(3)\nvar y_@{n};\n'));
assert(contains(out, 'var y_6;'), 'A function macro should be applied.');

% The body of a function sees its formals, then the globals at the time of the call, and
% never the formals of the function that called it. This is Dynare's own self-test.
out = modfile.expand_macros(sprintf('@#define a = 1\n@#define f(x) = x + a\n@#define a = 2\n@#define g(a) = f(1) + a\n@#define a = 3\n@#define h(a) = g(2) + a\nvar y_@{f(1)}_@{g(2)}_@{h(1)};\n'));
assert(contains(out, 'var y_4_6_7;'), sprintf('Function scoping should match Dynare, got: %s', out));

% --- A define inside a loop ------------------------------------------------------------
% The loop index is no local of the generated script, whose defines are emitted flat, one
% per iteration: such a define renders the value it took rather than mention the index.
[out, info] = modfile.expand_macros(sprintf('@#define w = [1]\n@#for elt in [2, 3]\n@#define w = w + [elt]\n@#endfor\nvar y_@{w[3]};\n'));
assert(contains(out, 'var y_3;'), 'The define should accumulate over the loop.');
assert(~any(contains(info.defines(:,2), 'elt')), sprintf('A define in a loop should not mention the index, got: %s', strjoin(info.defines(:,2), ' | ')));

% --- A redefined variable -------------------------------------------------------------
% The script hoists the defines above the control flow that reads them, so a later
% definition is emitted under a fresh name, and what is rendered afterwards refers to it.
[out, info] = modfile.expand_macros(sprintf('@#define a = 1\n@#if a != 1\n@#error "first"\n@#endif\n@#define a = a + 1\n@#if a != 2\n@#error "second"\n@#endif\nvar y_@{a};\n'));
assert(contains(out, 'var y_2;'), 'The redefinition should take effect.');
assert(isequal(info.defines(:,1)', {'a', 'a_2'}) && strcmp(info.defines{2,2}, '(a + 1)'), sprintf('Expected a and a_2 = (a + 1), got: %s', strjoin(strcat(info.defines(:,1)', {' = '}, info.defines(:,2)'), ', ')));
assert(strcmp(info.conditionals(2).conds{1}, '(a_2 ~= 2)'), sprintf('The later condition should read the alias, got: %s', info.conditionals(2).conds{1}));

% --- @#include -------------------------------------------------------------------------
fid = fopen('t01_included.inc', 'w');
fprintf(fid, 'varexo e_shared;\n');
fclose(fid);
cleanup = onCleanup(@() delete('t01_included.inc'));

out = modfile.expand_macros(sprintf('var y;\n@#include "t01_included.inc"\n'), fullfile(pwd, 't01_main.mod'));
assert(contains(out, 'varexo e_shared;'), 'The included file should be spliced in.');

% A file including itself is refused rather than looping.
fid = fopen('t01_selfref.mod', 'w');
fprintf(fid, '@#include "t01_selfref.mod"\n');
fclose(fid);
cleanup2 = onCleanup(@() delete('t01_selfref.mod'));

thrown = false;
try
    modfile.expand_macros(fileread('t01_selfref.mod'), fullfile(pwd, 't01_selfref.mod'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:expand_macros:circularInclude');
end
assert(thrown, 'Expected expand_macros:circularInclude.');

% A missing include names the directories that were searched.
thrown = false;
try
    modfile.expand_macros(sprintf('@#include "nowhere.inc"\n'), fullfile(pwd, 't01_main.mod'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:resolve_include:includeNotFound');
end
assert(thrown, 'Expected resolve_include:includeNotFound.');

% --- Errors ----------------------------------------------------------------------------
thrown = false;
try
    modfile.expand_macros(sprintf('@#if true\nyes\n'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:expand_macros:unterminatedDirective');
end
assert(thrown, 'Expected expand_macros:unterminatedDirective for an unclosed @#if.');

thrown = false;
try
    modfile.expand_macros(sprintf('@#for i in [1]\nx\n'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:expand_macros:unterminatedDirective');
end
assert(thrown, 'Expected expand_macros:unterminatedDirective for an unclosed @#for.');

thrown = false;
try
    modfile.expand_macros(sprintf('@#endif\n'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:expand_macros:unexpectedDirective');
end
assert(thrown, 'Expected expand_macros:unexpectedDirective.');

thrown = false;
try
    modfile.expand_macros(sprintf('@#nosuchthing 1\n'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:expand_macros:unsupportedDirective');
end
assert(thrown, 'Expected expand_macros:unsupportedDirective.');

fprintf('t01_directives.m: All tests passed\n');
