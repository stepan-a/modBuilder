% Comprehensions, in the three forms Dynare's macro processor accepts.
%
% Following preprocessor/src/macro/Expressions.cc, a comprehension either maps an
% expression over an input set, filters that set, or both. The filtering form yields the
% elements themselves, which is the mapping form with the index as its output expression.

addpath ../utils

env = macro.environment(struct('Countries', {{'US', 'EA', 'JP'}}, 'Nums', {{1, 2, 3}}));

value = @(expr) macro.tostring(macro(expr).eval(env));

% --- The three forms --------------------------------------------------------------------
assert(strcmp(value('[i^2 for i in Nums]'), '[1, 4, 9]'), 'A comprehension maps its expression over the set.');
assert(strcmp(value('[c in Countries when c != "JP"]'), '[US, EA]'), 'A comprehension with no "for" filters the set.');
assert(strcmp(value('[i^2 for i in Nums when i > 1]'), '[4, 9]'), 'A comprehension can filter and map at once.');

% The filtering form is the mapping one with the index as its output expression.
assert(strcmp(value('[c for c in Countries when c != "JP"]'), value('[c in Countries when c != "JP"]')), 'The two spellings of a filter should agree.');

% --- The index --------------------------------------------------------------------------
assert(strcmp(value('["y_" + c for c in Countries]'), '[y_US, y_EA, y_JP]'), 'The index is bound in the output expression.');
assert(strcmp(value('[a + b for (a, b) in [(1,2), (3,4)]]'), '[3, 7]'), 'A tuple index destructures the elements.');
assert(strcmp(value('[(a, b) in [(1,2), (3,4)] when a > 1]'), '[(3, 4)]'), 'Filtering on a destructured tuple gives the tuples back.');
assert(strcmp(value('[i for i in 1:5 when mod(i, 2) == 1]'), '[1, 3, 5]'), 'The input set may be any array expression.');
assert(strcmp(value('[i for i in [j*2 for j in Nums]]'), '[2, 4, 6]'), 'A comprehension may run over another one.');
assert(strcmp(value('[[i, i] for i in Nums]'), '[[1, 1], [2, 2], [3, 3]]'), 'The output expression may itself be an array.');

% An empty result is still an array, and an unguarded set is copied.
assert(strcmp(macro('[c in Countries when false]').eval(env).kind, 'array'), 'A comprehension always gives an array.');
assert(strcmp(value('[c in Countries when true]'), '[US, EA, JP]'), 'A guard that always holds keeps everything.');

% The index does not outlive the comprehension, which is the one place this departs from
% Dynare: there the binding is made in the enclosing environment and stays there, so a
% file reading the index afterwards would see whatever the last iteration bound.
after = macro.environment(struct('Nums', {{1, 2, 3}}));
macro('[i for i in Nums]').eval(after);
assert(~isKey(after.vars, "i"), 'The index should not leak out of the comprehension.');

% An array literal is still read as one; the forms differ by what follows the first
% expression, and nothing else.
assert(strcmp(value('[1, 2, 3]'), '[1, 2, 3]'), 'A plain array literal.');
assert(strcmp(value('[]'), '[]'), 'An empty array literal.');
assert(strcmp(value('[1, 2, 3][2:3]'), '[2, 3]'), 'A literal that is indexed.');
assert(strcmp(value('["EA" in Countries, "CN" in Countries]'), '[true, false]'), 'An array of membership tests is not a comprehension.');

% --- MATLAB rendering -------------------------------------------------------------------
% Rendered rather than declined, so that the generated script keeps the relation between
% the two settings: editing the input set there still answers the comprehension.
Countries = macroarray('US', 'EA', 'JP'); Nums = macroarray(1, 2, 3); %#ok<NASGU>
render = @(expr) local_render(macro(expr), env);

assert(strcmp(render('[c for c in Countries when c != "JP"]'), 'filter(Countries, @(c) ~strcmp(c, ''JP''))'), 'A filter renders as filter().');
assert(strcmp(render('[i^2 for i in Nums]'), 'map(Nums, @(i) (i ^ 2))'), 'A map renders as map().');
assert(strcmp(render('[i^2 for i in Nums when i > 1]'), 'map(filter(Nums, @(i) (i > 1)), @(i) (i ^ 2))'), 'Filtering and mapping compose.');

