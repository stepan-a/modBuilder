addpath ../utils

% inline: lag-aware substitution of a defining variable into other equations.
% Motivating Phillips-curve example: pi = beta*mc(-1) with mc = w/mpl should
% become pi = beta*(w(-1)/mpl(-1)) after inlining mc.

m = modBuilder();
m.add('pi', 'pi = beta * mc(-1)');
m.add('mc', 'mc = w / mpl');
m.exogenous('w', 1.0);
m.exogenous('mpl', 1.0);
m.parameter('beta', 0.99);

m.inline('mc', 'w / mpl');

% pi must reflect the lag-shifted replacement
got = m{'pi'}.equations{2};
LHSRHS = strsplit(got, '=');
got_rhs = ast(strtrim(LHSRHS{2}));
expected_rhs = ast('beta * (w(-1) / mpl(-1))');
if not(ast.ast_equal(got_rhs, expected_rhs))
    error('inline: lag-aware substitution failed. expected "%s", got "%s"', expected_rhs.string(), got_rhs.string())
end

% mc's own equation became a tautology w/mpl = w/mpl. The user is responsible
% for removing it explicitly; here we just check mc is still listed as endogenous.
if not(m.isendogenous('mc'))
    error('mc should still be endogenous (defining equation kept)')
end

fprintf('t02.m: All tests passed\n');
