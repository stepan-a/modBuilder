% steady_plan(PropagateKnown=true): inline the known steady-state values (anchors,
% and constant closed forms of earlier blocks) into a block's residual before the
% recognisers run. A factor that is constant at the steady state then collapses,
% turning an otherwise unrecognisable residual into a solvable one.
%
% x solves x^2 + s*x - c = 0. With s a free unknown this is a genuine quadratic
% that no recogniser closes. But s is an anchor known to be 0 at the steady state;
% substituting s = 0 collapses the residual to x^2 - c, which the monomial
% recogniser closes as x = c^(1/2).

m = modBuilder();
m.add('x', 'x^2 + s*x - c');
m.add('s', 's - g');
m.parameter('c', 4);
m.parameter('g', 0);
m.steady('s', '0');           % the known steady-state value of the anchor s

xblock = @(b) b(arrayfun(@(z) strcmp(z.vars{1}, 'x'), b));

% Without propagation: the quadratic residual is left unsolved.
b0 = m.steady_plan(Match=true, Anchors={'s'});
assert(isempty(xblock(b0).closed_form), 'without propagation x must stay unsolved (quadratic)');

% With propagation: s -> 0 collapses x^2 + s*x - c to x^2 - c, which closes.
b1 = m.steady_plan(Match=true, Anchors={'s'}, PropagateKnown=true);
cf = xblock(b1).closed_form;
assert(~isempty(cf) && strcmp(cf(1).var, 'x'), 'with propagation x must be solved');

fprintf('steady-plan/t28: known-value propagation collapses x^2+s*x-c to x^2-c -> %s\n', cf(1).expr);