% What is rendered must compute what the macro engine computes, which is checked by
% running it rather than by eye.
rendered = {'[c for c in Countries when c != "JP"]', '[i^2 for i in Nums]', ...
            '[i^2 for i in Nums when i > 1]', '["y_" + c for c in Countries]', ...
            '[c in Countries when c != "JP"]', '[i for i in Nums when i > 1]'};
for i = 1:numel(rendered)
    tree = macro(rendered{i});
    assert(strcmp(string(eval(local_render(tree, env))), macro.tostring(tree.eval(env))), ...
           sprintf('"%s" renders to MATLAB that computes something else.', rendered{i}));
end

% Declined, and then emitted as the evaluated literal by the caller: a destructured index
% would have to be rewritten into the components of the argument of the anonymous
% function, and an input set mixing kinds cannot say how its body renders.
[~, ok] = macro('[a + b for (a, b) in [(1,2), (3,4)]]').to_matlab(env);
assert(~ok, 'A destructured index has no faithful rendering.');
mixed = macro.environment(struct('Mixed', {{1, 'a'}}));
[~, ok] = macro('[x for x in Mixed]').to_matlab(mixed);
assert(~ok, 'An input set mixing kinds should be declined.');

% --- Errors -----------------------------------------------------------------------------
assert_id(@() macro('[c for 2 in Nums]'), 'macro:parse:badIndex');
assert_id(@() macro('[c for (a, 2) in Nums]'), 'macro:parse:badIndex');
assert_id(@() macro('[c + 1 when true]'), 'macro:parse:badComprehension');
assert_id(@() macro('[i for i in Nums'), 'macro:parse:missingToken');
assert_id(@() macro('[i for i in 3]').eval(env), 'macro:eval_comprehension:typeError');
assert_id(@() macro('[(a, b) for (a, b) in Nums]').eval(env), 'macro:eval_comprehension:typeError');

% --- Reading a .mod file that uses them --------------------------------------------------
source = 't13_comprehensions.mod';
fid = fopen(source, 'w');
fprintf(fid, '@#define Countries = ["US", "EA", "JP"]\n');
fprintf(fid, '@#define Core = [c for c in Countries when c != "JP"]\n\n');
fprintf(fid, 'var y_US y_EA y_JP z_US z_EA nx;\nvarexo e_US e_EA e_JP;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n@#for c in Countries\n[name = ''y_@{c}'']\ny_@{c} = alpha*e_@{c};\n@#endfor\n');
% The index set is itself a comprehension, so the 'when' of the loop and the 'when' of the
% set have to be told apart by where they stand.
fprintf(fid, '@#for c in [x for x in Countries when x != "JP"]\n[name = ''z_@{c}'']\nz_@{c} = y_@{c};\n@#endfor\n');
fprintf(fid, '[name = ''nx'']\nnx = y_@{Core[1]} - y_@{Core[2]};\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

[m, script] = modfile.load(source, Script='t13_gen.m');
cleanup2 = onCleanup(@() delete(script));
text = fileread(script);

equation = @(name) m.equations{strcmp(m.equations(:,1), name), 2};
assert(strcmp(equation('z_US'), 'z_US = y_US'), sprintf('Unexpected equation: %s', equation('z_US')));
assert(strcmp(equation('nx'), 'nx = y_US - y_EA'), sprintf('Unexpected equation: %s', equation('nx')));
assert(isequal(sort(m.equations(:,1)'), {'nx', 'y_EA', 'y_JP', 'y_US', 'z_EA', 'z_US'}), 'The guard should have left JP out of the second loop.');

% The comprehension reaches the script as one, not as the list it happened to give.
assert(contains(text, 'Core = filter(Countries, @(c) ~strcmp(c, ''JP''));'), sprintf('Expected the comprehension to be rendered, got:\n%s', text));
assert(modfile.build(script) == m, 'The script should rebuild the same model.');

fprintf('t13_comprehensions.m: All tests passed\n');

function str = local_render(tree, env)
    [str, ok] = tree.to_matlab(env);
    assert(ok, 'Expected the expression to render.');
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
