% Statements outside the imported subset: warn and skip, except the ones that would
% silently change the model.

addpath ../utils

header = @(fid) fprintf(fid, 'var y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\nmodel;\n[name = ''y'']\ny = alpha*e;\nend;\n');

% --- Computational statements are skipped, with a warning -----------------------------
source = 't09_skipped.mod';
fid = fopen(source, 'w');
header(fid);
fprintf(fid, 'shocks;\nvar e; stderr 0.01;\nend;\n');
fprintf(fid, 'varobs y;\n');
fprintf(fid, 'stoch_simul(order=1, irf=20) y;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

ws = warning('off', 'modfile:read:ignoredStatement');
restore = onCleanup(@() warning(ws));

mod = modfile.read(source);
assert(all(ismember({'shocks', 'varobs', 'stoch_simul'}, mod.skipped)), 'The computational statements should be reported as skipped.');

m = modBuilder(source);
assert(isequal(m.var(:,1), {'y'}), 'The model should still be built.');
assert(m.size('equations') == 1, 'The model should have one equation.');

% Strict turns those warnings into errors.
thrown = false;
try
    modfile.read(source, Strict=true);
catch ME
    thrown = strcmp(ME.identifier, 'modfile:read:ignoredStatement');
end
assert(thrown, 'Strict should promote the warning to an error.');

% --- Statements that change the model are refused -------------------------------------
refused = { 'predetermined_variables k;', 'varexo_det g;', 'external_function(name=myfun);', 'planner_objective y;' };

for i = 1:numel(refused)
    bad = sprintf('t09_bad%u.mod', i);
    fid = fopen(bad, 'w');
    header(fid);
    fprintf(fid, '%s\n', refused{i});
    fclose(fid);

    thrown = false;
    try
        modfile.read(bad);
    catch ME
        thrown = strcmp(ME.identifier, 'modfile:read:unsupportedStatement');
    end
    delete(bad);
    assert(thrown, sprintf('Expected read:unsupportedStatement for "%s".', refused{i}));
end

% A declaration option group rewrites the equations, so it is refused too.
bad = 't09_deflator.mod';
fid = fopen(bad, 'w');
fprintf(fid, 'var(log) y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\nmodel;\n[name = ''y'']\ny = alpha*e;\nend;\n');
fclose(fid);
thrown = false;
try
    modfile.read(bad);
catch ME
    thrown = strcmp(ME.identifier, 'modfile:read:unsupportedStatement');
end
delete(bad);
assert(thrown, 'Expected read:unsupportedStatement for var(log).');

% A file without a model block is not a model.
bad = 't09_nomodel.mod';
fid = fopen(bad, 'w');
fprintf(fid, 'var y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\n');
fclose(fid);
thrown = false;
try
    modfile.read(bad);
catch ME
    thrown = strcmp(ME.identifier, 'modfile:read:missingModel');
end
delete(bad);
assert(thrown, 'Expected read:missingModel.');

fprintf('t09_unsupported.m: All tests passed\n');
