% Test examples from substitute method documentation

addpath ../utils

% Example 1: Simple regex substitution (backward compatible)
m = modBuilder();
m.add('Y', 'Y = alpha*K + beta*L');
m.parameter('alpha', 0.33);
m.parameter('beta', 0.67);
m.exogenous('K', 1.0);
m.exogenous('L', 1.0);

m.substitute('alpha', 'gamma', 'Y');

if ~strcmp(m{'Y'}.equations{2}, 'Y = gamma*K + beta*L')
    error('Example 1 failed: simple regex substitution')
end

fprintf('Example 1 passed: Simple regex substitution\n');

% Example 2: Implicit loop - substitute in all equations using regex
m2 = modBuilder();
m2.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2 + alpha_3*K_3');
m2.parameter('alpha_$1', 0.3, {1, 2, 3});
m2.exogenous('K_$1', 1.0, {1, 2, 3});

m2.substitute('alpha_$1', 'beta_$1', {1, 2, 3});

expected = 'Y = beta_1*K_1 + beta_2*K_2 + beta_3*K_3';
if ~strcmp(m2{'Y'}.equations{2}, expected)
    error('Example 2 failed: implicit loop in all equations')
end

fprintf('Example 2 passed: Implicit loop - substitute in all equations\n');

% Example 3: Implicit loop - substitute in specific equation using regex
m3 = modBuilder();
m3.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2');
m3.add('C', 'C = alpha_1*Y');
m3.parameter('alpha_$1', 0.5, {1, 2});
m3.exogenous('K_$1', 1.0, {1, 2});

m3.substitute('alpha_$1', 'beta_$1', 'Y', {1, 2});

if ~strcmp(m3{'Y'}.equations{2}, 'Y = beta_1*K_1 + beta_2*K_2')
    error('Example 3 failed: Y equation')
end
if ~strcmp(m3{'C'}.equations{2}, 'C = alpha_1*Y')
    error('Example 3 failed: C equation should be unchanged')
end

fprintf('Example 3 passed: Implicit loop - substitute in specific equation\n');

% Example 4: Implicit loop with explicit equation name using regex
m4 = modBuilder();
m4.add('Y', 'Y = alpha_1*K_1 + alpha_2*K_2');
m4.add('C', 'C = beta*Y');
m4.parameter('alpha_$1', 0.5, {1, 2});
m4.parameter('beta', 0.3);
m4.exogenous('K_$1', 1.0, {1, 2});

m4.substitute('alpha_$1', 'gamma_$1', 'Y', {1, 2});

if ~strcmp(m4{'Y'}.equations{2}, 'Y = gamma_1*K_1 + gamma_2*K_2')
    error('Example 4 failed: Y equation')
end
if ~strcmp(m4{'C'}.equations{2}, 'C = beta*Y')
    error('Example 4 failed: C equation should be unchanged')
end

fprintf('Example 4 passed: Implicit loop with explicit equation name\n');

fprintf('substitute.m: All tests passed\n');
