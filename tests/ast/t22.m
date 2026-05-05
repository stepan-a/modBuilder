% ast.is_invertible_call_in / split_invertible_call: exp / log unwrap.

% Positive cases
assert( ast('exp(a)*K - y').is_invertible_call_in('a'),                'coef · exp(a) + rest is invertible');
assert( ast('y - exp(a)*K').is_invertible_call_in('a'),                'rest - coef · exp(a) is invertible');
assert( ast('log(R) - beta*pi').is_invertible_call_in('R'),            'log(R) + rest is invertible');
assert( ast('y - exp(a)*k^alpha*h^(1-alpha)').is_invertible_call_in('a'), 'productivity in production function is invertible');

% Negative cases
assert(~ast('exp(a) - exp(a + 1)').is_invertible_call_in('a'),         'two x-bearing terms — NOT invertible');
assert(~ast('exp(a) + a').is_invertible_call_in('a'),                  'a inside exp AND outside — NOT invertible');
assert(~ast('sin(a) - x').is_invertible_call_in('a'),                  'sin not in allowlist — NOT invertible');
assert(~ast('a + b').is_invertible_call_in('a'),                       'no call wrapping a — NOT invertible');

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

fprintf('t22.m: invertible-call recogniser + isolate OK\n');
