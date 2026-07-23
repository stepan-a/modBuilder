% iterated_elimination: RATIO-PRIORITY of the greedy selection. An equation whose
% closed form is a MONOMIAL in the remaining unknowns (it identifies a ratio, like
% an Euler condition pinning k proportional to h) must be consumed before a
% structure-destroying substitution reaches it: without the priority, the greedy
% picks c = k + h first (highest gain) and buries the system in (k+h)^(-s), where
% no recogniser -- expansion included -- can dig it out.

addpath ../utils

r1 = ast('c^(-s) - b*c^(-s)*k^(a-1)*h^(1-a)').staticise().simplify();   % pins k/h (c factors out)
r2 = ast('k + h - c').staticise().simplify();                            % aggregate constraint
r3 = ast('c*h^p - w').staticise().simplify();                            % pins h against c

[cf, rem] = ast.iterated_elimination({r1, r2, r3}, {'k', 'c', 'h'}, {'a', 'b', 's', 'p', 'w'});

% With the ratio picks consumed first (and every (equation, unknown) pair probed,
% not just the caller's pairing), the whole system closes analytically: the ratio
% substitutions keep the aggregate constraint a two-power binomial instead of a
% buried (k+h)^(-s).
assert(numel(cf) == 3, sprintf('the system must close fully, got %d closures', numel(cf)));
assert(isempty(rem.vars), 'no unknown must remain open');

% The closed forms, evaluated in the returned order, must solve all three equations.
vals = struct('a', 0.3, 'b', 0.9, 's', 2, 'p', 1.5, 'w', 1.2);
for j = 1:numel(cf)
    vals.(cf(j).var) = cf(j).expr.eval(vals);
end
assert(abs(r1.eval(vals)) < 1e-9, 'the Euler-like equation must hold at the closed forms');
assert(abs(r2.eval(vals)) < 1e-9, 'the aggregate constraint must hold at the closed forms');
assert(abs(r3.eval(vals)) < 1e-9, 'the labour-like equation must hold at the closed forms');

% monomial_in_vars draws the line correctly.
assert( ast.monomial_in_vars(ast('rho*h^2/c').simplify(), {'h', 'c'}), 'a power quotient is a monomial in {h, c}');
assert(~ast.monomial_in_vars(ast('h + c').simplify(), {'h', 'c'}),     'a sum is not a monomial');
assert(~ast.monomial_in_vars(ast('exp(h)*c').simplify(), {'h', 'c'}),  'a call bearing an unknown is not a monomial');
assert(~ast.monomial_in_vars(ast('c^h').simplify(), {'h', 'c'}),       'an unknown in an exponent is not a monomial');

fprintf('t36.m: ratio-priority elimination consumes ratio-identifying equations first OK\n');
