% modBuilder.ramsey_foc — optimal-policy first-order conditions (New Keynesian model)

m = modBuilder();
m.add('pi', 'pi = beta*pi(+1) + kappa*y');                 % NKPC
m.add('y',  'y = y(+1) - sigma*(i - pi(+1))');             % IS
m.add('W',  'W = -(pi^2 + lambda*y^2)/2 + beta*W(+1)');    % recursive welfare (per-period loss)
m.parameter('beta', 0.99);
m.parameter('kappa', 0.1);
m.parameter('sigma', 1);
m.parameter('lambda', 0.5);
m.exogenous('i', 0);                                       % instrument

r = m.ramsey_foc('W', {'i'});

% Constraints = NKPC and IS -> one multiplier each; controls = endogenous + instrument - W.
assert(isequal(r.multipliers, {'mult_pi', 'mult_y'}), 'a multiplier per constraint');
assert(isequal(r.controls, {'pi', 'y', 'i'}),          'controls = pi, y, i');

% FOC(pi): -pi + mult_pi - mult_pi(-1) - (sigma/beta)*mult_y(-1) = 0
assert(foc_equal(r.foc{1}, '-pi + mult_pi - mult_pi(-1) - sigma/beta*mult_y(-1)'), ...
       sprintf('FOC(pi) wrong: %s', r.foc{1}));
% FOC(y): mult_y - kappa*mult_pi - lambda*y - mult_y(-1)/beta = 0
assert(foc_equal(r.foc{2}, 'mult_y - kappa*mult_pi - lambda*y - mult_y(-1)/beta'), ...
       sprintf('FOC(y) wrong: %s', r.foc{2}));
% FOC(i): the instrument appears only in the IS curve, so its FOC pins mult_y to zero.
assert(foc_equal(r.foc{3}, 'sigma*mult_y'), sprintf('FOC(i) wrong: %s', r.foc{3}));

fprintf('foc/t02.m: ramsey_foc OK\n');

function tf = foc_equal(focstr, expected)
    % Equal up to algebra: expand+simplify the difference and check it vanishes (robust to
    % fractions the local simplify leaves un-distributed). tsym lags are kept distinct.
    parts = strsplit(focstr, '=');
    d = ast('binop', '-', {ast(strtrim(parts{1})), ast(expected)}).expand().simplify();
    tf = strcmp(d.type, 'num') && abs(d.value) < 1e-12;
end
