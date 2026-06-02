% modBuilder.partial — symbolic partial derivative of an equation's static residual

m = modBuilder();
m.add('y', 'y = alpha*k(-1) + e');

% Linear partials give clean closed forms. The residual is y - (alpha*k + e),
% staticised, so the lag k(-1) collapses to k.
assert(ast.ast_equal(m.partial('y', 'y'),     ast('1')),                  'd resid_y / dy = 1');
assert(ast.ast_equal(m.partial('y', 'k'),     ast('-alpha').simplify()),  'd resid_y / dk = -alpha (lag aggregated)');
assert(ast.ast_equal(m.partial('y', 'e'),     ast('-1').simplify()),      'd resid_y / de = -1');
assert(ast.ast_equal(m.partial('y', 'alpha'), ast('-k').simplify()),      'd resid_y / dalpha = -k (staticised)');

% A symbol absent from the equation has a zero partial.
assert(ast.ast_equal(m.partial('y', 'q'), ast('0')), 'partial w.r.t. an absent symbol is 0');

% Nonlinear equation: verify the partial numerically at a point.
m.add('Y', 'Y = exp(a)*K(-1)^alpha*H^(1-alpha)');
g = m.partial('Y', 'K');
vals = struct('Y', 1, 'a', 0.1, 'K', 2, 'alpha', 0.3, 'H', 1.5);
got = g.eval(vals);
expected = -exp(0.1)*0.3*2^(0.3-1)*1.5^(1-0.3);   % d/dK of -exp(a)*K^alpha*H^(1-alpha)
assert(abs(got - expected) < 1e-12, sprintf('nonlinear partial mismatch: %.12g vs %.12g', got, expected));

% Dynamic (period-specific) partials via the Lag option. K appears only as K(-1).
% Lag=-1 picks up that block; here it equals the static partial because there is no
% other occurrence of K, but it keeps the lag in the result.
gd = m.partial('Y', 'K', 'Lag', -1);
% eval resolves the tsym K(-1) to vals.K (lag ignored at evaluation, as in ast.eval).
assert(abs(gd.eval(vals) - expected) < 1e-12, 'Lag=-1 partial should match the K(-1) derivative');
assert(ast.ast_equal(m.partial('Y', 'K', 'Lag', 0), ast('0')),  'no contemporaneous K -> Lag=0 partial is 0');
assert(ast.ast_equal(m.partial('Y', 'Y', 'Lag', 0), ast('1')),  'Y is contemporaneous -> Lag=0 partial is 1');

% Linear equation: the static partial sums lags; the period-specific blocks separate them.
assert(ast.ast_equal(m.partial('y', 'k'),            ast('-alpha').simplify()), 'static d/dk = -alpha');
assert(ast.ast_equal(m.partial('y', 'k', 'Lag', -1), ast('-alpha').simplify()), 'd/dk(-1) = -alpha');
assert(ast.ast_equal(m.partial('y', 'k', 'Lag', 0),  ast('0')),                 'no contemporaneous k -> d/dk(0) = 0');

% Unknown equation raises with the documented id.
threw = false;
try
    m.partial('nope', 'k');
catch err
    threw = true;
    assert(strcmp(err.identifier, 'modBuilder:partial:unknownEquation'), ...
           sprintf('expected modBuilder:partial:unknownEquation, got %s', err.identifier));
end
assert(threw, 'partial on an unknown equation should raise');

fprintf('partial/t01.m: modBuilder.partial OK\n');
