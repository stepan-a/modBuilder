addpath ../utils

% Test subs method: implicit loop with indexed equations (Cartesian product with warnings)

% Build model with indexed equations and parameters
m = modBuilder();
m.add('Y_FR', 'Y_FR = alpha_FR*K_FR');
m.add('Y_DE', 'Y_DE = alpha_DE*K_DE');
m.parameter('alpha_$1', 0.5, {'FR', 'DE'});
m.exogenous('K_$1', 1.0, {'FR', 'DE'});

% Substitute alpha_$1 with beta_$1 in equations Y_$1
% This creates a Cartesian product: tries all combinations
% Warnings are issued for non-existent combinations (e.g., alpha_DE in Y_FR)
Countries = {'FR', 'DE'};
m.subs('alpha_$1', 'beta_$1', 'Y_$1', Countries);

% Verify substitution in Y_FR
expected_eq_FR = 'Y_FR = beta_FR*K_FR';
if ~strcmp(m{'Y_FR'}.equations{2}, expected_eq_FR)
    error('Substitution failed in Y_FR: expected "%s", got "%s"', expected_eq_FR, m{'Y_FR'}.equations{2})
end

% Verify substitution in Y_DE
expected_eq_DE = 'Y_DE = beta_DE*K_DE';
if ~strcmp(m{'Y_DE'}.equations{2}, expected_eq_DE)
    error('Substitution failed in Y_DE: expected "%s", got "%s"', expected_eq_DE, m{'Y_DE'}.equations{2})
end

% Check that beta symbols are now parameters (rename was used)
if ~m.isparameter('beta_FR')
    error('Symbol beta_FR should be a parameter after substitution')
end
if ~m.isparameter('beta_DE')
    error('Symbol beta_DE should be a parameter after substitution')
end

% Check that alpha symbols no longer exist
if m.issymbol('alpha_FR')
    error('Symbol alpha_FR should no longer exist after substitution')
end
if m.issymbol('alpha_DE')
    error('Symbol alpha_DE should no longer exist after substitution')
end

fprintf('t05.m: All tests passed (with warnings for non-matching patterns)\n');
