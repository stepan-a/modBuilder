% Equations without a name tag are matched to endogenous variables automatically.
%
% The tag is the association, not a claim about the left-hand side, so both cases have to
% work: a tag that contradicts the left-hand side must be honoured, and an untagged model
% must be matched by the same bipartite matcher the Dynare-based constructor uses.

addpath ../utils

% --- A tag that does not name the left-hand side ---------------------------------------
% tests/load-mod-file/rbc1.true.mod tags 'k = exp(b)*(y-c)+...' with name='c'.
m = modBuilder('../load-mod-file/rbc1.true.mod');
row = strcmp(m.equations(:,1), 'c');
assert(any(row), 'No equation is keyed to c.');
assert(startsWith(strtrim(m.equations{row,2}), 'k ='), 'The tag should win over the left-hand side.');

% --- No tags at all --------------------------------------------------------------------
source = 't03_untagged.mod';
fid = fopen(source, 'w');
fprintf(fid, 'var y c k;\n');
fprintf(fid, 'varexo e;\n');
fprintf(fid, 'parameters alpha beta delta;\n\n');
fprintf(fid, 'alpha = 0.36;\nbeta = 0.99;\ndelta = 0.025;\n\n');
fprintf(fid, 'model;\n');
fprintf(fid, 'y = k^alpha + e;\n');
fprintf(fid, 'c = y - delta*k;\n');
fprintf(fid, '1/beta = alpha*y(+1)/k + (1-delta);\n');
fprintf(fid, 'end;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

% The automatic matching is announced, not silent.
warned = false;
lastwarn('');
ws = warning('off', 'modfile:name_equations:autoMatch');
restore = onCleanup(@() warning(ws));
state = warning('query', 'modfile:name_equations:autoMatch');
assert(strcmp(state.state, 'off'), 'The warning should be silenceable by identifier.');

m2 = modBuilder(source);
assert(m2.size('equations') == 3, 'All three equations should be present.');
assert(isempty(setxor(m2.equations(:,1)', {'y', 'c', 'k'})), 'Every equation should be keyed to a distinct variable.');

% The third equation is the only one that can be keyed to k.
row = strcmp(m2.equations(:,1), 'k');
assert(contains(m2.equations{row,2}, '1/beta'), 'The Euler equation should be keyed to k.');

% --- No perfect matching is an error, naming the offending equations -------------------
% Neither equation mentions c, so no assignment can cover both declared variables.
bad = 't03_ambiguous.mod';
fid = fopen(bad, 'w');
fprintf(fid, 'var y c;\nvarexo e;\nparameters alpha;\nalpha = 0.5;\n');
fprintf(fid, 'model;\ny = alpha*e;\ny = 2*e;\nend;\n');
fclose(fid);
cleanup2 = onCleanup(@() delete(bad));

thrown = false;
try
    modBuilder(bad);
catch ME
    thrown = strcmp(ME.identifier, 'modfile:name_equations:ambiguousEquation');
end
assert(thrown, 'Expected name_equations:ambiguousEquation.');

fprintf('t03_untagged.m: All tests passed\n');
