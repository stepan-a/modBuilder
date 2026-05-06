% suggest_calibrations: returns empty when there is no residual or when
% the user has already declared calibration swaps.

addpath ../utils

% Case 1: no residual — recursive trivial chain. Nothing to suggest.
m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1);
s = m.suggest_calibrations();
if ~isempty(s), error('No-residual model should yield no suggestions; got %d.', numel(s)), end

% Case 2: rbc3 with calibrate('h', 1/3, 'theta') already declared.
% The swap closes the model fully, so total residual is 0; suggest_calibrations
% returns empty (it would also return empty because of the early-return on
% pre-declared swaps; either path produces the right answer).
m2 = modBuilder();
m2.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
m2.add('b', 'b = tau*a(-1) + rho*b(-1) + u');
m2.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
m2.add('c', 'k = exp(b)*(y-c) + (1-deltak)*k(-1)');
m2.add('h', 'c*theta*h^(1+psi) = (1-alpha)*y');
m2.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k + (1-deltak))');
m2.parameter('alpha', 0.36);
m2.parameter('rho', 0.95);
m2.parameter('tau', 0.025);
m2.parameter('beta', 0.99);
m2.parameter('deltak', 0.025);
m2.parameter('psi', 0);
m2.parameter('theta', 2.95);
m2.exogenous('e', 0);
m2.exogenous('u', 0);
m2.calibrate('h', 1/3, 'theta');
s2 = m2.suggest_calibrations();
if ~isempty(s2), error('Pre-declared swap or no residual should suppress suggestions; got %d.', numel(s2)), end

fprintf('t22.m: suggest_calibrations empty cases OK\n');
