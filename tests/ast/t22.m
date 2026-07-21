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

fprintf('t22.m: invertible-call recogniser + isolate OK\n');
