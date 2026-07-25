% The initval block is imported as the initial guess for the steady state.

addpath ../utils

source = 't06_initval.mod';
fid = fopen(source, 'w');
fprintf(fid, 'var y k;\n');
fprintf(fid, 'varexo e;\n');
fprintf(fid, 'parameters alpha beta;\n\n');
fprintf(fid, 'alpha = 0.36;\n');
fprintf(fid, 'beta = 0.99;\n\n');
fprintf(fid, 'model;\n[name = ''y'']\ny = alpha*k + e;\n[name = ''k'']\nk = beta*k(-1) + y;\nend;\n\n');
fprintf(fid, 'initval;\ny = 1.5;\nk = 1/(1-beta);\ne = 0;\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

m = modBuilder(source);

value = @(tbl, name) tbl{strcmp(tbl(:,1), name), 2};

assert(abs(value(m.var, 'y') - 1.5) < 1e-15, 'The initial value of y was not imported.');
assert(abs(value(m.var, 'k') - 1/(1-0.99)) < 1e-12, 'An initial value expressed over a parameter was not evaluated.');
assert(abs(value(m.varexo, 'e') - 0) < 1e-15, 'The value of the exogenous variable was not imported.');

% write(initval=true) puts them back.
m.write('t06_roundtrip', initval=true);
cleanup2 = onCleanup(@() delete('t06_roundtrip.mod'));
text = fileread('t06_roundtrip.mod');
assert(contains(text, 'initval;'), 'An initval block should be written back.');
assert(~isempty(regexp(text, 'y = 1\.500000;', 'once')), 'The initial value of y should be written back.');

% Reading that file again gives the same values.
again = modBuilder('t06_roundtrip.mod');
assert(abs(value(again.var, 'y') - 1.5) < 1e-15, 'The round-trip lost the initial value.');

% An initval entry for an unknown symbol is reported.
bad = 't06_bad.mod';
fid = fopen(bad, 'w');
fprintf(fid, 'var y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\nmodel;\n[name = ''y'']\ny = alpha*e;\nend;\ninitval;\nnosuchvar = 1;\nend;\n');
fclose(fid);
cleanup3 = onCleanup(@() delete(bad));

thrown = false;
try
    modBuilder(bad);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:declare_symbol:notEndogenous');
end
assert(thrown, sprintf('Expected an error for an unknown initval target, got none or another id.'));

fprintf('t06_initval.m: All tests passed\n');
