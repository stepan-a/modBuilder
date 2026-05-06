% steady_aux: m.calibrate validation cases.

addpath ../utils

m = modBuilder();
m.add('y', 'y = alpha*x + beta*c');
m.add('c', 'c = rho*c(-1) + e');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.5);
m.parameter('rho', 0.9);
m.exogenous('x', 1);
m.exogenous('e', 0);

% Happy path: pin endogenous y, solve for parameter alpha.
m.calibrate('y', 1, 'alpha');
if size(m.calibration_swaps, 1) ~= 1
    error('Expected 1 swap recorded, got %d.', size(m.calibration_swaps, 1))
end

% Reject: endo is not endogenous (it's a parameter).
ok = false;
try
    m.calibrate('alpha', 0.5, 'beta');
catch
    ok = true;
end
if ~ok, error('calibrate should reject a parameter as endo.'), end

% Reject: param is not a parameter (it's exogenous).
ok = false;
try
    m.calibrate('c', 1, 'x');
catch
    ok = true;
end
if ~ok, error('calibrate should reject an exogenous as the elevated param.'), end

% Reject: endo already in a swap.
ok = false;
try
    m.calibrate('y', 2, 'beta');
catch
    ok = true;
end
if ~ok, error('calibrate should reject a duplicate endo.'), end

% Reject: param already in a swap.
ok = false;
try
    m.calibrate('c', 1, 'alpha');
catch
    ok = true;
end
if ~ok, error('calibrate should reject a duplicate param.'), end

fprintf('t19.m: m.calibrate validation OK\n');
