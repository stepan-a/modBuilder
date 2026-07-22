% steady_plan: the ratio-priority elimination closes a coupled two-country core
% down to a SINGLE unknown. Each Euler condition identifies the capital/hours
% ratio of its country, risk sharing identifies c_1 against c_2; consuming those
% first keeps the world resource constraint from burying the system in
% (sum)^(-sigma), and 5 of the 6 core variables close conditional on the last one
% (which variable remains open depends on greedy tie-breaks -- not asserted).

m = modBuilder();
for i = {'1', '2'}
    s = i{1};
    m.add(['k_' s], ['c_' s '^(-sigma) = beta*c_' s '(+1)^(-sigma)*(alpha*A_' s '*k_' s '^(alpha-1)*h_' s '^(1-alpha) + 1 - delta)']);
    m.add(['h_' s], ['chi*h_' s '^phi = (1-alpha)*A_' s '*k_' s '^alpha*h_' s '^(-alpha)*c_' s '^(-sigma)']);
end
m.add('c_1', 'c_1^(-sigma) = omega*c_2^(-sigma)');
m.add('c_2', 'A_1*k_1^alpha*h_1^(1-alpha) + A_2*k_2^alpha*h_2^(1-alpha) = c_1 + c_2 + delta*(k_1 + k_2)');
m.parameter('alpha', 0.33);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);
m.parameter('sigma', 2);
m.parameter('phi', 1.5);
m.parameter('chi', 1);
m.parameter('omega', 1.2);
m.parameter('A_1', 1);
m.parameter('A_2', 1);
m.endogenous('k_1', 10);
m.endogenous('k_2', 10);
m.endogenous('h_1', 1);
m.endogenous('h_2', 1);
m.endogenous('c_1', 1);
m.endogenous('c_2', 1);

pl = m.steady_plan(Match=true);
core = pl(arrayfun(@(x) numel(x.vars) == 6, pl));
assert(isscalar(core), 'the six core variables must form one simultaneous block');
assert(numel(core.closed_form) == 5, sprintf('ratio priority must close 5/6, got %d', numel(core.closed_form)));
assert(isscalar(core.reduced.vars), 'exactly one variable must remain open');

% Solve the reduced residual for the open variable by a secant iteration, then
% verify the conditional closed forms deliver an exact steady state.
vals = struct('alpha', 0.33, 'beta', 0.99, 'delta', 0.025, 'sigma', 2, 'phi', 1.5, 'chi', 1, 'omega', 1.2, 'A_1', 1, 'A_2', 1);
open_var = core.reduced.vars{1};
g = ast(core.reduced.residuals{1});
x0 = 5; x1 = 15;
vals.(open_var) = x0; g0 = g.eval(vals);
vals.(open_var) = x1; g1 = g.eval(vals);
for it = 1:60
    x2 = x1 - g1*(x1 - x0)/(g1 - g0);
    x0 = x1; g0 = g1;
    vals.(open_var) = x2; g1 = g.eval(vals);
    x1 = x2;
    if abs(g1) < 1e-12, break, end
end
assert(abs(g1) < 1e-10, sprintf('secant failed on the reduced residual (%g)', g1));
for j = 1:numel(core.closed_form)
    vals.(core.closed_form(j).var) = ast(core.closed_form(j).expr).eval(vals);
end
r = zeros(6, 1);
r(1) = vals.c_1^(-vals.sigma) - vals.beta*vals.c_1^(-vals.sigma)*(vals.alpha*vals.A_1*vals.k_1^(vals.alpha-1)*vals.h_1^(1-vals.alpha) + 1 - vals.delta);
r(2) = vals.chi*vals.h_1^vals.phi - (1-vals.alpha)*vals.A_1*vals.k_1^vals.alpha*vals.h_1^(-vals.alpha)*vals.c_1^(-vals.sigma);
r(3) = vals.c_2^(-vals.sigma) - vals.beta*vals.c_2^(-vals.sigma)*(vals.alpha*vals.A_2*vals.k_2^(vals.alpha-1)*vals.h_2^(1-vals.alpha) + 1 - vals.delta);
r(4) = vals.chi*vals.h_2^vals.phi - (1-vals.alpha)*vals.A_2*vals.k_2^vals.alpha*vals.h_2^(-vals.alpha)*vals.c_2^(-vals.sigma);
r(5) = vals.c_1^(-vals.sigma) - vals.omega*vals.c_2^(-vals.sigma);
r(6) = vals.A_1*vals.k_1^vals.alpha*vals.h_1^(1-vals.alpha) + vals.A_2*vals.k_2^vals.alpha*vals.h_2^(1-vals.alpha) - vals.c_1 - vals.c_2 - vals.delta*(vals.k_1 + vals.k_2);
assert(max(abs(r)) < 1e-9, sprintf('closed forms must deliver an exact steady state (max residual %g)', max(abs(r))));

fprintf('steady-plan/t40: ratio priority closes the two-country core down to one unknown\n');
