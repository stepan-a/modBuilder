addpath ../utils

% Test equation syntax validation
%
% Tests that validate_equation_syntax() catches common errors:
% - Unbalanced parentheses
% - Use of ==  instead of =
% - Use of ./ (element-wise division)

% Test 1: Unbalanced parentheses should throw error
m1 = modBuilder();
try
    m1.add('y', 'y = a*(b + c');  % Missing closing parenthesis
    error('Should have thrown error for unbalanced parentheses')
catch ME
    if ~contains(ME.message, 'unbalanced parentheses')
        error('Error message should mention unbalanced parentheses, got: %s', ME.message)
    end
end

% Test 2: Using == should throw error
m2 = modBuilder();
try
    m2.add('y', 'y == a*b');  % Using == instead of =
    error('Should have thrown error for ==')
catch ME
    if ~contains(ME.message, '==')
        error('Error message should mention ==, got: %s', ME.message)
    end
end

% Test 3: Using ./ should throw error
m3 = modBuilder();
try
    m3.add('y', 'y = a./b');  % Using element-wise division
    error('Should have thrown error for ./')
catch ME
    if ~contains(ME.message, './')
        error('Error message should mention ./, got: %s', ME.message)
    end
end

% Test 4: Valid equation should work fine
m4 = modBuilder();
m4.add('y', 'y = a*y(-1) + b/(c + d)')
m4.parameter('a', 0.8)
m4.parameter('b', 0.2)
m4.parameter('c', 1.0)
m4.parameter('d', 0.5)

% Verify equation was added
if size(m4.equations, 1) ~= 1
    error('Valid equation should have been added')
end

% Test 5: change() method should also validate
m5 = modBuilder();
m5.add('y', 'y = a*y(-1)')
m5.parameter('a', 0.8)

try
    m5.change('y', 'y == b*y(-1)')  % Using ==
    error('change() should have thrown error for ==')
catch ME
    if ~contains(ME.message, '==')
        error('Error message should mention ==, got: %s', ME.message)
    end
end

% Test 6: Static method can be called directly
try
    modBuilder.validate_equation_syntax('y = a*(b + c')  % Unbalanced
    error('Should have thrown error')
catch ME
    if ~contains(ME.message, 'unbalanced')
        error('Direct call should catch unbalanced parentheses')
    end
end
