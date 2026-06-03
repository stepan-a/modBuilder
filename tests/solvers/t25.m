% solve_system Method= argument: auto / analytical / ad / numerical agree on a nonlinear
% steady state, and the analytical-only path errors on an operator with no differentiation rule.

methods_list = {'auto', 'analytical', 'ad', 'numerical'};
sols = zeros(3, numel(methods_list));
for t = 1:numel(methods_list)
    m = modBuilder();
    m.add('k', '1/beta = alpha*y/k + (1-delta)');
    m.add('y', 'y = k^alpha');
    m.add('c', 'c = y - delta*k');
    m.parameter('alpha', 0.36);
    m.parameter('beta', 0.99);
    m.parameter('delta', 0.025);
    m.endogenous('k', 5);
    m.endogenous('y', 1.5);
    m.endogenous('c', 1);
    m.solve_system({'k', 'y', 'c'}, {'k', 'y', 'c'}, 'Method', methods_list{t}, 'tol', 1e-10);
    sols(:, t) = [m.k; m.y; m.c];
    % Residuals must vanish at the solution.
    for eq = {'k', 'y', 'c'}
        assert(abs(m.evaluate(eq{1}).resid) < 1e-7, ...
               sprintf('Method=%s: residual of %s not zero', methods_list{t}, eq{1}));
    end
end

% Every method converges to the same steady state.
ref = sols(:, 1);
for t = 2:numel(methods_list)
    assert(max(abs(sols(:, t) - ref)) < 1e-8, ...
           sprintf('Method=%s solution differs from Method=auto', methods_list{t}));
end

% Method='analytical' aborts when an equation uses an operator with no differentiation rule.
m = modBuilder();
m.add('y', 'y = adl(x)');     % adl has no differentiation rule
m.add('x', 'x = 0.5');
m.endogenous('y', 1);
m.endogenous('x', 1);
threw = false;
try
    m.solve_system({'y', 'x'}, {'y', 'x'}, 'Method', 'analytical');
catch err
    threw = true;
    assert(strcmp(err.identifier, 'modBuilder:solve_system:noAnalyticalJacobian'), ...
           sprintf('expected modBuilder:solve_system:noAnalyticalJacobian, got %s', err.identifier));
end
assert(threw, 'Method=analytical should abort on an unsupported operator');

% An invalid Method is rejected.
threw = false;
try
    m.solve_system({'y', 'x'}, {'y', 'x'}, 'Method', 'banana');
catch
    threw = true;
end
assert(threw, 'an unknown Method should error');

% Static-Jacobian cache: the analytical path must stay correct after an equation is
% changed (the cache is content-guarded on the equation text, so a changed equation
% rebuilds its partials). Solve once to populate the cache, change an equation, solve
% again, and check the new steady state.
m = modBuilder();
m.add('y', 'y = alpha*x + beta');
m.add('x', 'x = gamma');
m.parameter('alpha', 2);
m.parameter('beta',  1);
m.parameter('gamma', 3);
m.endogenous('y', 0);
m.endogenous('x', 0);
m.solve_system({'y', 'x'}, {'y', 'x'}, 'Method', 'analytical', 'tol', 1e-12);
assert(abs(m.y - 7) < 1e-9 && abs(m.x - 3) < 1e-9, 'first analytical solve: y=7, x=3');

m.change('y', 'y = alpha*x^2 + beta');   % new equation -> cache entry for y is rebuilt
m.y = 0; m.x = 0;
m.solve_system({'y', 'x'}, {'y', 'x'}, 'Method', 'analytical', 'tol', 1e-12);
assert(abs(m.y - 19) < 1e-9 && abs(m.x - 3) < 1e-9, 'after change: analytical solve gives y=19, x=3');

fprintf('solvers/t25.m: solve_system Method= argument OK\n');
