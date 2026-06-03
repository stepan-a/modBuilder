% modBuilder.lagrangian_foc — Bellman/Lagrangian first-order conditions

% ---------------------------------------------------------------------------
% Optimal growth (intertemporal): max E Σ βᵗ log(c)  s.t. the resource constraint.
% Expect the static control FOC (marginal utility = multiplier) and the dynamic
% state Euler (with the discounted lead multiplier).
% ---------------------------------------------------------------------------
m = modBuilder();
m.add('W', 'W = log(c) + beta*W(+1)');
m.add('k', 'A*k(-1)^alpha + (1-delta)*k(-1) = c + k');   % resource constraint
m.parameter('beta', 0.99);
m.parameter('A', 1);
m.parameter('alpha', 0.33);
m.parameter('delta', 0.025);

r = m.lagrangian_foc('W', {'k'}, {'c', 'k'});
assert(isequal(r.multipliers, {'mult_k'}), 'one multiplier per constraint');
assert(isequal(r.controls, {'c', 'k'}),    'controls echoed back');

% FOC(c): 1/c - mult_k = 0
assert(foc_equal(r.foc{1}, '1/c - mult_k'), sprintf('FOC(c) wrong: %s', r.foc{1}));
% FOC(k): -mult_k + beta*mult_k(+1)*(A*alpha*k^(alpha-1) + 1 - delta) = 0  (consumption Euler)
assert(foc_equal(r.foc{2}, '-mult_k + beta*mult_k(+1)*(A*alpha*k^(alpha-1) + 1 - delta)'), ...
       sprintf('FOC(k) wrong: %s', r.foc{2}));

% ---------------------------------------------------------------------------
% Static constrained problem (no continuation): max x^a y^(1-a) s.t. budget.
% The discount M = 0 is never used (no leads); the FOCs collapse to ∂L/∂· = 0.
% ---------------------------------------------------------------------------
m2 = modBuilder();
m2.add('U', 'U = x^a*y^(1-a)');
m2.add('x', 'px*x + py*y = I');     % budget, keyed to x
m2.parameter('a', 0.5);
m2.parameter('px', 1);
m2.parameter('py', 2);
m2.parameter('I', 10);

r2 = m2.lagrangian_foc('U', {'x'}, {'x', 'y'});
assert(foc_equal(r2.foc{1}, 'a*x^(a-1)*y^(1-a) + mult_x*px'),   sprintf('static FOC(x) wrong: %s', r2.foc{1}));
assert(foc_equal(r2.foc{2}, '(1-a)*x^a*y^(-a) + mult_x*py'),    sprintf('static FOC(y) wrong: %s', r2.foc{2}));

fprintf('foc/t01.m: lagrangian_foc OK\n');

% Compare a returned FOC ("<expr> = 0") to an expected expression, modulo the AST's
% canonical form.
function tf = foc_equal(focstr, expected)
    % Equal up to algebra: expand+simplify the difference and check it vanishes (robust to
    % fractions the local simplify leaves un-distributed). tsym lags are kept distinct.
    parts = strsplit(focstr, '=');
    d = ast('binop', '-', {ast(strtrim(parts{1})), ast(expected)}).expand().simplify();
    tf = strcmp(d.type, 'num') && abs(d.value) < 1e-12;
end
