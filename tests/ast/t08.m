% check_factor: examples from the design note (after staticisation).

% beta*R*lambda*tau/pi - lambda*tau   over lambda → has=true, cancels=true
n = ast('beta*R*lambda*tau/pi - lambda*tau').staticise();
[has, cancels] = n.check_factor('lambda');
assert(has && cancels, 'lambda is a common factor');

% Same expression, over R → has=true, cancels=false (R only in one term)
[has, cancels] = n.check_factor('R');
assert(has && ~cancels, 'R appears in only one additive term');

% lambda*tau over lambda → cancels=true (lambda is a single multiplicative factor)
n = ast('lambda*tau').staticise();
[has, cancels] = n.check_factor('lambda');
assert(has && cancels, 'lambda factors out of lambda*tau');

% NOTE: w/w - omega should ideally also yield cancels=true (w/w = 1) but
% recognising this requires algebraic simplification (the follow-up simplify
% pass). The MVP multiplicative-factor algorithm conservatively returns
% cancels=false here.
n = ast('w/w - omega').staticise();
[has, cancels] = n.check_factor('w');
assert(has && ~cancels, 'MVP: w/w not detected as constant; cancels=false');

% (C - eta*C/g)^(-sigma)*exp(z) - tauC*lambda over lambda → cancels=false
n = ast('(C - eta*C/g)^(-sigma)*exp(z) - tauC*lambda').staticise();
[has, cancels] = n.check_factor('lambda');
assert(has && ~cancels, 'lambda only on one side');

% A symbol that is absent everywhere
[has, cancels] = ast('alpha + beta').check_factor('gamma');
assert(~has && ~cancels, 'absent symbol');

% Variable in a denominator does not cancel: f/x
[has, cancels] = ast('alpha/x').staticise().check_factor('x');
assert(has && ~cancels, 'x in denominator does not cancel');

% Variable in an exponent does not cancel: f^x
[has, cancels] = ast('alpha^x').staticise().check_factor('x');
assert(has && ~cancels, 'x in exponent does not cancel');

% Variable inside a nonlinear call does not cancel
[has, cancels] = ast('exp(x) - 1').staticise().check_factor('x');
assert(has && ~cancels, 'x inside exp does not cancel');

% x^n cancels (it is a multiplicative factor x^n)
[has, cancels] = ast('x^2 + x^3').staticise().check_factor('x');
assert(has && cancels, 'x^n cancels as a factor');

% STEADY_STATE(x) is not the same as x: variable does not match
[has, cancels] = ast('STEADY_STATE(x) + alpha').check_factor('x');
assert(~has && ~cancels, 'STEADY_STATE(x) does not match dynamic x');

% tsym matches by name (without staticisation), since check_factor compares names
[has, cancels] = ast('alpha*x(-1) + beta*x(+1)').check_factor('x');
assert(has && cancels, 'x cancels across leads/lags');
