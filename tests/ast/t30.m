% ast.isolate: the monomial recogniser inverts a power whose BASE is a compound
% expression carrying the variable (extract_monomial recurses through '^'):
% (base)^E is a monomial in x when base = cb*x^db, since (cb*x^db)^E = cb^E*x^(db*E).
% This closes the self-referential price indexation block (NOPG/InflationFactor)^E - 1.

% (a/x)^E - c = 0  ->  x = a * c^(-1/E). Check numerically with a=2, E=3, c=8 -> x=1.
r = ast('(a/x)^E - c').isolate('x');
assert(~isempty(r), 'isolate must invert a power of a compound base');
val = r.eval(struct('a', 2, 'E', 3, 'c', 8));
assert(abs(val - 1) < 1e-12, 'expected x=1 for (2/x)^3=8, got %g', val);

% Verify the residual actually vanishes at the isolated value (general check).
res = ast('(a/x)^E - c');
vals = struct('a', 2, 'E', 3, 'c', 8, 'x', val);
assert(abs(res.eval(vals)) < 1e-12, 'isolated x must zero the residual');

% (NOPG/IF)^E - 1 = 0  ->  IF = NOPG (the SW inflation-indexation pattern).
r2 = ast('(NOPG/IF)^E - 1').isolate('IF');
assert(~isempty(r2), 'isolate must handle (NOPG/IF)^E - 1');
v2 = r2.eval(struct('NOPG', 1.005, 'E', 0.7));
assert(abs(v2 - 1.005) < 1e-12, 'expected IF = NOPG = 1.005, got %g', v2);

fprintf('ast/t30: isolate inverts a power of a compound base (monomial recurses through ^)\n');
