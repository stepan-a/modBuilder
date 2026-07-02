% ast.expand distributes a power over a product -- (a*b)^e -> a^e * b^e for any
% exponent -- so a variable appearing in several factors collects into one power,
% exposing a monomial that isolate can then invert.

% (a*b)^3 -> a^3 * b^3 (numeric check at a=2, b=5, e=3: 1000).
r = ast('(a*b)^e').expand();
assert(abs(r.eval(struct('a',2,'b',5,'e',3)) - 1000) < 1e-9, '(a*b)^e must expand to a^e*b^e');

% x^p * (x*b)^q collapses to x^(p+q)*b^q, i.e. a monomial in x.
e = ast('x^p*(x*b)^q').expand();
assert(e.is_monomial_in('x'), 'x^p*(x*b)^q must expand to a monomial in x');

% Consequently isolate closes EGDP - x^a*(x*b)^(1-a) once expanded: x = EGDP/b^(1-a).
res = ast('EGDP - x^a*(x*b)^(1-a)').expand();
sol = res.isolate('x');
assert(~isempty(sol), 'the expanded monomial must be isolable');
v = sol.eval(struct('EGDP',12,'a',0.3,'b',4));
assert(abs(12 - v^0.3*(v*4)^0.7) < 1e-9, 'isolated x must satisfy the equation');

fprintf('ast/t32: expand distributes power over product; multi-factor x collapses to a monomial\n');
