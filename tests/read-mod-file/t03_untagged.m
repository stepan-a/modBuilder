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

% --- Equations the steady state does not settle -----------------------------------------
% junk = 0.9*junk(+1), 0 = lambda, a bare x and Y/Y(-1) = g pin nothing at the steady
% state under the non-zero convention, yet each is plainly the equation of one variable.
% What the static matching leaves is paired on the dynamic equation, left-hand side first.
source3 = 't03_dynamic.mod';
fid = fopen(source3, 'w');
fprintf(fid, 'var junk lambda x Y g y;\nvarexo e;\nparameters rho;\nrho = 0.9;\n');
fprintf(fid, 'model;\njunk = 0.9*junk(+1);\n0 = lambda;\nx;\nY/Y(-1) = g;\ng = rho*y;\ny = rho*y(-1) + e;\nend;\n');
fclose(fid);
cleanup3 = onCleanup(@() delete(source3));
m3 = modBuilder(source3);
keyof = @(start) m3.equations{startsWith(strtrim(m3.equations(:,2)), start), 1};
assert(strcmp(keyof('junk'), 'junk') && strcmp(keyof('0 = lambda'), 'lambda') && strcmp(keyof('Y/Y(-1)'), 'Y') && strcmp(keyof('g ='), 'g') && any(strcmp(m3.equations(:,1), 'x')), sprintf('Unexpected keys: %s', strjoin(m3.equations(:,1)', ' ')));

% --- A subset of tags ------------------------------------------------------------------
% Tagged equations are keyed first, the rest paired among the variables the tags left.
% A tag that names no variable is ignored; the same tag on two equations is an error
% raised by the reader, with both lines, before any script runs.
source4 = 't03_partial.mod';
fid = fopen(source4, 'w');
fprintf(fid, 'var y c k;\nvarexo e;\nparameters alpha delta;\nalpha = 0.3;\ndelta = 0.1;\n');
fprintf(fid, 'model;\n[name = ''c'']\ny = c + delta*k;\n[name = ''output'']\nc = alpha*k(-1) + e;\nk = (1-delta)*k(-1) + y;\nend;\n');
fclose(fid);
cleanup4 = onCleanup(@() delete(source4));
warning('on', 'modfile:name_equations:autoMatch');
[warned, m4] = evalc('modBuilder(source4)');
warning('off', 'modfile:name_equations:autoMatch');
keyof = @(start) m4.equations{startsWith(strtrim(m4.equations(:,2)), start), 1};
% The tag takes c; of the two others, c = alpha*k(-1) + e mentions no y and must take k,
% which leaves y to the last equation.
assert(strcmp(keyof('y = c'), 'c') && strcmp(keyof('c = alpha'), 'k') && strcmp(keyof('k ='), 'y'), sprintf('The tag should win and the rest be paired around it, got: %s', strjoin(m4.equations(:,1)', ' ')));
assert(contains(regexprep(warned, '\s+', ' '), '2 equation(s) not keyed by a "name" tag'), sprintf('The warning should count the equations the tags did not key, got: %s', warned));

source5 = 't03_duplicate.mod';
fid = fopen(source5, 'w');
fprintf(fid, 'var y c;\nvarexo e;\nparameters alpha;\nalpha = 0.3;\nmodel;\n[name = ''y'']\ny = alpha*e;\n[name = ''y'']\nc = y;\nend;\n');
fclose(fid);
cleanup5 = onCleanup(@() delete(source5));
thrown = '';
message = '';
try
    modBuilder(source5);
catch ME
    thrown = ME.identifier;
    message = ME.message;
end
assert(strcmp(thrown, 'modfile:name_equations:duplicateTag'), sprintf('Expected name_equations:duplicateTag, got "%s".', thrown));
assert(~isempty(regexp(message, 'lines [0-9]+ and [0-9]+ both carry name=''y''', 'once')), sprintf('The error should name both lines, got: %s', message));

fprintf('t03_untagged.m: All tests passed\n');
