% ast.is_monomial_in: predicate cases.

% Monomial cases
assert( ast('alpha*x^2').is_monomial_in('x'),                      'alpha*x^2 is monomial in x');
assert( ast('alpha*x^2 + beta').is_monomial_in('x'),               'alpha*x^2 + beta is monomial in x');
assert( ast('x^d').is_monomial_in('x'),                            'x^d (symbolic d) is monomial in x');
assert( ast('a*x + b').is_monomial_in('x'),                        'linear is also monomial with d=1');
assert( ast('c*theta*h^(1+psi) - (1-alpha)*y').is_monomial_in('h'),'labour FOC residual is monomial in h');

% Non-monomial cases
assert(~ast('alpha').is_monomial_in('x'),               'x-free expression is NOT monomial (no x present)');
assert(~ast('exp(x)').is_monomial_in('x'),              'exp(x) is NOT monomial');
assert(~ast('x^2 + x').is_monomial_in('x'),             'x^2 + x has two distinct exponents — NOT monomial');
assert(~ast('x^x').is_monomial_in('x'),                 'x in exponent — NOT monomial');
% Note: x*x*y collapses to x^2 * y after simplify (collect_powers), so it IS monomial.
% Note: 1/x canonicalises to x^(-1), which IS monomial of degree -1; not tested
% explicitly because the closed form is degenerate when rest = 0.

fprintf('t20.m: is_monomial_in cases OK\n');
