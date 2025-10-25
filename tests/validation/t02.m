addpath ../utils

% Test equation syntax validation for subs() and substitute() methods
%
% Tests that validate_equation_syntax() catches common errors in substitution results:
% - Unbalanced parentheses
% - Use of ==  instead of =
% - Use of ./ (element-wise division)

% Test 1: subs() creating unbalanced parentheses should throw error
m1 = modBuilder();
m1.add('y', 'y = a*x')
m1.parameter('a', 0.8)

try
    m1.subs('x', '(b + c', 'y')  % Creates: y = a*(b + c (unbalanced)
    error('Should have thrown error for unbalanced parentheses')
catch ME
    if ~contains(ME.message, 'unbalanced parentheses')
        error('Error message should mention unbalanced parentheses, got: %s', ME.message)
    end
end

% Test 2: subs() creating == should throw error
m2 = modBuilder();
m2.add('y', 'y = a*x')
m2.parameter('a', 0.8)

try
    m2.subs('=', '==', 'y')  % Creates: y == a*x
    error('Should have thrown error for ==')
catch ME
    if ~contains(ME.message, '==')
        error('Error message should mention ==, got: %s', ME.message)
    end
end

% Test 3: subs() creating ./ should throw error
m3 = modBuilder();
m3.add('y', 'y = a/b')
m3.parameter('a', 0.8)
m3.parameter('b', 0.5)

try
    m3.subs('/', './', 'y')  % Creates: y = a./b
    error('Should have thrown error for ./')
catch ME
    if ~contains(ME.message, './')
        error('Error message should mention ./, got: %s', ME.message)
    end
end

% Test 4: substitute() creating unbalanced parentheses should throw error
m4 = modBuilder();
m4.add('y', 'y = a*x')
m4.parameter('a', 0.8)

try
    m4.substitute('x', '(b + c', 'y')  % Creates: y = a*(b + c (unbalanced)
    error('Should have thrown error for unbalanced parentheses')
catch ME
    if ~contains(ME.message, 'unbalanced parentheses')
        error('Error message should mention unbalanced parentheses, got: %s', ME.message)
    end
end

% Test 5: substitute() creating == should throw error
m5 = modBuilder();
m5.add('y', 'y = a*x')
m5.parameter('a', 0.8)

try
    m5.substitute('=', '==', 'y')  % Creates: y == a*x
    error('Should have thrown error for ==')
catch ME
    if ~contains(ME.message, '==')
        error('Error message should mention ==, got: %s', ME.message)
    end
end

% Test 6: Valid subs() should work fine with balanced expression
m6 = modBuilder();
m6.add('y', 'y = a+b')
m6.parameter('a', 0.8)
m6.parameter('b', 0.2)

m6.subs('a+b', 'a*a + b*b', 'y')  % Creates: y = a*a + b*b - valid!

% Verify equation was modified
if ~contains(m6.equations{1,2}, 'a*a + b*b')
    error('Valid subs should have modified the equation')
end
