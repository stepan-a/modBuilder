% clear_denominators and the rational-normalisation fallback in isolate /
% linearise_system.
%
% Closed forms inlined into rational chains bury a linear structure under
% nested (a+b*x)/(c+d*x) quotients that no recogniser sees through. Multiplying
% the denominators out preserves the roots (non-zero steady-state convention)
% and re-exposes the structure: '+' chains are combined over the multiset lcm
% of the per-term denominator factor lists, so denominators shared across terms
% are not squared and a Moebius-form equation clears to a linear one.

addpath ../utils

tol = 1e-12;

% Shared denominator counted once: a/(c+d*x) + b/(c+d*x) - e clears linear in x.
r = ast('a/(c+d*x) + b/(c+d*x) - e');
cleared = r.clear_denominators();
assert(cleared.is_linear_in('x'), 'shared denominator must clear to a linear residual');
rhs = r.isolate('x');
assert(~isempty(rhs), 'isolate must see through the shared denominator');
v = struct('a', 2, 'b', 3, 'c', 1, 'd', 2, 'e', 0.5);
xs = rhs.eval(v);
assert(abs((v.a + v.b)/(v.c + v.d*xs) - v.e) < tol, 'isolated root must satisfy the equation');

% Moebius = constant is linear after clearing: (2+3*x)/(1+x) = 4 -> x = -2.
rhs = ast('(2+3*x)/(1+x) - 4').isolate('x');
assert(~isempty(rhs) && abs(rhs.eval(struct()) + 2) < tol, 'Moebius-form equation must isolate');

% Composition of Moebius maps stays Moebius: nested quotients still isolate.
r = ast('((a+b*x)/(c+d*x) + e)/(f + g*(a+b*x)/(c+d*x)) - h');
rhs = r.isolate('x');
assert(~isempty(rhs), 'nested Moebius must isolate');
v = struct('a', 1, 'b', 2, 'c', 3, 'd', 0.5, 'e', 0.25, 'f', 1.5, 'g', 0.75, 'h', 0.6);
xs = rhs.eval(v);
m = (v.a + v.b*xs)/(v.c + v.d*xs);
assert(abs((m + v.e)/(v.f + v.g*m) - v.h) < tol, 'nested Moebius root must satisfy the equation');

% Invertible call wrapping a rational: log((a+b*x)/(c+d*x)) = 0.
rhs = ast('log((a+b*x)/(c+d*x))').isolate('x');
assert(~isempty(rhs), 'call unwrap must chain with the rational fallback');
v = struct('a', 1, 'b', 2, 'c', 4, 'd', 0.5);
xs = rhs.eval(v);
assert(abs(log((v.a + v.b*xs)/(v.c + v.d*xs))) < tol, 'unwrapped rational root must satisfy the equation');

% Degenerate quotient: (a+x)/(c+x) - (b+x)/(c+x) has no x-root; must return [].
assert(isempty(ast('(a+x)/(c+x) - (b+x)/(c+x)').isolate('x')), 'x-free cleared residual must not isolate');

% No-op detection: a polynomial residual comes back unchanged (up to canonicalisation).
r = ast('a*x + b');
assert(ast.ast_equal(r.clear_denominators(), r.canonicalise()), 'denominator-free residual must be a no-op');

% linearise_system through denominators: rational-linear 2x2 solves via Cramer.
r1 = ast('x/(1+y) - a');
r2 = ast('(x+y)/(2+y) - b');
[ok, A, b_] = ast.linearise_system({r1, r2}, {'x', 'y'});
assert(ok, 'linearise_system must clear denominators before giving up');
sol = ast.solve_linear_system(A, b_);
v = struct('a', 2, 'b', 1.5);
xs = sol{1}.eval(v);
ys = sol{2}.eval(v);
assert(abs(xs/(1+ys) - v.a) < tol && abs((xs+ys)/(2+ys) - v.b) < tol, 'Cramer solution must satisfy the rational system');

fprintf('ast/t34: rational normalisation (clear_denominators) in isolate and linearise_system\n');
