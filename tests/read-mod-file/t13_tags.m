% Equation tags whose values hold a comma or a bracket.

addpath ../utils

% The group is closed by the first ']' outside quotes and cut at the commas outside them.
eqs = modfile.parse_model_block(sprintf('[name=''FOC wages, eq. (2)'', bind=''IRR,INEG'']\ny = x;\n[name=''x [1]'', mcp = ''x > 0'']\nx = 1;\n'));
assert(strcmp(eqs(1).tags.name, 'FOC wages, eq. (2)') && strcmp(eqs(1).tags.bind, 'IRR,INEG'), sprintf('Unexpected tags: %s / %s', eqs(1).tags.name, eqs(1).tags.bind));
assert(strcmp(eqs(2).tags.name, 'x [1]') && strcmp(eqs(2).tags.mcp, 'x > 0'), 'A bracket inside a value should not close the group.');
assert(strcmp(eqs(1).lhs, 'y') && strcmp(eqs(2).rhs, '1'), 'The equations should follow their tags untouched.');

% End to end, the tag still names the equation.
source = 't13_tags.mod';
fid = fopen(source, 'w');
fprintf(fid, 'var y x; varexo e;\nmodel;\n[name=''y, the output'']\ny = x + e;\n[name=''x'', comment=''see [1]'']\nx = 0.5*x(-1);\nend;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));
m = modBuilder(source);
assert(isequal(m.equations(:,1)', {'y', 'x'}), sprintf('Unexpected keys: %s', strjoin(m.equations(:,1)', ' ')));

thrown = '';
try
    modfile.parse_model_block(sprintf('[name=''open\ny = x;\n'));
catch ME
    thrown = ME.identifier;
end
assert(strcmp(thrown, 'modfile:parse_model_block:unterminatedTag'), sprintf('Expected unterminatedTag, got "%s".', thrown));

% An occbin model writes one equation per regime under the same name. The equations of
% the binding regimes, tagged bind=, are dropped with a warning; the reference regime is
% the model.
source2 = 't13_occbin.mod';
fid = fopen(source2, 'w');
fprintf(fid, 'var c i lambdak; varexo e; parameters PHI;\nPHI = 1;\nmodel;\nc = e;\ni = c;\n[name=''investment'',bind=''IRR'']\ni - log(PHI) = 0;\n[name=''investment'',relax=''IRR'']\nlambdak = 0;\n[name=''investment'',bind=''IRR'',relax=''INEG'']\ni - log(PHI) = 0;\nend;\n');
fclose(fid);
cleanup2 = onCleanup(@() delete(source2));
[warned, m2] = evalc('modBuilder(source2)');
assert(m2.size('equations') == 3 && any(strcmp(m2.equations(:,1), 'lambdak')), sprintf('The reference regime should be kept, got: %s', strjoin(m2.equations(:,1)', ' ')));
assert(contains(regexprep(warned, '\s+', ' '), '2 equation(s) tagged bind='), sprintf('The binding regimes should be reported, got: %s', warned));

fprintf('t13_tags.m: All tests passed\n');
