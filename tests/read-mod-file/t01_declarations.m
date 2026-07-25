% Declarations: optional commas, TeX names, long names, empty lists, and order.

addpath ../utils

% Commas are optional and may appear anywhere, per Dynare's grammar.
rows = modfile.parse_declaration('a, b , c,', 'var');
assert(isequal(rows(:,1)', {'a', 'b', 'c'}), 'Optional commas not handled.');
assert(all(cellfun(@isempty, rows(:,2))) && all(cellfun(@isempty, rows(:,3))), 'No attributes were given.');

rows = modfile.parse_declaration('a b c', 'var');
assert(isequal(rows(:,1)', {'a', 'b', 'c'}), 'Blank-separated list not handled.');

% An empty list is legal: write() emits 'varexo ;' for a model with no exogenous
% variable, and such files are committed as fixtures.
assert(isempty(modfile.parse_declaration('', 'varexo')), 'An empty declaration should yield no rows.');
assert(isempty(modfile.parse_declaration('   ', 'varexo')), 'A blank declaration should yield no rows.');

% TeX name, long name, and both, in either arrangement.
rows = modfile.parse_declaration('alpha $\alpha$ (long_name=''Capital share'') beta $\beta$ gamma (long_name=''Growth'')', 'parameters');
assert(isequal(rows(:,1)', {'alpha', 'beta', 'gamma'}), 'Names not read.');
assert(strcmp(rows{1,2}, '\alpha') && strcmp(rows{1,3}, 'Capital share'), 'alpha attributes not read.');
assert(strcmp(rows{2,2}, '\beta') && isempty(rows{2,3}), 'beta attributes not read.');
assert(isempty(rows{3,2}) && strcmp(rows{3,3}, 'Growth'), 'gamma attributes not read.');

% A partition key modBuilder has no slot for is dropped, not an error.
ws = warning('off', 'modfile:parse_declaration:ignoredPartition');
restore = onCleanup(@() warning(ws));
rows = modfile.parse_declaration('y (long_name=''Output'', sector=''manufacturing'')', 'var');
assert(strcmp(rows{1,3}, 'Output'), 'long_name should survive an extra partition key.');

% Declaration order is preserved through the whole reader, independently of the order in
% which equations and assignments appear.
source = 't01_declarations.mod';
fid = fopen(source, 'w');
fprintf(fid, 'var y $Y$ (long_name=''Output'') k;\n');
fprintf(fid, 'varexo e u;\n');
fprintf(fid, 'parameters delta, alpha $\\alpha$, beta;\n\n');
fprintf(fid, 'beta = 0.99;\nalpha = 0.36;\ndelta = 0.025;\n\n');
fprintf(fid, 'model;\n[name = ''k'']\nk = (1-delta)*k(-1) + e;\n[name = ''y'']\ny = alpha*k + beta*u;\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

m = modBuilder(source);

assert(isequal(m.var(:,1)', {'y', 'k'}), 'Endogenous declaration order not preserved.');
assert(isequal(m.varexo(:,1)', {'e', 'u'}), 'Exogenous declaration order not preserved.');
assert(isequal(m.params(:,1)', {'delta', 'alpha', 'beta'}), 'Parameter declaration order not preserved.');

% The equations keep their own order, which differs from the var statement here.
assert(isequal(m.equations(:,1)', {'k', 'y'}), 'Equation order not preserved.');

assert(strcmp(m.var{1,3}, 'Output') && strcmp(m.var{1,4}, 'Y'), 'Endogenous attributes not imported.');
assert(strcmp(m.params{2,4}, '\alpha'), 'Parameter TeX name not imported.');

% Writing it back reproduces both orders.
m.write('t01_out');
cleanup2 = onCleanup(@() delete('t01_out.mod'));
text = fileread('t01_out.mod');
assert(contains(text, 'parameters delta'), 'Parameter order not written back.');

fprintf('t01_declarations.m: All tests passed\n');
