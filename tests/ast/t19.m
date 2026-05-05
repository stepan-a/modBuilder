% ast.split_linear: extractor returns (a, b) such that o = a*x + b.

% Simple case: alpha*x + beta
[a, b] = ast('alpha*x + beta').split_linear('x');
assert(ast.ast_equal(a, ast('alpha')), sprintf('a should be alpha, got %s', a.string()));
assert(ast.ast_equal(b, ast('beta')),  sprintf('b should be beta, got %s', b.string()));

% Bare x: a = 1, b = 0
[a, b] = ast('x').split_linear('x');
assert(strcmp(a.type, 'num') && a.value == 1, 'a should be num(1)');
assert(strcmp(b.type, 'num') && b.value == 0, 'b should be num(0)');

% Bare constant: a = 0, b = constant
[a, b] = ast('alpha').split_linear('x');
assert(strcmp(a.type, 'num') && a.value == 0, 'a should be num(0) for x-free expression');
assert(ast.ast_equal(b, ast('alpha')),        'b should be alpha');

% AR(1) static residual: a - rho*a - e  =>  a-coef = 1 - rho, b = -e
[a, b] = ast('a - rho*a - e').split_linear('a');
% Verify the closed-form RHS structurally: -b/a should equal e/(1-rho).
neg_b = ast('uminus', [], {b});
rhs = ast('binop', '/', {neg_b, a}).simplify();
expected = ast('e/(1-rho)').simplify();
assert(ast.ast_equal(rhs, expected), sprintf('Closed form should be e/(1-rho), got %s', rhs.string()));

% Two-variable: alpha*x + beta*y, isolate x
[a, b] = ast('alpha*x + beta*y').split_linear('x');
assert(ast.ast_equal(a, ast('alpha')),        'a should be alpha');
assert(ast.ast_equal(b, ast('beta*y')),       sprintf('b should be beta*y, got %s', b.string()));

fprintf('t19.m: split_linear extraction OK\n');
