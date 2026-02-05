% Test steady_options for write method

addpath ../utils

% Create a simple model
m = modBuilder();
m.add('y', 'y = alpha*x + beta');
m.parameter('alpha', 1/3);
m.parameter('beta', pi);
m.exogenous('x', 0);
m.endogenous('y', 1/7);

% Test steady with options (key-value)
m.write('t01_steady_opts.mod', initval=true, steady=true, steady_options={'maxit', 100});
b = modiff('t01_steady_opts.mod', 't01_steady_opts.true.mod');
if ~b
    error('Steady with options test failed.')
end
delete t01_steady_opts.mod

% Test steady with options including a standalone flag
m.write('t01_steady_opts_flag.mod', initval=true, steady=true, steady_options={'maxit', 100, 'nocheck'});
b = modiff('t01_steady_opts_flag.mod', 't01_steady_opts_flag.true.mod');
if ~b
    error('Steady with options+flag test failed.')
end
delete t01_steady_opts_flag.mod

% Test steady_options without steady throws an error
try
    m.write('t01_error.mod', steady_options={'maxit', 100});
    error('Should have thrown an error.')
catch e
    if ~contains(e.message, 'steady')
        rethrow(e)
    end
end

fprintf('steady-options/t01.m: All tests passed\n');
