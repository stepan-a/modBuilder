addpath ../utils

% Test substitute method: implicit loop - substitute in specific equation with regex

% Build model with multiple equations
m = modBuilder();
m.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2');
m.add('C', 'C = alpha_1*Y + alpha_2*L');
m.parameter('alpha_$1', 0.5, {1, 2});
m.exogenous('K_$1', 1.0, {1, 2});
m.exogenous('L', 1.0);

% Substitute alpha_$1 with beta_$1 in equation Y only using regex
m.substitute('alpha_$1', 'beta_$1', 'Y', {1, 2});

% Verify substitution in Y
expected_eq_Y = 'Y = beta_1*K_1 + beta_2*K_2';
if ~strcmp(m{'Y'}.equations{2}, expected_eq_Y)
    error('Substitution failed in Y: expected "%s", got "%s"', expected_eq_Y, m{'Y'}.equations{2})
end

% Verify C equation unchanged
expected_eq_C = 'C = alpha_1*Y + alpha_2*L';
if ~strcmp(m{'C'}.equations{2}, expected_eq_C)
    error('Equation C should be unchanged: expected "%s", got "%s"', expected_eq_C, m{'C'}.equations{2})
end

fprintf('t03.m: All tests passed\n');
