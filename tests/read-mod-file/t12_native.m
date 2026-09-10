% Native MATLAB statements: skipped whole, as Dynare passes them through.

addpath ../utils

source = 't12_native.mod';
fid = fopen(source, 'w');
fprintf(fid, 'var y c; varexo e;\nparameters alpha beta;\nalpha = 0.3;\n');
fprintf(fid, 'beta = 0.99; %% a calibration, since beta is declared\n');
fprintf(fid, 'results = struct();  %% not declared: native\n');
fprintf(fid, 'if alpha > 0.2\n    disp(''large share'')\nend\n');
fprintf(fid, 'x = y'';\n');
fprintf(fid, '[q, r] = deal(1, ...\n             2);\n');
fprintf(fid, 'model;\n[name=''y'']\ny = alpha*y(-1) + e;\n[name=''c'']\nc = beta*y;\nend;\n');
fprintf(fid, 'stoch_simul(order=1) y;\n');
fprintf(fid, 'if max(abs(oo_.dr.ghx)) > 1\n    error(''explosive'')\nend\n\n');
fprintf(fid, 'shocks;\nvar e; stderr 0.01;\nend;\n');
fprintf(fid, 'end\n');
fclose(fid);
cleanup1 = onCleanup(@() delete(source));

% The splitter tells the native lines apart from the Dynare statements.
stmts = modfile.split_statements(modfile.strip_comments(fileread(source)), source);
kinds = {stmts.kind};
keywords = {stmts.keyword};
native = keywords(strcmp(kinds, 'native'));
assert(isequal(native, {'results', 'if', 'disp', 'end', 'x', '', 'if', 'error', 'end', 'end'}), sprintf('Unexpected native lines: %s', strjoin(native, ' ')));
assert(isequal(keywords(strcmp(kinds, 'block')), {'model', 'shocks'}), 'The blocks should be found, the shocks block after native lines included.');
assert(sum(strcmp(keywords, 'beta')) == 1, 'An assignment to a declared symbol is a Dynare statement.');
continued = stmts(strcmp(keywords, '') & strcmp(kinds, 'native'));
assert(contains(continued.rest, '2);'), 'A line ending with ... continues on the next one.');

% The reader skips them with a warning each, and builds the model.
[warned, m] = evalc('modBuilder(source)');
assert(isequal(m.var(:,1)', {'y', 'c'}) && m.alpha == 0.3 && m.beta == 0.99, 'The model should be built from the Dynare statements alone.');
assert(contains(warned, 'MATLAB statement "results = struct();"'), sprintf('The native lines should be reported, got: %s', warned));

% Strict turns the report into an error.
thrown = '';
try
    modfile.read(source, Strict=true);
catch ME
    thrown = ME.identifier;
end
assert(strcmp(thrown, 'modfile:read:nativeStatement'), sprintf('Expected read:nativeStatement under Strict, got "%s".', thrown));

% Inside a block nothing is native: a shocks block's own var statements are its own.
stmts = modfile.split_statements(sprintf('var y; varexo e;\nshocks;\nvar e; stderr 0.01;\nend;\n'));
assert(numel(stmts) == 3 && strcmp(stmts(3).kind, 'block'), 'A block body is left to its own scanner.');

% A Dynare statement without its ';' is still reported.
thrown = '';
try
    modfile.split_statements(sprintf('var y; varexo e\n'));
catch ME
    thrown = ME.identifier;
end
assert(strcmp(thrown, 'modfile:split_statements:trailingText'), sprintf('Expected split_statements:trailingText, got "%s".', thrown));

fprintf('t12_native.m: All tests passed\n');
