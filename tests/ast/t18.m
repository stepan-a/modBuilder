% ast.is_linear_in: predicate cases.

% Linear cases
assert( ast('alpha*x').is_linear_in('x'),         'alpha*x is linear in x');
assert( ast('alpha*x + beta').is_linear_in('x'),  'alpha*x + beta is linear in x');
assert( ast('x').is_linear_in('x'),               'bare x is linear in x');
assert( ast('-x').is_linear_in('x'),              '-x is linear in x');
assert( ast('alpha*x + beta*y').is_linear_in('x'),'two-term linear in x');
assert( ast('a - rho*a').is_linear_in('a'),       'collected: a - rho*a is linear in a');
assert( ast('x/2').is_linear_in('x'),             'x/2 is linear in x');
assert( ast('5').is_linear_in('x'),               'constant is trivially linear in x (0 occurrences)');
assert( ast('y + z').is_linear_in('x'),           'x-free expression is trivially linear in x');

% Non-linear cases
assert(~ast('x^2').is_linear_in('x'),             'x^2 is NOT linear in x');
assert(~ast('x*x').is_linear_in('x'),             'x*x is NOT linear in x');
assert(~ast('exp(x)').is_linear_in('x'),          'exp(x) is NOT linear in x');
assert(~ast('log(x)').is_linear_in('x'),          'log(x) is NOT linear in x');
assert(~ast('1/x').is_linear_in('x'),             '1/x is NOT linear in x (x in denominator)');
assert(~ast('alpha/x').is_linear_in('x'),         'alpha/x is NOT linear in x');
assert(~ast('x^alpha').is_linear_in('x'),         'x^alpha is NOT linear in x');
assert(~ast('alpha^x').is_linear_in('x'),         'alpha^x is NOT linear in x (x in exponent)');
assert(~ast('x*y*x').is_linear_in('x'),           'x*y*x is NOT linear in x (two factors)');

% STEADY_STATE(x) is a constant — does not break linearity.
assert( ast('STEADY_STATE(x)*y').is_linear_in('x'),   'STEADY_STATE(x)*y is linear in x (ss is constant)');

fprintf('t18.m: is_linear_in cases OK\n');
