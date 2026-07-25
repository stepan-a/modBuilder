% Model-local variables (#name = expr;) are inlined into the equations that use them.
%
% The lagged case is the one where a wrong answer would be silent, so it is checked
% explicitly: #z = a*b; used as z(-1) must become a(-1)*b(-1), with the parameters left
% at the current period.

addpath ../utils

source = 't04_locals.mod';

fid = fopen(source, 'w');
fprintf(fid, 'var y c z w;\n');
fprintf(fid, 'varexo e;\n');
fprintf(fid, 'parameters alpha beta;\n\n');
fprintf(fid, 'alpha = 0.36;\n');
fprintf(fid, 'beta = 0.99;\n\n');
fprintf(fid, 'model;\n');
fprintf(fid, '#mc = alpha*c;\n');
fprintf(fid, '#total = mc + beta;\n');
fprintf(fid, '[name = ''y'']\n');
fprintf(fid, 'y = mc + e;\n');
fprintf(fid, '[name = ''c'']\n');
fprintf(fid, 'c = total;\n');
fprintf(fid, '[name = ''z'']\n');
fprintf(fid, 'z = mc(-1);\n');
fprintf(fid, '[name = ''w'']\n');
fprintf(fid, 'w = beta*z;\n');
fprintf(fid, 'end;\n');
fclose(fid);

cleanup = onCleanup(@() delete(source));

m = modBuilder(source);

% A local is not a symbol of the model.
assert(~m.issymbol('mc'), 'A model-local variable must not become a symbol.');
assert(~m.issymbol('total'), 'A model-local variable must not become a symbol.');

% Plain inlining.
assert(equation_equal(m.equations{1,2}, 'y = alpha*c + e'), sprintf('Unexpected equation for y: %s', m.equations{1,2}));

% A local defined in terms of another local is resolved first.
assert(equation_equal(m.equations{2,2}, 'c = alpha*c + beta'), sprintf('Unexpected equation for c: %s', m.equations{2,2}));

% The lagged use: the variable is shifted, the parameter is not.
assert(equation_equal(m.equations{3,2}, 'z = alpha*c(-1)'), sprintf('Unexpected equation for z: %s', m.equations{3,2}));

% An equation referencing no local is left byte for byte untouched.
assert(strcmp(m.equations{4,2}, 'w = beta*z'), sprintf('An equation without locals was rewritten: %s', m.equations{4,2}));

% A local colliding with a declared symbol is rejected.
bad = 't04_conflict.mod';
fid = fopen(bad, 'w');
fprintf(fid, 'var y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\nmodel;\n#alpha = 2*e;\n[name = ''y'']\ny = alpha;\nend;\n');
fclose(fid);
cleanup2 = onCleanup(@() delete(bad));

thrown = false;
try
    modBuilder(bad);
catch ME
    thrown = strcmp(ME.identifier, 'modfile:inline_model_local_variables:conflict');
end
assert(thrown, 'Expected inline_model_local_variables:conflict.');

% Mutually recursive definitions are rejected rather than looped over.
cyclic = 't04_cycle.mod';
fid = fopen(cyclic, 'w');
fprintf(fid, 'var y;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\nmodel;\n#p = q + 1;\n#q = p + 1;\n[name = ''y'']\ny = alpha*p + e;\nend;\n');
fclose(fid);
cleanup3 = onCleanup(@() delete(cyclic));

thrown = false;
try
    modBuilder(cyclic);
catch ME
    thrown = strcmp(ME.identifier, 'modfile:inline_model_local_variables:circularModelLocalVariable');
end
assert(thrown, 'Expected inline_model_local_variables:circularModelLocalVariable.');

fprintf('t04_model_local.m: All tests passed\n');
