addpath ../utils

% Regression test: matchequations should exclude a candidate that cancels out of
% the static reduction of an equation, and pick the other candidate instead.
%
% Scenario:
%   eq1:  lambda*R*tau - lambda*tau = 0      (lambda cancels; only R can be determined)
%   eq2:  R + gamma = beta*lambda             (both lambda and R appear; either could match)
% Endogenous candidates: {lambda, R}
%
% Without the static-reduction filter, the bipartite matcher could legally pick
% eq1 -> lambda and eq2 -> R, which is wrong (lambda is not actually pinned down
% by eq1). With the static-reduction filter, lambda is excluded from eq1's
% candidate set, forcing the only valid matching: eq1 -> R, eq2 -> lambda.

eq1 = 'lambda*R*tau - lambda*tau';
eq2 = 'R + gamma - beta*lambda';
candidates = {'lambda', 'R'};
eqasts = {ast(eq1).staticise(); ast(eq2).staticise()};
eqlhs_symbols = {{}; {}};

[eq2var, umeqs, umvars] = modBuilder.matchequations(eqasts, eqlhs_symbols, candidates);

if ~isempty(umeqs) || ~isempty(umvars)
    error('matchequations should produce a complete assignment, but left equations / variables unmatched.')
end
if not(strcmp(eq2var{1}, 'R'))
    error('matchequations must assign eq1 -> R (lambda cancels out), got "%s".', eq2var{1})
end
if not(strcmp(eq2var{2}, 'lambda'))
    error('matchequations must assign eq2 -> lambda, got "%s".', eq2var{2})
end

% Also check the underlying check_factor primitive directly.
[has, cancels] = ast(eq1).staticise().check_factor('lambda');
if not(has) || not(cancels)
    error('check_factor("lambda") on the static residual of eq1 must report has=true, cancels=true.')
end
[has, cancels] = ast(eq1).staticise().check_factor('R');
if not(has) || cancels
    error('check_factor("R") on the static residual of eq1 must report has=true, cancels=false.')
end

fprintf('auto_match_static.m: All tests passed\n');
