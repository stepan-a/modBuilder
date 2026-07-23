% ast.is_invertible_call_in / split_invertible_call: exp / log unwrap.

% Positive cases
assert( ast('exp(a)*K - y').is_invertible_call_in('a'),                'coef · exp(a) + rest is invertible');
assert( ast('y - exp(a)*K').is_invertible_call_in('a'),                'rest - coef · exp(a) is invertible');
assert( ast('log(R) - beta*pi').is_invertible_call_in('R'),            'log(R) + rest is invertible');
assert( ast('y - exp(a)*k^alpha*h^(1-alpha)').is_invertible_call_in('a'), 'productivity in production function is invertible');

% Several occurrences of the SAME call subtree are accepted (coefficients summed):
% the additive log AR static residual log(Z) - rho*log(Z) pins u = log(Z).
assert( ast('log(Z) - rho*log(Z)').is_invertible_call_in('Z'),         'repeated identical call is invertible');
assert( ast('log(W/wbar) - rw*log(W/wbar)').is_invertible_call_in('W'), 'centred repeated call is invertible');

% Negative cases
assert(~ast('exp(a) - exp(a + 1)').is_invertible_call_in('a'),         'two calls with DIFFERENT arguments — NOT invertible');
assert(~ast('exp(a) + a').is_invertible_call_in('a'),                  'a inside exp AND outside — NOT invertible');
assert(~ast('sin(a) - x').is_invertible_call_in('a'),                  'sin not in allowlist — NOT invertible');
assert(~ast('a + b').is_invertible_call_in('a'),                       'no call wrapping a — NOT invertible');
assert(~ast('rho*log(Z) - rho*log(Z) + q').is_invertible_call_in('Z'), 'summed coefficient folds to zero — NOT invertible');

% Decomposition
[fname, P, coef, rest] = ast('y - exp(a)*K').split_invertible_call('a');
assert(strcmp(fname, 'exp'),                       sprintf('fname should be exp, got %s', fname));
assert(ast.ast_equal(P, ast('a')),                 sprintf('P should be a, got %s', P.string()));
% coef is -K (the uminus from the leading minus is absorbed); rest is y.
assert(ast.ast_equal(rest, ast('y')),              sprintf('rest should be y, got %s', rest.string()));

% Verify the inverted equation closes via the linear recogniser on a (via isolate).
rhs = ast('y - exp(a)*K').isolate('a');
expected = ast('log(y/K)').simplify();
assert(ast.ast_equal(rhs, expected),               sprintf('isolate(a) should give log(y/K), got %s', rhs.string()));

% Multi-occurrence closes end to end: (1-rho)·log(Z) = 0 → Z = 1, centred → wbar,
% and a drift term lands in rest: (1-rho)·log(Z) = (1-rho)·mu → Z = exp(mu).
rhs = ast('log(Z) - rho*log(Z)').isolate('Z');
assert(ast.ast_equal(rhs.simplify(), ast('1').simplify()),    sprintf('isolate(Z) should give 1, got %s', rhs.string()));
rhs = ast('log(W/wbar) - rw*log(W/wbar)').isolate('W');
assert(ast.ast_equal(rhs.simplify(), ast('wbar').simplify()), sprintf('isolate(W) should give wbar, got %s', rhs.string()));
rhs = ast('log(Z) - rho*log(Z) - (1-rho)*mu').isolate('Z');
chk = ast('binop', '-', {rhs, ast('exp(mu)')}).expand().simplify();
assert(ast.is_zero(chk),                           sprintf('isolate(Z) with drift should give exp(mu), got %s', rhs.string()));

% Unit-root diagnostic: when the summed coefficient folds to zero the equation pins
% the growth of f(P), not its level -- isolate reports it through its second output.
[rhs, info] = ast('log(Z) - (1-lam)*log(Z) - lam*log(Z) - ez').isolate('Z');
assert(isempty(rhs) && info.unit_root,             'zero-sum coefficients must raise the unit_root diagnostic');
[~, info] = ast('log(Z) - rho*log(Z)').isolate('Z');
assert(~info.unit_root,                            'a pinned equation must not raise unit_root');

% Zero-base guard: under the non-zero steady-state convention, a·x^d = 0 pins x
% only when d is a positive number. The c-cancelling Euler condition must NOT
% pretend to pin c through the 0^(-1/sig) artefact (the equation pins R), a
% positive power yields the literal zero root (callers filter it with
% reject_zero), and coef*exp(P) = 0 has no root at all (never fabricate log(0)).
rhs = ast('c^(-sig) - beta*R*c^(-sig)').isolate('c');
assert(isempty(rhs),                               'a c-cancelling equation must not return a closed form for c');
rhs = ast('2*x^3').isolate('x');
assert(~isempty(rhs) && strcmp(rhs.type, 'num') && rhs.value == 0, 'a positive numeric power must pin the literal zero root');
rhs = ast('k*exp(a)').isolate('a');
assert(isempty(rhs),                               'coef*exp(P) = 0 has no root; no log(0) closed form');

% The pinning divisors travel in info.coefs so a caller holding a calibration can
% detect knife-edge points (coefficient symbolically non-zero, numerically zero).
[rhs, info] = ast('b - R*b - x').isolate('b');
assert(~isempty(rhs) && isscalar(info.coefs),      'the linear recogniser must expose its pinning coefficient');
assert(abs(info.coefs{1}.eval(struct('R', 1))) < 1e-14, 'the coefficient must evaluate to 0 at R = 1');
assert(abs(info.coefs{1}.eval(struct('R', 0.5)) - 0.5) < 1e-14, 'the coefficient must evaluate to 1-R off the knife edge');

% The binomial-power recogniser groups exponents up to rational equality: two
% structurally different writings of the same exponent form ONE class, so a sum
% that is mathematically a two-power binomial closes even when the substitution
% chains disguised it as three powers.
r = ast('2*x^(alpha/(alpha+phi) + sigma) + 3*x^((alpha + sigma*(alpha+phi))/(alpha+phi)) - w*x');
rhs = r.isolate('x');
assert(~isempty(rhs), 'disguised two-power binomial must close');
vals = struct('alpha', 0.3, 'phi', 1.5, 'sigma', 2, 'w', 4);
xv = rhs.eval(vals);
E = vals.alpha/(vals.alpha+vals.phi) + vals.sigma;
assert(abs(2*xv^E + 3*xv^E - vals.w*xv) < 1e-9, 'the recovered root must solve the disguised binomial');

fprintf('t22.m: invertible-call recogniser + isolate OK\n');
