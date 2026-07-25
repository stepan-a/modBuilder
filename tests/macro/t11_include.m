% @#include, and the directives an included file brings with it.
%
% An included file starts again at line 1, so a construct in it can sit at the same line
% as one in the includer. Keying constructs by line alone merges the two: they come out
% as a single conditional, and forcing a branch of one forces the other.
% modfile.construct_id keys them by file and line together.

addpath ../utils

% --- The included file contributes its statements ---------------------------------------
fid = fopen('t11_part.inc', 'w');
fprintf(fid, 'varexo e_extra;\n@#if Extra\nvar nx;\n@#endif\n');
fclose(fid);
cleanup = onCleanup(@() delete('t11_part.inc'));

% Both @#if sit on line 2 of their own file, which is the collision this pins.
source = 't11_main.mod';
fid = fopen(source, 'w');
fprintf(fid, '@#define Extra = true\n@#if Extra\nvar z;\n@#endif\n');
fprintf(fid, 'var y;\n@#include "t11_part.inc"\n');
fprintf(fid, 'varexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e;\n');
fprintf(fid, '@#if Extra\n[name = ''nx'']\nnx = y;\n[name = ''z'']\nz = y;\n@#endif\nend;\n');
fclose(fid);
cleanup2 = onCleanup(@() delete(source));

mod = modfile.read(source);

% Three conditionals were reached, two of them written on line 2 of their own file.
assert(numel(mod.macro.conditionals) == 3, 'Three conditionals should be recorded.');
assert(sum([mod.macro.conditionals.line] == 2) == 2, 'Two of them are on line 2, in different files.');
assert(numel(unique([mod.macro.conditionals.id])) == 3, 'Their keys must still be distinct.');

% --- The model is built from both files -------------------------------------------------
[m, script] = modfile.load(source, Script='t11_gen.m');
cleanup3 = onCleanup(@() delete(script));

assert(isequal(sort(m.var(:,1)'), {'nx', 'y', 'z'}), sprintf('Unexpected endogenous variables: %s', strjoin(m.var(:,1)', ' ')));
assert(ismember('e_extra', m.varexo(:,1)), 'The included exogenous variable should be declared.');
assert(m.size('equations') == 3, 'Three equations.');
assert(modfile.build(script) == m, 'The script should rebuild the same model.');

% The var statement is itself conditional here, so its order cannot be restored: a
% reorder() call takes the whole list and would fail as soon as the flag changed. The
% variables follow the equations instead, which differs in the var statement only.
assert(~contains(fileread(script), 'reorder'), 'reorder must not be emitted when the var list is conditional.');
assert(isequal(m.var(:,1)', m.equations(:,1)'), 'The order then follows the equations.');

% --- Turning the flag off drops what every one of them guards ---------------------------
flipped = strrep(fileread(script), 'Extra = true;', 'Extra = false;');
fid = fopen('t11_flipped.m', 'w');
fprintf(fid, '%s', flipped);
fclose(fid);
cleanup4 = onCleanup(@() delete('t11_flipped.m'));

closed = modfile.build('t11_flipped.m');
assert(isequal(closed.var(:,1)', {'y'}), sprintf('Only y should remain, got: %s', strjoin(closed.var(:,1)', ' ')));
assert(ismember('e_extra', closed.varexo(:,1)), 'The included declaration outside the conditional stays.');

% --- Two constructs on the same line of different files stay apart ----------------------
% A loop in the included file and a loop at the same line of the includer must not be
% folded together either.
fid = fopen('t11_loop.inc', 'w');
fprintf(fid, '@#for s in [1, 2]\n  b_@{s}\n@#endfor\n');
fclose(fid);
cleanup5 = onCleanup(@() delete('t11_loop.inc'));

loops = 't11_loops.mod';
fid = fopen(loops, 'w');
fprintf(fid, 'varexo\n@#for s in [1, 2]\n  a_@{s}\n@#endfor\n@#include "t11_loop.inc"\n;\n');
fprintf(fid, 'var y;\nparameters alpha;\nalpha = 0.5;\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*a_1 + b_1;\nend;\n');
fclose(fid);
cleanup6 = onCleanup(@() delete(loops));

ml = modfile.load(loops);
assert(isequal(ml.varexo(:,1)', {'a_1', 'a_2', 'b_1', 'b_2'}), sprintf('Unexpected exogenous variables: %s', strjoin(ml.varexo(:,1)', ' ')));

% --- @#includepath, and the failures --------------------------------------------------
mkdir('t11_dir');
fid = fopen(fullfile('t11_dir', 't11_far.inc'), 'w');
fprintf(fid, 'varexo e_far;\n');
fclose(fid);
cleanup7 = onCleanup(@() rmdir('t11_dir', 's'));

out = modfile.expand_macros(sprintf('@#includepath "t11_dir"\n@#include "t11_far.inc"\n'), fullfile(pwd, 'here.mod'));
assert(contains(out, 'varexo e_far;'), '@#includepath should extend the search.');

thrown = false;
try
    modfile.expand_macros(sprintf('@#include "nowhere.inc"\n'), fullfile(pwd, 'here.mod'));
catch ME
    thrown = strcmp(ME.identifier, 'modfile:resolve_include:includeNotFound');
end
assert(thrown, 'Expected resolve_include:includeNotFound.');

fprintf('t11_include.m: All tests passed\n');
