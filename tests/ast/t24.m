% ast.diff_ast — symbolic differentiation (structural cases + autoDiff1 cross-check)

% ---------------------------------------------------------------------------
% Structural checks: simple node types and the algebraic (binop) rules.
% diff_ast already simplifies, so compare against the simplified expected tree.
% ---------------------------------------------------------------------------
assert(ast.ast_equal(ast('x').diff_ast('x'), ast('1')),                'd(x)/dx = 1');
assert(ast.ast_equal(ast('x').diff_ast('y'), ast('0')),                'd(x)/dy = 0');
assert(ast.ast_equal(ast('3.5').diff_ast('x'), ast('0')),              'd(const)/dx = 0');
assert(ast.ast_equal(ast('-x').diff_ast('x'), ast('-1').simplify()),   'd(-x)/dx = -1');

% Period-specific: a lead/lag and a steady-state node are independent of x.
assert(ast.ast_equal(ast('K(-1)').diff_ast('K'), ast('0')),            'd(K(-1))/dK = 0');
assert(ast.ast_equal(ast('K(+1)').diff_ast('K'), ast('0')),            'd(K(+1))/dK = 0');
assert(ast.ast_equal(ast('STEADY_STATE(K)').diff_ast('K'), ast('0')),  'd(STEADY_STATE(K))/dK = 0');

% Binops.
assert(ast.ast_equal(ast('a*x').diff_ast('x'), ast('a').simplify()),       'd(a*x)/dx = a');
assert(ast.ast_equal(ast('x^2').diff_ast('x'), ast('2*x').simplify()),     'd(x^2)/dx = 2*x');
assert(ast.ast_equal(ast('x^3').diff_ast('x'), ast('3*x^2').simplify()),   'd(x^3)/dx = 3*x^2');
assert(ast.ast_equal(ast('1/x').diff_ast('x'), ast('-1/x^2').simplify()),  'd(1/x)/dx = -1/x^2');

% Higher-order via chaining.
assert(ast.ast_equal(ast('x^3').diff_ast('x').diff_ast('x'), ast('6*x').simplify()), 'd2(x^3)/dx2 = 6*x');

% cbrt has only an autoDiff1 overload (no plain-double implementation), so it is
% checked structurally rather than through the numeric oracle below.
assert(ast.ast_equal(ast('cbrt(x)').diff_ast('x'), ast('1/(3*cbrt(x)^2)').simplify()), 'd(cbrt(x))/dx = 1/(3*cbrt(x)^2)');

% abs and sign follow the autoDiff1 conventions: abs(u)' = sign(u)*u', sign(u)' = 0.
assert(ast.ast_equal(ast('abs(x)').diff_ast('x'), ast('sign(x)').simplify()),  'd(abs(x))/dx = sign(x)');
assert(ast.ast_equal(ast('sign(x)').diff_ast('x'), ast('0')),                  'd(sign(x))/dx = 0');
assert(ast.ast_equal(ast('sign(x*y)').diff_ast('x'), ast('0')),                'd(sign(x*y))/dx = 0');

% ---------------------------------------------------------------------------
% autoDiff1 cross-check: for each (expression, target) evaluate the analytical
% derivative and the dual-number derivative at several points; they must agree.
% This is the strong test — it exercises every rule against an independent oracle.
% ---------------------------------------------------------------------------
pts = [0.3 0.7 1.4; 0.5 1.1 0.9; 1.2 0.4 2.1; 0.8 1.6 0.6];   % rows = (x, y, z) points

cases = {
    % expression                              target
    'x + y',                                  'x'
    'x - y',                                  'y'
    '3*x*y',                                  'x'
    'x/y',                                    'x'
    'x/y',                                    'y'
    'x^2 + 3*x*y + y^2',                      'x'
    'x^y',                                    'x'      % exponent depends on target (general)
    'y^x',                                    'x'      % base constant w.r.t. target
    'x^x',                                    'x'      % both depend on target
    'log(x)',                                 'x'
    'ln(x*y)',                                'x'
    'log10(x)',                               'x'
    'exp(x*y)',                               'y'
    'sqrt(x + y)',                            'x'
    'sin(x)*cos(y)',                          'x'
    'sin(x)*cos(y)',                          'y'
    'tan(x)',                                 'x'
    'asin(x/2)',                              'x'
    'acos(x/2)',                              'x'
    'atan(x*y)',                              'y'
    'sinh(x)',                                'x'
    'cosh(x)',                                'x'
    'tanh(x*y)',                              'x'
    'asinh(x)',                               'x'
    'acosh(x + 1)',                           'x'      % argument > 1 on the grid
    'atanh(x/3)',                             'x'
    'erf(x)',                                 'x'
    'abs(x - 1)',                             'x'      % sign-varying argument (nonzero on the grid)
    'x*abs(x - 1)',                           'x'      % product rule through abs
    'max(x, y)',                              'x'      % min/max via the abs identity; grid has no ties
    'min(x, y)',                              'y'
    'max(x*y, 1)',                            'x'
    'exp(-x^2)*sin(y) + log(x*y)/sqrt(z)',    'x'      % composite
    };

for k = 1:size(cases, 1)
    expr = cases{k, 1};
    tgt  = cases{k, 2};
    g = ast(expr).diff_ast(tgt);
    for r = 1:size(pts, 1)
        pt = struct('x', pts(r, 1), 'y', pts(r, 2), 'z', pts(r, 3));
        analytic = g.eval(pt);
        oracle = adcheck(expr, tgt, pt);
        assert(abs(analytic - oracle) < 1e-9, ...
               sprintf('diff_ast mismatch for d(%s)/d%s at point %d: analytic=%.12g, AD=%.12g', ...
                       expr, tgt, r, analytic, oracle));
    end
end

% ---------------------------------------------------------------------------
% normcdf / normpdf: autoDiff1 has no rule for these, so cross-check against a
% central finite difference of the original expression instead.
% ---------------------------------------------------------------------------
fd_cases = {'normcdf(x)', 'x'; 'normpdf(x*y)', 'x'; 'normpdf(x)', 'x'};
h = 1e-6;
for k = 1:size(fd_cases, 1)
    expr = fd_cases{k, 1};
    tgt  = fd_cases{k, 2};
    g = ast(expr).diff_ast(tgt);
    for r = 1:size(pts, 1)
        pt = struct('x', pts(r, 1), 'y', pts(r, 2), 'z', pts(r, 3));
        pp = pt; pp.(tgt) = pt.(tgt) + h;
        pm = pt; pm.(tgt) = pt.(tgt) - h;
        fd = (ast(expr).eval(pp) - ast(expr).eval(pm)) / (2*h);
        analytic = g.eval(pt);
        assert(abs(analytic - fd) < 1e-6, ...
               sprintf('diff_ast/FD mismatch for d(%s)/d%s at point %d: analytic=%.12g, FD=%.12g', ...
                       expr, tgt, r, analytic, fd));
    end
end

fprintf('t24.m: ast.diff_ast OK\n');

% Local AD oracle: evaluate the expression with target wrapped as a dual number
% (derivative 1) and every other symbol as a constant dual (derivative 0).
function d = adcheck(expr, tgt, pt)
    names = fieldnames(pt);
    advals = struct();
    for i = 1:numel(names)
        nm = names{i};
        advals.(nm) = autoDiff1(pt.(nm), double(strcmp(nm, tgt)));
    end
    result = ast(expr).eval(advals);
    d = result.dx;
end
