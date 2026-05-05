% ast.split_monomial: extractor returns (a, d, b) such that o = a·x^d + b.

% c·theta·h^(1+psi) - (1-alpha)·y → a=c·theta, d=1+psi, b=-(1-alpha)·y
[a, d, b] = ast('c*theta*h^(1+psi) - (1-alpha)*y').split_monomial('h');
assert(ast.ast_equal(a, ast('c*theta').simplify()),  sprintf('a should be c*theta, got %s', a.string()));
assert(ast.ast_equal(d, ast('1+psi').simplify()),    sprintf('d should be 1+psi, got %s', d.string()));
% b can be either -(1-alpha)*y or alpha*y - y depending on simplification — compare numerically.
neg_b_over_a = ast('binop', '/', {ast.negate_sum(b), a});
inv_d = ast('binop', '/', {ast('num', 1, {}), d});
rhs = ast('binop', '^', {neg_b_over_a, inv_d}).simplify();
expected = ast('((1-alpha)*y / (c*theta))^(1/(1+psi))').simplify();
assert(ast.ast_equal(rhs, expected), sprintf('Closed form mismatch: got %s', rhs.string()));

% bare x^2: a = 1, d = 2, b = 0
[a, d, b] = ast('x^2').split_monomial('x');
assert(strcmp(a.type, 'num') && a.value == 1, 'a should be num(1)');
assert(strcmp(d.type, 'num') && d.value == 2, 'd should be num(2)');
assert(strcmp(b.type, 'num') && b.value == 0, 'b should be num(0)');

fprintf('t21.m: split_monomial extraction OK\n');
