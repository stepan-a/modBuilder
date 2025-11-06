addpath ../utils

% Test subs method: implicit loop - substitute in all equations

% Build model with indexed parameters
m = modBuilder();
m.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2 + alpha_3*K_3');
m.parameter('alpha_$1', 0.3, {1, 2, 3});
m.exogenous('K_$1', 1.0, {1, 2, 3});

% Substitute alpha_$1 with beta_$1 in all equations using implicit loop
m.subs('alpha_$1', 'beta_$1', {1, 2, 3});

% Verify substitution occurred
expected_eq = 'Y = beta_1*K_1 + beta_2*K_2 + beta_3*K_3';
if ~strcmp(m{'Y'}.equations{2}, expected_eq)
    error('Substitution failed: expected "%s", got "%s"', expected_eq, m{'Y'}.equations{2})
end

% Check that beta symbols are now parameters (rename was used)
if ~m.isparameter('beta_1')
    error('Symbol beta_1 should be a parameter after substitution')
end
if ~m.isparameter('beta_2')
    error('Symbol beta_2 should be a parameter after substitution')
end
if ~m.isparameter('beta_3')
    error('Symbol beta_3 should be a parameter after substitution')
end

% Check that alpha symbols no longer exist
if m.issymbol('alpha_1')
    error('Symbol alpha_1 should no longer exist after substitution')
end

fprintf('t02.m: All tests passed\n');
