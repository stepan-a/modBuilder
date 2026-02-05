% Test precision option for write method

addpath ../utils

% Create a simple model with parameters that need high precision
m = modBuilder();
m.add('y', 'y = alpha*x + beta');
m.parameter('alpha', 1/3);  % Repeating decimal
m.parameter('beta', pi);    % Irrational number
m.exogenous('x', 0);

% Test default precision (6 decimal places with %f format)
m.write('precision_default.mod');
b = modiff('precision_default.mod', 'precision_default.true.mod');
if ~b
    error('Default precision test failed.')
end
delete precision_default.mod

% Test high precision (15 significant digits)
m.write('precision_high.mod', precision=15);
b = modiff('precision_high.mod', 'precision_high.true.mod');
if ~b
    error('High precision test failed.')
end
delete precision_high.mod

% Test precision with initval
m.endogenous('y', 1/7);  % Set initial value
m.write('precision_initval.mod', initval=true, precision=10);
b = modiff('precision_initval.mod', 'precision_initval.true.mod');
if ~b
    error('Precision with initval test failed.')
end
delete precision_initval.mod

% Test that filename without .mod extension still works
m.write('precision_noext');
assert(exist('precision_noext.mod', 'file') == 2, 'File without .mod extension should work');
delete precision_noext.mod

% Test initval with steady
m.write('precision_steady.mod', initval=true, steady=true);
b = modiff('precision_steady.mod', 'precision_steady.true.mod');
if ~b
    error('Steady test failed.')
end
delete precision_steady.mod

% Test initval with steady and check
m.write('precision_steady_check.mod', initval=true, steady=true, check=true);
b = modiff('precision_steady_check.mod', 'precision_steady_check.true.mod');
if ~b
    error('Steady+check test failed.')
end
delete precision_steady_check.mod

% Test check without steady throws an error
try
    m.write('precision_error.mod', check=true);
    error('Should have thrown an error.')
catch e
    if ~contains(e.message, 'steady')
        rethrow(e)
    end
end

% Test steady without initval issues a warning
warning('error', 'modBuilder:steadyWithoutInitval');
try
    m.write('precision_warn.mod', steady=true);
    error('Should have thrown a warning-as-error.')
catch e
    if ~strcmp(e.identifier, 'modBuilder:steadyWithoutInitval')
        rethrow(e)
    end
end
warning('on', 'modBuilder:steadyWithoutInitval');
if exist('precision_warn.mod', 'file')
    delete precision_warn.mod
end

fprintf('precision/t01.m: All tests passed\n');
