% Test that reserved names are properly rejected
addpath src

model = modBuilder();

fprintf('Testing reserved name validation:\n\n');

% Test 1: Built-in function name
fprintf('1. Trying to use "log" (built-in function):\n');
try
    model.parameter('log', 0.5);
    fprintf('   ERROR: Should have been rejected!\n');
catch e
    fprintf('   PASS: %s\n', e.message);
end

% Test 2: Method name
fprintf('\n2. Trying to use "add" (method name):\n');
try
    model.parameter('add', 0.5);
    fprintf('   ERROR: Should have been rejected!\n');
catch e
    fprintf('   PASS: %s\n', e.message);
end

% Test 3: Property name
fprintf('\n3. Trying to use "params" (property name):\n');
try
    model.parameter('params', 0.5);
    fprintf('   ERROR: Should have been rejected!\n');
catch e
    fprintf('   PASS: %s\n', e.message);
end

% Test 4: Another method name
fprintf('\n4. Trying to use "copy" (method name):\n');
try
    model.parameter('copy', 0.5);
    fprintf('   ERROR: Should have been rejected!\n');
catch e
    fprintf('   PASS: %s\n', e.message);
end

% Test 5: Valid name should work
fprintf('\n5. Trying to use "alpha" (valid name):\n');
try
    model.add('y', 'y = alpha*k');
    model.parameter('alpha', 0.36);
    fprintf('   PASS: Accepted as expected (alpha = %.2f)\n', model.alpha);
catch e
    fprintf('   ERROR: %s\n', e.message);
end

fprintf('\nAll tests completed!\n');
