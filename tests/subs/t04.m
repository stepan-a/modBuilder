addpath ../utils

% Test subs method: implicit loop with explicit equation names

% Build model with multiple equations
m = modBuilder();
m.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2');
m.add('C', 'C = beta*Y');
m.parameter('alpha_$1', 0.5, {1, 2});
m.parameter('beta', 0.3);
m.exogenous('K_$1', 1.0, {1, 2});

% Substitute alpha_$1 with gamma_$1 in equation Y (not in C)
m.subs('alpha_$1', 'gamma_$1', 'Y', {1, 2});

% Verify substitution in Y
expected_eq = 'Y = gamma_1*K_1 + gamma_2*K_2';
if ~strcmp(m{'Y'}.equations{2}, expected_eq)
    error('Substitution failed in Y: expected "%s", got "%s"', expected_eq, m{'Y'}.equations{2})
end

% Verify C equation unchanged
expected_eq_C = 'C = beta*Y';
if ~strcmp(m{'C'}.equations{2}, expected_eq_C)
    error('Equation C should be unchanged: expected "%s", got "%s"', expected_eq_C, m{'C'}.equations{2})
end

% Check that gamma symbols are now parameters (rename was used)
if ~m.isparameter('gamma_1')
    error('Symbol gamma_1 should be a parameter after substitution')
end
if ~m.isparameter('gamma_2')
    error('Symbol gamma_2 should be a parameter after substitution')
end

% Check that alpha symbols no longer exist
if m.issymbol('alpha_1')
    error('Symbol alpha_1 should no longer exist after substitution')
end

fprintf('t04.m: All tests passed\n');
