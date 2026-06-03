% modBuilder.augment — grow a model into the (square) optimal-policy problem from the FOCs

addpath ../utils

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
m.augment(r);

% Square optimal-policy problem: 6 endogenous (pi, y, W, mult_1, mult_2, i), 6 equations,
% and no exogenous variables left (the instrument was promoted to endogenous).
assert(size(m.var, 1) == 6,       sprintf('expected 6 endogenous, got %u', size(m.var, 1)));
assert(size(m.equations, 1) == 6, sprintf('expected 6 equations, got %u', size(m.equations, 1)));
assert(isempty(m.varexo),         'the instrument should have been promoted to endogenous');
assert(m.isendogenous('i'),       'instrument i is now endogenous');
assert(m.isendogenous('mult_1') && m.isendogenous('mult_2'), 'multipliers are endogenous');

% The FOCs were added as equations, keyed to the "needy" variables (multipliers + instrument):
% mult_1 <- FOC(pi), mult_2 <- FOC(y), and i <- FOC(i) (the instrument appears in no FOC, so it
% takes the leftover one via the relaxed keying).
assert(equation_equal(m{'mult_1'}.equations{2}, r.foc{1}), 'FOC(pi) keyed to mult_1');
assert(equation_equal(m{'mult_2'}.equations{2}, r.foc{2}), 'FOC(y) keyed to mult_2');
assert(equation_equal(m{'i'}.equations{2},      r.foc{3}), 'FOC(i) keyed to i');

% Multipliers carry the default \mu_{i} texname (positional index).
imu1 = find(strcmp(m.var(:,1), 'mult_1'));
imu2 = find(strcmp(m.var(:,1), 'mult_2'));
assert(strcmp(m.var{imu1, 4}, '\mu_{1}'), 'mult_1 has texname \mu_{1}');
assert(strcmp(m.var{imu2, 4}, '\mu_{2}'), 'mult_2 has texname \mu_{2}');

% The constraints and the welfare equation are untouched.
assert(equation_equal(m{'pi'}.equations{2}, 'pi = beta*pi(+1) + kappa*y'),            'NKPC kept');
assert(equation_equal(m{'y'}.equations{2},  'y = y(+1) - sigma*(i - pi(+1))'),        'IS kept');
assert(equation_equal(m{'W'}.equations{2},  'W = -(pi^2 + lambda*y^2)/2 + beta*W(+1)'), 'welfare kept');

% ---------------------------------------------------------------------------
% A multiplier name that is already taken is rejected with a clear error. The
% check runs before any mutation, so the model is left untouched.
% ---------------------------------------------------------------------------
m2 = modBuilder();
m2.add('pi', 'pi = beta*pi(+1) + kappa*y');
m2.add('y',  'y = y(+1) - sigma*(i - pi(+1))');
m2.add('W',  'W = -(pi^2 + lambda*y^2)/2 + beta*W(+1)');
m2.parameter('beta', 0.99);
m2.parameter('kappa', 0.1);
m2.parameter('sigma', 1);
m2.parameter('lambda', 0.5);
m2.exogenous('i', 0);

rbad = m2.ramsey_foc('W', {'i'}, 'MultiplierNames', {'beta', 'sigma'});   % collide with parameters
caught = false;
try
    m2.augment(rbad);
catch e
    caught = strcmp(e.identifier, 'modBuilder:augment:multiplierExists');
end
assert(caught, 'augment must reject a multiplier name that already exists');

% The same model augments cleanly once the prefix avoids the clash.
r3 = m2.ramsey_foc('W', {'i'}, 'MultiplierPrefix', 'lam');
m2.augment(r3);
assert(m2.isendogenous('lam_1') && m2.isendogenous('lam_2'), 'prefixed multipliers added');

fprintf('foc/t03.m: augment OK\n');
