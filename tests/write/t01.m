% Test write method options (initval, steady, check)

addpath ../utils

% Create a simple model
m = modBuilder();
m.add('y', 'y = alpha*x + beta');
m.parameter('alpha', 1/3);
m.parameter('beta', pi);
m.exogenous('x', 0);
m.endogenous('y', 1/7);

% Test that filename without .mod extension still works
m.write('t01_noext');
assert(exist('t01_noext.mod', 'file') == 2, 'File without .mod extension should work');
delete t01_noext.mod

% Test initval with steady
m.write('t01_steady.mod', initval=true, steady=true);
b = modiff('t01_steady.mod', 't01_steady.true.mod');
if ~b
    error('Steady test failed.')
end
delete t01_steady.mod

% Test initval with steady and check
m.write('t01_steady_check.mod', initval=true, steady=true, check=true);
b = modiff('t01_steady_check.mod', 't01_steady_check.true.mod');
if ~b
    error('Steady+check test failed.')
end
delete t01_steady_check.mod

% Test check without steady throws an error
try
    m.write('t01_error.mod', check=true);
    error('Should have thrown an error.')
catch e
    if ~contains(e.message, 'steady')
        rethrow(e)
    end
end

% Test steady without initval issues a warning
warning('error', 'modBuilder:steadyWithoutInitval');
try
    m.write('t01_warn.mod', steady=true);
    error('Should have thrown a warning-as-error.')
catch e
    if ~strcmp(e.identifier, 'modBuilder:steadyWithoutInitval')
        rethrow(e)
    end
end
warning('on', 'modBuilder:steadyWithoutInitval');
if exist('t01_warn.mod', 'file')
    delete t01_warn.mod
end

fprintf('write/t01.m: All tests passed\n');
