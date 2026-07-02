% ast: the binomial-power recogniser (gated, last resort) and the two
% simplifications that enable it -- numeric-call folding and a sum-monomial base.

% Numeric-call folding: log(1) -> 0, exp(0) -> 1.
assert(ast('log(1)').simplify().eval(struct()) == 0, 'log(1) must fold to 0');
assert(abs(ast('exp(0)').simplify().eval(struct()) - 1) < 1e-12, 'exp(0) must fold to 1');

% Binomial-power isolate is gated by allow_binomial: cheap recognisers alone leave
% a*x^p + b*x^q unsolved; enabling the binomial rule closes it.
r0 = ast('3*x^2 - 12*x^5').isolate('x', false);
assert(isempty(r0), 'binomial-power must be off when allow_binomial=false');
r1 = ast('3*x^2 - 12*x^5').isolate('x', true);
assert(~isempty(r1), 'binomial-power must close a*x^p + b*x^q');
v = r1.eval(struct());
assert(abs(3*v^2 - 12*v^5) < 1e-10, 'binomial-power root must satisfy the equation');

% Sum-monomial base: (c - c*e) is homogeneous of degree 1 in c, so a binomial in
% that base -- the household FOC pattern base^p vs base^q after elimination -- closes.
% A*(c-c*e)^3 - B*(c-c*e)^5 = 0 -> (c-c*e)^2 = A/B -> c = (A/B)^(1/2)/(1-e).
r2 = ast('A*(c-c*e)^3 - B*(c-c*e)^5').isolate('c', true);
assert(~isempty(r2), 'binomial in a sum-monomial base must close');
v2 = r2.eval(struct('A', 4, 'B', 1, 'e', 0.5));   % (c-c*e)^2 = 4 -> c*0.5 = 2 -> c = 4
assert(abs(v2 - 4) < 1e-9, 'expected c = 4, got %g', v2);

fprintf('ast/t31: binomial-power (gated) + numeric-call folding + sum-monomial base\n');
