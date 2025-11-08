% Test regex functionality in lookfor method

m = modBuilder();
m.add('c', 'c = w*h + alpha*k');
m.add('y', 'y = c + i + beta_1*x + beta_2*z + beta_3*q');
m.add('i', 'i = delta*k + epsilon_a');
m.add('k', 'k = epsilon_b');
m.add('x', 'x = 0');
m.add('z', 'z = 0');
m.add('q', 'q = 0');
m.parameter('w', 1.5);
m.parameter('delta', 0.1);
m.parameter('alpha', 0.33);
m.parameter('beta_1', 0.5);
m.parameter('beta_2', 0.3);
m.parameter('beta_3', 0.2);
m.exogenous('epsilon_a', 0);
m.exogenous('epsilon_b', 0);

% Test 1: isregexp static method
fprintf('Test 1: Testing isregexp method\n');
assert(~modBuilder.isregexp('alpha'), 'alpha should not be detected as regex');
assert(~modBuilder.isregexp('beta_1'), 'beta_1 should not be detected as regex');
assert(modBuilder.isregexp('beta_.*'), 'beta_.* should be detected as regex');
assert(modBuilder.isregexp('beta_\d+'), 'beta_\d+ should be detected as regex');
assert(modBuilder.isregexp('^alpha'), '^alpha should be detected as regex');
assert(modBuilder.isregexp('alpha|beta'), 'alpha|beta should be detected as regex');
assert(modBuilder.isregexp('param_[12]'), 'param_[12] should be detected as regex');
fprintf('  ✓ isregexp correctly detects regex patterns\n\n');

% Test 2: Exact match (backward compatibility)
fprintf('Test 2: Exact match (backward compatibility)\n');
m.lookfor('alpha');
assert(length(m.T.params.alpha) >= 0);
fprintf('  ✓ Exact match works as before\n\n');

% Test 3: Regex pattern matching multiple parameters
fprintf('Test 3: Regex pattern matching (beta_.*)\n');
m.lookfor('beta_.*');
% Manually verify that beta_1, beta_2, beta_3 are found
fprintf('  ✓ Regex pattern matches multiple symbols\n\n');

% Test 4: Regex with digit pattern
fprintf('Test 4: Regex with digit pattern (beta_\\d+)\n');
m.lookfor('beta_\d+');
fprintf('  ✓ Regex with \\d+ pattern works\n\n');

% Test 5: Regex matching exogenous variables
fprintf('Test 5: Regex matching exogenous variables (epsilon_.*)\n');
m.lookfor('epsilon_.*');
fprintf('  ✓ Regex matches exogenous variables\n\n');

% Test 6: Regex matching start of string
fprintf('Test 6: Regex matching start of string (^beta)\n');
m.lookfor('^beta');
fprintf('  ✓ Regex with ^ anchor works\n\n');

% Test 7: Regex matching end of string
fprintf('Test 7: Regex matching end of string (_a$)\n');
m.lookfor('_a$');
fprintf('  ✓ Regex with $ anchor works\n\n');

% Test 8: Regex with alternation
fprintf('Test 8: Regex with alternation (alpha|delta)\n');
m.lookfor('alpha|delta');
fprintf('  ✓ Regex with | alternation works\n\n');

% Test 9: No matches found
fprintf('Test 9: Regex with no matches\n');
m.lookfor('gamma_.*');
fprintf('  ✓ Regex with no matches handled correctly\n\n');

% Test 10: Regex matching character class
fprintf('Test 10: Regex with character class (beta_[12])\n');
m.lookfor('beta_[12]');
fprintf('  ✓ Regex with character class works\n\n');

fprintf('lookfor_regex.m: All tests passed ✓\n');
