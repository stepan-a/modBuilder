% ast.single_fraction and ast.complexity: rewriting a sum of fractions as one quotient, and
% scoring algebraically equal forms by how they RENDER, so a caller can pick between them.

m = struct('alpha', '\alpha', 'beta', '\beta', 'delta', '\delta', 'psi', '\psi');

% --- single_fraction: value-preserving rational normalisation -----------------------------
e  = ast('1/(alpha*beta*delta) - 1 - 1/(alpha*delta) + 1/alpha').simplify();
sf = e.single_fraction();
v  = struct('alpha', 0.36, 'beta', 0.99, 'delta', 0.025);
assert(abs(e.eval(v) - sf.eval(v)) < 1e-12, 'single_fraction preserves the value');
assert(strcmp(sf.to_latex(m), '\frac{1 - \beta - \alpha\,\beta\,\delta + \beta\,\delta}{\alpha\,\beta\,\delta}'), ...
       'sum of fractions becomes one quotient');

% A nested quotient flattens onto a single denominator.
n2 = ast('(delta - 1 + 1/beta)/(alpha*delta)').simplify().single_fraction();
assert(strcmp(n2.to_latex(m), '\frac{1 - \beta + \beta\,\delta}{\alpha\,\beta\,\delta}'), 'nested quotient flattened');

% With no denominator it is a no-op (up to canonicalisation).
p = ast('a + b*c').simplify();
assert(ast.ast_equal(p.single_fraction(), p), 'no denominator: unchanged');

% --- complexity: the single fraction wins, though it has MORE nodes ------------------------
assert(ast.node_count(sf) > ast.node_count(e), 'the single fraction is the bigger tree');
assert(ast.complexity(sf, m) < ast.complexity(e, m), 'yet it is the simpler rendering');

% Flat beats nested at equal content.
assert(ast.complexity(ast('x/(a*b)')) < ast.complexity(ast('x/a/b')), 'one denominator beats two');

% A control sequence counts as ONE glyph: the score must not depend on how a symbol is named.
assert(ast.complexity(ast('a+b'), struct('a', '\alpha', 'b', '\beta')) == ast.complexity(ast('a+b')), ...
       'naming does not change the score');

% --- fraction_stats models the renderer, not the tree -------------------------------------
% Canonical form stores 1/(a*b*c) as a product of three inverse powers, but ONE \frac is
% emitted, at depth one.
q = ast('x/(a*b*c)').simplify();
[nfrac, dfrac] = ast.fraction_stats(q);
assert(nfrac == 1, 'gathered inverse factors count as one fraction');
assert(dfrac == 1, 'and as a single level of nesting');
assert(numel(strfind(q.to_latex(), '\frac')) == nfrac, 'count matches the rendering');

[nfrac2, dfrac2] = ast.fraction_stats(ast('(a/b)/(c/d)'));
assert(dfrac2 == 2, 'a quotient of quotients nests');
assert(nfrac2 == 3, 'and emits three \frac');

fprintf('t38.m: ast.single_fraction / ast.complexity OK\n');
