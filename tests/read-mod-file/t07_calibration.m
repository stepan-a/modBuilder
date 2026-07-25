% Calibration is imported, including chains of expressions over earlier parameters.

addpath ../utils

source = 't07_calibration.mod';
fid = fopen(source, 'w');
fprintf(fid, 'var y k;\n');
fprintf(fid, 'varexo e;\n');
fprintf(fid, 'parameters r beta alpha delta unused;\n\n');
fprintf(fid, 'r = 0.01;\n');
fprintf(fid, 'beta = 1/(1+r);\n');
fprintf(fid, 'alpha = 0.3;\n');
fprintf(fid, 'alpha = 0.36;\n');
fprintf(fid, 'delta = 1 - beta*(1-0.5);\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*k + e;\n[name = ''k'']\nk = beta*k(-1) + delta*y;\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

[m, scriptpath] = modfile.load(source, Script='t07_generated.m');
cleanup2 = onCleanup(@() delete(scriptpath));

value = @(name) m.params{strcmp(m.params(:,1), name), 2};

assert(abs(value('r') - 0.01) < 1e-15, 'r not imported.');
assert(abs(value('beta') - 1/1.01) < 1e-15, 'A calibration expressed over an earlier parameter was not evaluated.');
assert(abs(value('delta') - (1 - (1/1.01)*0.5)) < 1e-15, 'A chained calibration was not evaluated.');

% A repeated assignment: the last one wins, as in Dynare.
assert(abs(value('alpha') - 0.36) < 1e-15, 'The last assignment should win.');

% A parameter that no equation references is still declared, uncalibrated.
assert(m.isparameter('unused'), 'A declared but unused parameter should reach the table.');
assert(isnan(value('unused')), 'An uncalibrated parameter should be NaN.');

% Declaration order is the order of the parameters statement, not of the assignments.
assert(isequal(m.params(:,1)', {'r', 'beta', 'alpha', 'delta', 'unused'}), 'Parameter declaration order not preserved.');

% The script keeps the source arithmetic rather than a pre-computed number, so the chain
% stays readable and can be re-tuned by editing one line.
text = fileread(scriptpath);
assert(~isempty(regexp(text, '^beta = 1/\(1\+r\);$', 'once', 'lineanchors')), 'The source expression should be kept in the script.');
assert(contains(text, 'm.parameter(''beta'', beta'), 'The parameter should take its value from the local.');
assert(contains(text, 'm.parameter(''unused'', NaN'), 'An uncalibrated parameter should be declared with NaN.');

fprintf('t07_calibration.m: All tests passed\n');
