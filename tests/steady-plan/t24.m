% steady_plan(Match=true): re-pairing equations to variables by bipartite
% matching, with cancellation-aware dependencies, triangularises a block that
% the declaration pairing reports as simultaneous.
%
% The consumption Euler equation "c = beta*R*c(+1)" is keyed to c, but c cancels
% at the steady state (residual c*(1-beta*R)): it pins R = 1/beta, not c. Under
% the declaration pairing this — together with "c = w/R" keyed to R — creates a
% spurious {c, R} 2-cycle. With Match=true the Euler is re-paired to R and its
% cancelling c is dropped from the dependency graph, so the system becomes the
% recursive chain w -> R, w -> c, R -> c.

m = modBuilder();
m.add('c', 'c = beta*R*c(+1)');
m.add('R', 'c = w/R');
m.add('w', 'w = 2');
m.parameter('beta', 0.99);

b0 = m.steady_plan();            % declaration pairing (default)
b1 = m.steady_plan(Match=true);  % steady-state-causal matching

big0 = max(arrayfun(@(b) numel(b.vars), b0));
big1 = max(arrayfun(@(b) numel(b.vars), b1));

assert(big0 == 2, 'declaration pairing should give a 2-variable simultaneous block, got %d', big0);
assert(big1 == 1, 'matched pairing should triangularise to singletons, got %d', big1);
assert(numel(b1) == 3, 'expected 3 singleton blocks, got %d', numel(b1));

fprintf('steady-plan/t24: Match=true triangularises the spurious Euler block (%d -> %d)\n', big0, big1);
