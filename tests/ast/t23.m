% ast.is_linear_in_set / split_linear_set / linearise_system / solve_linear_system

% Joint linearity recogniser
assert( ast('(1-rho)*a - tau*b - e').is_linear_in_set({'a', 'b'}), 'joint AR residual is linear in {a, b}');
assert( ast('a + b').is_linear_in_set({'a', 'b'}),                 'a + b is linear in {a, b}');
assert(~ast('a*b - c').is_linear_in_set({'a', 'b'}),               'a*b is bilinear — NOT linear in set {a, b}');
assert(~ast('a^2 - c').is_linear_in_set({'a', 'b'}),               'a^2 — NOT linear in set');
assert(~ast('exp(a) - c').is_linear_in_set({'a', 'b'}),            'a inside exp — NOT linear in set');

% Per-equation extraction
[coefs, const] = ast.split_linear_set(ast('(1-rho)*a - tau*b - e'), {'a', 'b'});
assert(ast.ast_equal(coefs{1}, ast('1-rho').simplify()),  sprintf('coef(a) should be 1-rho, got %s', coefs{1}.string()));
assert(ast.ast_equal(coefs{2}, ast('-tau').simplify()),   sprintf('coef(b) should be -tau, got %s', coefs{2}.string()));
assert(ast.ast_equal(const, ast('-e').simplify()),        sprintf('const should be -e, got %s', const.string()));

% System linearisation: joint AR
res1 = ast('a - rho*a - tau*b - e');
res2 = ast('b - tau*a - rho*b - u');
[ok, A, b_vec] = ast.linearise_system({res1, res2}, {'a', 'b'});
assert(ok, 'joint AR system should linearise');
assert(ast.ast_equal(A{1,1}.simplify(), ast('1-rho').simplify()),  'A(1,1) should be 1-rho');
assert(ast.ast_equal(A{1,2}.simplify(), ast('-tau').simplify()),   'A(1,2) should be -tau');
assert(ast.ast_equal(A{2,1}.simplify(), ast('-tau').simplify()),   'A(2,1) should be -tau');
assert(ast.ast_equal(A{2,2}.simplify(), ast('1-rho').simplify()),  'A(2,2) should be 1-rho');
assert(ast.ast_equal(b_vec{1}.simplify(), ast('-e').simplify()),   'b(1) should be -e');
assert(ast.ast_equal(b_vec{2}.simplify(), ast('-u').simplify()),   'b(2) should be -u');

% Cramer's rule: closed forms via solve_linear_system
rhs_list = ast.solve_linear_system(A, b_vec);

% Numerical check: with rho=0.5, tau=0.1, e=1, u=2, expect a ≈ 0.7/0.24, b ≈ 1.1/0.24.
values = struct('rho', 0.5, 'tau', 0.1, 'e', 1, 'u', 2);
a_val = rhs_list{1}.eval(values);
b_val = rhs_list{2}.eval(values);
assert(abs(a_val - 0.7/0.24) < 1e-10, sprintf('a value %g should equal 0.7/0.24', a_val));
assert(abs(b_val - 1.1/0.24) < 1e-10, sprintf('b value %g should equal 1.1/0.24', b_val));

fprintf('t23.m: linear-system Cramer solver OK\n');
