% The generated script keeps the macro control flow: @#for becomes a loop and @#if an if.

addpath ../utils

% --- A uniform @#for becomes a modBuilder implicit loop --------------------------------
source = 't09_loop.mod';
fid = fopen(source, 'w');
fprintf(fid, '@#define Countries = ["US", "EA", "JP"]\n\n');
fprintf(fid, 'var\n@#for c in Countries\n  y_@{c}\n@#endfor\n;\n\n');
fprintf(fid, 'varexo\n@#for c in Countries\n  e_@{c}\n@#endfor\n;\n\n');
fprintf(fid, 'parameters alpha;\nalpha = 0.33;\n\n');
fprintf(fid, 'model;\n@#for c in Countries\n[name = ''y_@{c}'']\ny_@{c} = alpha + e_@{c};\n@#endfor\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

[m, script] = modfile.load(source, Script='t09_loop_gen.m');
cleanup2 = onCleanup(@() delete(script));
text = fileread(script);

assert(contains(text, 'm.add(''y_$1'', ''y_$1 = alpha + e_$1'', {''US'', ''EA'', ''JP''});'), sprintf('Expected one implicit-loop add, got:\n%s', text));
assert(contains(text, 'm.exogenous(''e_$1'', NaN, ''declared'', true, {''US'', ''EA'', ''JP''});'), 'Expected one implicit-loop exogenous declaration.');
assert(count(text, 'm.add(') == 1, 'The three equations should be one call.');

% Running the script rebuilds the same model, so the compact form is not a shortcut.
again = modfile.build(script);
assert(again == m, 'The looped script should rebuild the same model.');
assert(isequal(m.var(:,1)', {'y_US', 'y_EA', 'y_JP'}), 'Unexpected endogenous variables.');

% --- A conditional with a single branch becomes a MATLAB if ----------------------------
source2 = 't09_if.mod';
fid = fopen(source2, 'w');
fprintf(fid, '@#ifndef Open\n@#define Open = true\n@#endif\n\n');
fprintf(fid, 'var y c;\n@#if Open\nvar nx;\n@#endif\n\n');
fprintf(fid, 'varexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e;\n[name = ''c'']\nc = y;\n');
fprintf(fid, '@#if Open\n[name = ''nx'']\nnx = y - c;\n@#endif\nend;\n');
fclose(fid);
cleanup3 = onCleanup(@() delete(source2));

[m2, script2] = modfile.load(source2, Script='t09_if_gen.m');
cleanup4 = onCleanup(@() delete(script2));
text2 = fileread(script2);

assert(contains(text2, 'Open = true;'), 'The macro flag should be a MATLAB local.');
assert(~isempty(regexp(text2, '^if Open$', 'once', 'lineanchors')), sprintf('Expected a MATLAB if, got:\n%s', text2));
assert(contains(text2, '    m.add(''nx'', ''nx = y - c'');'), 'The conditional equation should sit inside the if.');
assert(~isempty(regexp(text2, '^end$', 'once', 'lineanchors')), 'The if should be closed.');

again2 = modfile.build(script2);
assert(again2 == m2, 'The conditional script should rebuild the same model.');

% Flipping the local in the script drops the conditional part, which is the whole point
% of emitting an if rather than the expanded equations.
flipped = strrep(fileread(script2), 'Open = true;', 'Open = false;');
fid = fopen('t09_flipped.m', 'w');
fprintf(fid, '%s', flipped);
fclose(fid);
cleanup5 = onCleanup(@() delete('t09_flipped.m'));

closed = modfile.build('t09_flipped.m');
assert(~ismember('nx', closed.var(:,1)), 'Setting the flag to false should drop the conditional equation.');
assert(closed.size('equations') == 2, 'The closed model should have two equations.');

% --- A conditional with an @#else emits BOTH branches ----------------------------------
% The branch that was not taken produces no text, so it is read again with the conditional
% forced onto it. Both branches then reach the script, and flipping the flag there gives
% the model the .mod file would have given with that setting.
source3 = 't09_else.mod';
fid = fopen(source3, 'w');
fprintf(fid, '@#define Sticky = true\n\nvar y p;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e;\n');
fprintf(fid, '@#if Sticky\n[name = ''p'']\np = alpha*y;\n@#else\n[name = ''p'']\np = y;\n@#endif\nend;\n');
fclose(fid);
cleanup6 = onCleanup(@() delete(source3));

[m3, script3] = modfile.load(source3, Script='t09_else_gen.m');
cleanup7 = onCleanup(@() delete(script3));
text3 = fileread(script3);

assert(~isempty(regexp(text3, '^if Sticky$', 'once', 'lineanchors')), sprintf('Expected a MATLAB if, got:\n%s', text3));
assert(~isempty(regexp(text3, '^else$', 'once', 'lineanchors')), 'Expected the else branch to be emitted.');
assert(contains(text3, 'm.add(''p'', ''p = alpha*y'');'), 'The taken branch should be emitted.');
assert(contains(text3, 'm.add(''p'', ''p = y'');'), 'The branch that was not taken should be emitted too.');
assert(strcmp(m3.equations{2,2}, 'p = alpha*y'), 'The model should use the taken branch.');
assert(modfile.build(script3) == m3, 'The script should rebuild the same model.');

% Flipping the flag in the script switches branch, exactly as editing the .mod would.
flipped3 = strrep(text3, 'Sticky = true;', 'Sticky = false;');
fid = fopen('t09_else_flipped.m', 'w');
fprintf(fid, '%s', flipped3);
fclose(fid);
cleanup7b = onCleanup(@() delete('t09_else_flipped.m'));
other = modfile.build('t09_else_flipped.m');
assert(strcmp(other.equations{strcmp(other.equations(:,1), 'p'), 2}, 'p = y'), 'Flipping the flag should switch to the other branch.');

% --- A loop modBuilder's implicit loops cannot express becomes a MATLAB for ------------
% A modBuilder implicit loop expands over the Cartesian product of its index sets. This
% loop runs over an explicit list of pairs that is not the full product, so it has to be
% emitted as a MATLAB for loop instead.
source4 = 't09_matlabfor.mod';
fid = fopen(source4, 'w');
fprintf(fid, '@#define Pairs = [(1, "a"), (2, "b")]\n\n');
fprintf(fid, 'var\n@#for (i, j) in Pairs\n  y_@{i}@{j}\n@#endfor\n;\n\n');
fprintf(fid, 'varexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n@#for (i, j) in Pairs\n[name = ''y_@{i}@{j}'']\ny_@{i}@{j} = alpha*e;\n@#endfor\nend;\n');
fclose(fid);
cleanup8 = onCleanup(@() delete(source4));

[m4, script4] = modfile.load(source4, Script='t09_for_gen.m');
cleanup9 = onCleanup(@() delete(script4));
text4 = fileread(script4);

assert(contains(text4, 'for it = 1:2'), sprintf('Expected a MATLAB for loop, got:\n%s', text4));
assert(contains(text4, 'i_values = {1, 2};'), 'The first index values should be listed before the loop.');
assert(contains(text4, 'j_values = {''a'', ''b''};'), 'The second index values should be listed before the loop.');
assert(contains(text4, 'sprintf('), 'The loop should build the names with sprintf.');

again4 = modfile.build(script4);
assert(again4 == m4, 'The MATLAB for loop should rebuild the same model.');
assert(isequal(m4.var(:,1)', {'y_1a', 'y_2b'}), sprintf('Unexpected endogenous variables: %s', strjoin(m4.var(:,1)', ' ')));

% --- A loop body with several equations keeps its order --------------------------------
% A modBuilder implicit loop runs one call over every index, which would group the output
% by call instead of by iteration and so change the order the variables are declared in.
% Such a body has to go through a MATLAB for loop.
source5 = 't09_order.mod';
fid = fopen(source5, 'w');
fprintf(fid, '@#define C = ["US", "EA"]\n\nvar\n@#for c in C\n  y_@{c} k_@{c}\n@#endfor\n;\n\n');
fprintf(fid, 'varexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n@#for c in C\n[name = ''y_@{c}'']\ny_@{c} = alpha*e;\n[name = ''k_@{c}'']\nk_@{c} = y_@{c};\n@#endfor\nend;\n');
fclose(fid);
cleanup10 = onCleanup(@() delete(source5));

[m5, script5] = modfile.load(source5, Script='t09_order_gen.m');
cleanup11 = onCleanup(@() delete(script5));

assert(isequal(m5.var(:,1)', {'y_US', 'k_US', 'y_EA', 'k_EA'}), sprintf('The loop should keep its order, got: %s', strjoin(m5.var(:,1)', ' ')));
assert(contains(fileread(script5), 'for it = 1:2'), 'A multi-equation body should become a MATLAB for loop.');
assert(modfile.build(script5) == m5, 'The generated loop should rebuild the same model.');

% --- Nested @#for fold into one multi-index loop ---------------------------------------
source6 = 't09_nested.mod';
fid = fopen(source6, 'w');
fprintf(fid, '@#define C = ["US", "EA"]\n@#define S = [1, 2]\n\n');
fprintf(fid, 'var\n@#for c in C\n@#for s in S\n  y_@{c}_@{s}\n@#endfor\n@#endfor\n;\n\n');
fprintf(fid, 'varexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n@#for c in C\n@#for s in S\n[name = ''y_@{c}_@{s}'']\ny_@{c}_@{s} = alpha*e;\n@#endfor\n@#endfor\nend;\n');
fclose(fid);
cleanup12 = onCleanup(@() delete(source6));

[m6, script6] = modfile.load(source6, Script='t09_nested_gen.m');
cleanup13 = onCleanup(@() delete(script6));
text6 = fileread(script6);

assert(contains(text6, 'm.add(''y_$1_$2'', ''y_$1_$2 = alpha*e'', {''US'', ''EA''}, {1, 2});'), sprintf('Nested loops should fold into one two-index loop, got:\n%s', text6));
assert(isequal(m6.var(:,1)', {'y_US_1', 'y_US_2', 'y_EA_1', 'y_EA_2'}), 'Nested loops should keep their expansion order.');
assert(modfile.build(script6) == m6, 'The folded loop should rebuild the same model.');

% The placeholder written for one index must not be eaten by another: here the second
% index is the number 1, which occurs inside the "$1" the first index just produced.
assert(~contains(text6, '$$'), 'A placeholder should not be substituted into.');

% --- A conditional whose condition is FALSE still reaches the script --------------------
% Nothing of it is expanded, so a single pass sees nothing at all. Reading again with the
% conditional forced on recovers it, and the script can then be switched back on.
%
% Both @#if here carry the same condition and are forced together: a flag usually guards a
% declaration and the equation that goes with it, and flipping one alone would leave a
% model with an equation for an undeclared variable.
source7 = 't09_inactive.mod';
fid = fopen(source7, 'w');
fprintf(fid, '@#define Open = false\n\nvar y\n@#if Open\n  nx\n@#endif\n;\n');
fprintf(fid, 'varexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e;\n@#if Open\n[name = ''nx'']\nnx = y;\n@#endif\nend;\n');
fclose(fid);
cleanup14 = onCleanup(@() delete(source7));

[m7, script7] = modfile.load(source7, Script='t09_inactive_gen.m');
cleanup15 = onCleanup(@() delete(script7));
text7 = fileread(script7);

assert(~ismember('nx', m7.var(:,1)), 'The inactive branch should not be in the model.');
assert(~isempty(regexp(text7, '^if Open$', 'once', 'lineanchors')), sprintf('The conditional should still reach the script, got:\n%s', text7));
assert(contains(text7, 'm.add(''nx'', ''nx = y'');'), 'The branch should be emitted even though it was not taken.');
assert(modfile.build(script7) == m7, 'The script should rebuild the same model.');

% Switching the flag on in the script brings the branch in.
flipped7 = strrep(text7, 'Open = false;', 'Open = true;');
fid = fopen('t09_inactive_flipped.m', 'w');
fprintf(fid, '%s', flipped7);
fclose(fid);
cleanup16 = onCleanup(@() delete('t09_inactive_flipped.m'));
opened = modfile.build('t09_inactive_flipped.m');
assert(ismember('nx', opened.var(:,1)), 'Switching the flag on should bring the branch in.');
assert(opened.size('equations') == 2, 'The open model should have two equations.');

% --- A condition using a kind predicate ------------------------------------------------
source9 = 't09_predicate.mod';
fid = fopen(source9, 'w');
fprintf(fid, '@#define Regimes = ["a", "b"]\n\nvar y nx;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e;\n@#if isarray(Regimes)\n[name = ''nx'']\nnx = y;\n@#endif\nend;\n');
fclose(fid);
cleanup17 = onCleanup(@() delete(source9));

[m9, script9] = modfile.load(source9, Script='t09_predicate_gen.m');
cleanup18 = onCleanup(@() delete(script9));
text9 = fileread(script9);

assert(~isempty(regexp(text9, '^if isa\(Regimes, ''macroarray''\)$', 'once', 'lineanchors')), sprintf('The predicate should render as a MATLAB if, got:\n%s', text9));
assert(ismember('nx', m9.var(:,1)), 'The branch should be in the model.');
assert(modfile.build(script9) == m9, 'The script should rebuild the same model.');

% --- Nested conditionals -----------------------------------------------------------
% A @#if inside a branch of another becomes a nested MATLAB if, whichever branch the
% outer one took: the inner conditional of a branch that was not taken is recovered by
% reading that branch, and then its own branches by reading it again.
for outer = {'true', 'false'}
    source8 = 't09_nestedif.mod';
    fid = fopen(source8, 'w');
    fprintf(fid, '@#define Open = %s\n@#define Sticky = true\n\n', outer{1});
    fprintf(fid, 'var y p;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\n\n');
    fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*e;\n');
    fprintf(fid, '@#if Open\n@#if Sticky\n[name = ''p'']\np = alpha*y;\n@#else\n[name = ''p'']\np = y;\n@#endif\n');
    fprintf(fid, '@#else\n[name = ''p'']\np = 0;\n@#endif\nend;\n');
    fclose(fid);

    [m8, script8] = modfile.load(source8, Script='t09_nestedif_gen.m');
    text8 = fileread(script8);

    assert(~isempty(regexp(text8, '^if Open$', 'once', 'lineanchors')), sprintf('Outer if missing (Open = %s):\n%s', outer{1}, text8));
    assert(~isempty(regexp(text8, '^    if Sticky$', 'once', 'lineanchors')), sprintf('Inner if missing (Open = %s):\n%s', outer{1}, text8));
    assert(contains(text8, 'm.add(''p'', ''p = alpha*y'');'), 'The inner taken branch should be emitted.');
    assert(contains(text8, 'm.add(''p'', ''p = y'');'), 'The inner other branch should be emitted.');
    assert(contains(text8, 'm.add(''p'', ''p = 0'');'), 'The outer else branch should be emitted.');
    assert(modfile.build(script8) == m8, 'The nested script should rebuild the same model.');

    % Only one equation for p reaches the model, whichever path is taken.
    assert(m8.size('equations') == 2, 'The model should have two equations.');

    % Each of the three settings gives the equation the .mod file would have given.
    expected = {'true', 'true', 'p = alpha*y'; 'true', 'false', 'p = y'; 'false', 'true', 'p = 0'};
    for k = 1:size(expected, 1)
        flipped8 = regexprep(text8, '^Open = \w+;$', sprintf('Open = %s;', expected{k,1}), 'lineanchors');
        flipped8 = regexprep(flipped8, '^Sticky = \w+;$', sprintf('Sticky = %s;', expected{k,2}), 'lineanchors');
        fid = fopen('t09_nestedif_flipped.m', 'w');
        fprintf(fid, '%s', flipped8);
        fclose(fid);
        built = modfile.build('t09_nestedif_flipped.m');
        got = built.equations{strcmp(built.equations(:,1), 'p'), 2};
        assert(strcmp(got, expected{k,3}), sprintf('Open=%s Sticky=%s should give "%s", got "%s".', expected{k,1}, expected{k,2}, expected{k,3}, got));
    end

    delete(source8);
    delete(script8);
    delete('t09_nestedif_flipped.m');
end

fprintf('t09_emission.m: All tests passed\n');
