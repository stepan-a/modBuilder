% A conditional that cuts a statement instead of wrapping it.
%
% The macro layer sits under the statement grammar, so a directive can slice a statement
% in half rather than enclose it. There is then no call to put inside an if: one m.add
% carries the whole equation. The control flow goes one level down instead, into the
% argument, which is assembled before it is passed.

addpath ../utils

source = 't12_cut.mod';
fid = fopen(source, 'w');
fprintf(fid, '@#define Open = true\n\nvar y nx;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*\n@#if Open\ne + 1\n@#else\ne\n@#endif\n;\n');
fprintf(fid, '[name = ''nx'']\nnx = y;\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

[m, script] = modfile.load(source, Script='t12_gen.m');
cleanup2 = onCleanup(@() delete(script));
text = fileread(script);

% The equation is assembled, not passed as a frozen literal.
assert(~isempty(regexp(text, '^eq_y = ''y = alpha\* e'';$', 'once', 'lineanchors')), sprintf('Expected the shared part to be assigned once, got:\n%s', text));
assert(contains(text, 'eq_y = [eq_y '' + 1''];'), 'The branch that was taken should append its part.');
assert(contains(text, 'm.add(''y'', eq_y);'), 'The assembled array should be passed to add.');
assert(~contains(text, 'm.add(''y'', ''y ='), 'The equation must not be emitted as a literal.');

% What the branches share is written once, so only the difference sits inside the if.
assert(count(text, 'y = alpha') == 1, 'The common part should appear once.');

assert(strcmp(m.equations{1,2}, 'y = alpha* e + 1'), sprintf('Unexpected equation: %s', m.equations{1,2}));
assert(modfile.build(script) == m, 'The script should rebuild the same model.');

% Flipping the flag rebuilds the equation the .mod file would have given, which is the
% whole point: before this the equation was frozen at its read-time text.
flipped = strrep(text, 'Open = true;', 'Open = false;');
fid = fopen('t12_flipped.m', 'w');
fprintf(fid, '%s', flipped);
fclose(fid);
cleanup3 = onCleanup(@() delete('t12_flipped.m'));

other = modfile.build('t12_flipped.m');
assert(strcmp(other.equations{1,2}, 'y = alpha* e'), sprintf('Flipping should give the other branch, got: %s', other.equations{1,2}));

% A conditional that wraps a whole statement still becomes a plain if around the call, so
% the assembled form is used only where it is needed.
assert(~isempty(regexp(text, '^if Open$', 'once', 'lineanchors')), 'The wrapping conditional keeps its if.');

% --- A cut equation with three branches --------------------------------------------------
source2 = 't12_three.mod';
fid = fopen(source2, 'w');
fprintf(fid, '@#define Regime = 2\n\nvar y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e\n');
fprintf(fid, '@#if Regime == 1\n+ 1\n@#elseif Regime == 2\n+ 2\n@#else\n+ 3\n@#endif\n;\nend;\n');
fclose(fid);
cleanup4 = onCleanup(@() delete(source2));

[m2, script2] = modfile.load(source2, Script='t12_three_gen.m');
cleanup5 = onCleanup(@() delete(script2));
text2 = fileread(script2);

assert(contains(text2, 'elseif (Regime == 2)'), sprintf('The elseif should be assembled too, got:\n%s', text2));
assert(strcmp(m2.equations{1,2}, 'y = alpha*e + 2'), sprintf('Unexpected equation: %s', m2.equations{1,2}));

expected = {'y = alpha*e + 1', 'y = alpha*e + 2', 'y = alpha*e + 3'};
for k = 1:3
    flipped2 = regexprep(text2, '^Regime = \d+;$', sprintf('Regime = %u;', k), 'lineanchors');
    fid = fopen('t12_three_flipped.m', 'w');
    fprintf(fid, '%s', flipped2);
    fclose(fid);
    built = modfile.build('t12_three_flipped.m');
    assert(strcmp(built.equations{1,2}, expected{k}), sprintf('Regime %u should give "%s", got "%s".', k, expected{k}, built.equations{1,2}));
end
delete('t12_three_flipped.m');

fprintf('t12_cut.m: All tests passed\n');
