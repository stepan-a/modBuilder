% simplify: constant folding, identities, and structural cancellation.
%
% NOTE: simplify returns a tree in canonical form (subtraction as '+ uminus',
% division as '* ^(-1)'). When comparing expected and actual results, build the
% expected from a string and canonicalise it — the renderer pretty-prints back
% to '-' and '/' but the underlying tree shape uses the canonical operators.

eq_canon = @(a, b) ast.ast_equal(a.canonicalise(), b.canonicalise());

% Constant folding
assert(eq_canon(ast('2 + 3').simplify(), ast('5')), '2 + 3 → 5');
assert(eq_canon(ast('6 / 2').simplify(), ast('3')), '6 / 2 → 3');
assert(eq_canon(ast('2 ^ 3').simplify(), ast('8')), '2 ^ 3 → 8');

% Additive identities
assert(eq_canon(ast('0 + x').simplify(), ast('x')), '0 + x → x');
assert(eq_canon(ast('x + 0').simplify(), ast('x')), 'x + 0 → x');
assert(eq_canon(ast('x - 0').simplify(), ast('x')), 'x - 0 → x');

% Multiplicative identities
assert(eq_canon(ast('0 * x').simplify(), ast('0')), '0 * x → 0');
assert(eq_canon(ast('x * 0').simplify(), ast('0')), 'x * 0 → 0');
assert(eq_canon(ast('1 * x').simplify(), ast('x')), '1 * x → x');
assert(eq_canon(ast('x * 1').simplify(), ast('x')), 'x * 1 → x');
assert(eq_canon(ast('x / 1').simplify(), ast('x')), 'x / 1 → x');
assert(eq_canon(ast('0 / x').simplify(), ast('0')), '0 / x → 0');

% Power identities
assert(eq_canon(ast('x ^ 0').simplify(), ast('1')), 'x ^ 0 → 1');
assert(eq_canon(ast('x ^ 1').simplify(), ast('x')), 'x ^ 1 → x');
assert(eq_canon(ast('1 ^ x').simplify(), ast('1')), '1 ^ x → 1');

% Double negation
n = ast('uminus', [], {ast('uminus', [], {ast('sym', 'x', {})})}).simplify();
assert(ast.ast_equal(n, ast('sym', 'x', {})), '--x → x');

% Structural cancellation
assert(eq_canon(ast('f - f').simplify(), ast('0')), 'f - f → 0');
assert(eq_canon(ast('f / f').simplify(), ast('1')), 'f / f → 1');
assert(eq_canon(ast('(a*b - a*b)').simplify(), ast('0')), 'a*b - a*b → 0');

% Structural cancellation across commutativity (canonicalise normalises operand order)
assert(eq_canon(ast('a*b - b*a').simplify(), ast('0')), 'a*b - b*a → 0');

% Structural merging
assert(eq_canon(ast('f + f').simplify(), ast('2*f')), 'f + f → 2*f');
assert(eq_canon(ast('f * f').simplify(), ast('f^2')), 'f * f → f^2');

% The motivating w/w − ω case from the design note: now reduces to 1 - ω
n = ast('w/w - omega').simplify();
assert(eq_canon(n, ast('1 - omega')), 'w/w - omega → 1 - omega');

% After simplification, w no longer appears: check_factor reports has=false
[has, cancels] = n.check_factor('w');
assert(~has && ~cancels, 'after simplify, w/w - omega does not contain w anymore');

% Idempotent: simplify(simplify(t)) == simplify(t)
n1 = ast('a*b + 0 - a*b + 1*c').simplify();
n2 = n1.simplify();
assert(ast.ast_equal(n1, n2), 'simplify is idempotent');
