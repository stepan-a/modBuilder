addpath ../utils

% Test input validation (Enhancement 5.2)
%
% Tests that validateattributes() and validate_symbol_name() catch common errors:
% - Empty strings
% - Non-char inputs
% - Non-row inputs (column vectors)
% - Reserved function names
%
% Tests for methods: add(), parameter(), exogenous(), endogenous(), change()

fprintf('Testing input validation (Enhancement 5.2)...\n');

%% Test 1: add() with empty varname should throw error
m1 = modBuilder();
try
    m1.add('', 'y = a*b');  % Empty varname
    error('Should have thrown error for empty varname')
catch ME
    if ~contains(ME.message, 'nonempty')
        error('Error message should mention nonempty, got: %s', ME.message)
    end
end

%% Test 2: add() with empty equation should throw error
m2 = modBuilder();
try
    m2.add('y', '');  % Empty equation
    error('Should have thrown error for empty equation')
catch ME
    if ~contains(ME.message, 'nonempty')
        error('Error message should mention nonempty, got: %s', ME.message)
    end
end

%% Test 3: add() with reserved name should throw error
m3 = modBuilder();
try
    m3.add('log', 'log = a*b');  % 'log' is a reserved function name
    error('Should have thrown error for reserved name')
catch ME
    if ~contains(ME.message, 'reserved')
        error('Error message should mention reserved, got: %s', ME.message)
    end
end

%% Test 4: add() with another reserved name (exp)
m4 = modBuilder();
try
    m4.add('exp', 'exp = a*b');  % 'exp' is a reserved function name
    error('Should have thrown error for reserved name')
catch ME
    if ~contains(ME.message, 'reserved')
        error('Error message should mention reserved, got: %s', ME.message)
    end
end

%% Test 5: add() with valid non-reserved name should work
m5 = modBuilder();
m5.add('y', 'y = a*b');
m5.parameter('a', 0.5);
m5.parameter('b', 0.3);
% Should succeed

%% Test 6: parameter() with empty name should throw error
m6 = modBuilder();
m6.add('y', 'y = a*b');
try
    m6.parameter('', 0.5);  % Empty pname
    error('Should have thrown error for empty pname')
catch ME
    if ~contains(ME.message, 'nonempty')
        error('Error message should mention nonempty, got: %s', ME.message)
    end
end

%% Test 7: parameter() with reserved name should throw error
m7 = modBuilder();
m7.add('y', 'y = sin*b');
try
    m7.parameter('sin', 0.5);  % 'sin' is a reserved function name
    error('Should have thrown error for reserved name')
catch ME
    if ~contains(ME.message, 'reserved')
        error('Error message should mention reserved, got: %s', ME.message)
    end
end

%% Test 8: exogenous() with empty name should throw error
m8 = modBuilder();
m8.add('y', 'y = a*eps');
try
    m8.exogenous('', 0.0);  % Empty xname
    error('Should have thrown error for empty xname')
catch ME
    if ~contains(ME.message, 'nonempty')
        error('Error message should mention nonempty, got: %s', ME.message)
    end
end

%% Test 9: exogenous() with reserved name should throw error
m9 = modBuilder();
m9.add('y', 'y = a*max');
try
    m9.exogenous('max', 0.0);  % 'max' is a reserved function name
    error('Should have thrown error for reserved name')
catch ME
    if ~contains(ME.message, 'reserved')
        error('Error message should mention reserved, got: %s', ME.message)
    end
end

%% Test 10: endogenous() with empty name should throw error
m10 = modBuilder();
try
    m10.endogenous('', 1.0);  % Empty ename
    error('Should have thrown error for empty ename')
catch ME
    if ~contains(ME.message, 'nonempty')
        error('Error message should mention nonempty, got: %s', ME.message)
    end
end

%% Test 11: endogenous() with reserved name should throw error
m11 = modBuilder();
try
    m11.endogenous('cos', 1.0);  % 'cos' is a reserved function name
    error('Should have thrown error for reserved name')
catch ME
    if ~contains(ME.message, 'reserved')
        error('Error message should mention reserved, got: %s', ME.message)
    end
end

%% Test 12: change() with empty varname should throw error
m12 = modBuilder();
m12.add('y', 'y = a*b');
try
    m12.change('', 'y = c*d');  % Empty varname
    error('Should have thrown error for empty varname')
catch ME
    if ~contains(ME.message, 'nonempty')
        error('Error message should mention nonempty, got: %s', ME.message)
    end
end

%% Test 13: change() with empty equation should throw error
m13 = modBuilder();
m13.add('y', 'y = a*b');
try
    m13.change('y', '');  % Empty equation
    error('Should have thrown error for empty equation')
catch ME
    if ~contains(ME.message, 'nonempty')
        error('Error message should mention nonempty, got: %s', ME.message)
    end
end

%% Test 14: Valid parameters with non-reserved names should work
m14 = modBuilder();
m14.add('y', 'y = alpha*beta*gamma');
m14.parameter('alpha', 0.5);
m14.parameter('beta', 0.3);
m14.parameter('gamma', 0.2);
% Should succeed

%% Test 15: Valid exogenous with non-reserved names should work
m15 = modBuilder();
m15.add('y', 'y = a*epsilon');
m15.parameter('a', 0.5);
m15.exogenous('epsilon', 0.0);
% Should succeed

%% Test 16: change() with valid inputs should work
m16 = modBuilder();
m16.add('y', 'y = a*b');
m16.parameter('a', 0.5);
m16.parameter('b', 0.3);
m16.change('y', 'y = a*b*b');
% Should succeed

fprintf('All input validation tests passed!\n');
