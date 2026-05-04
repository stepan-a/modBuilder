addpath ../utils

% subs accepts an expression target (not just a single symbol). The dispatch
% picks the structural ast.replace_subtree primitive when the target has more
% than one node.

m = modBuilder();
m.add('Y', 'Y = (alpha + beta)*K + gamma');
m.parameter('alpha', 0.3);
m.parameter('beta', 0.2);
m.parameter('gamma', 1);
m.exogenous('K', 1);

% Replace the sub-expression (alpha + beta) by a single symbol
m.subs('alpha + beta', 'sigma');

LHSRHS = strsplit(m{'Y'}.equations{2}, '=');
got = ast(strtrim(LHSRHS{2}));
expected = ast('sigma * K + gamma');
if not(ast.ast_equal(got.simplify(), expected.simplify()))
    error('subs expr: expected "%s", got "%s"', expected.string(), got.string())
end

% sigma is an unknown symbol introduced by the substitution
if not(any(strcmp(m.getallsymbols(), 'sigma')))
    error('subs expr: sigma should be tracked as a new symbol')
end

% alpha and beta are no longer referenced by any equation, so they are dropped
if m.isparameter('alpha') || m.isparameter('beta')
    error('subs expr: alpha and beta should be removed (unused)')
end

% gamma is still referenced
if not(m.isparameter('gamma'))
    error('subs expr: gamma should still be a parameter')
end

fprintf('t10.m: All tests passed\n');
