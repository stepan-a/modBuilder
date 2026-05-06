% steady_aux: collision detection and storage in o.steady_state.

addpath ../utils

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1);

% Happy path: aux that does not collide with anything.
m.steady_aux('_aux1', 'alpha*x');
if size(m.steady_state, 1) ~= 1
    error('Expected 1 steady-state entry after one aux, got %d.', size(m.steady_state, 1))
end
if ~strcmp(m.steady_state{1, 1}, '_aux1')
    error('Aux name not stored.')
end

% Collision with a parameter.
ok = false;
try
    m.steady_aux('alpha', 'something');
catch
    ok = true;
end
if ~ok, error('steady_aux should reject a name colliding with a parameter.'), end

% Collision with an endogenous.
ok = false;
try
    m.steady_aux('y', 'something');
catch
    ok = true;
end
if ~ok, error('steady_aux should reject a name colliding with an endogenous.'), end

% Collision with an exogenous.
ok = false;
try
    m.steady_aux('x', 'something');
catch
    ok = true;
end
if ~ok, error('steady_aux should reject a name colliding with an exogenous.'), end

% Collision with a previously-defined aux.
ok = false;
try
    m.steady_aux('_aux1', 'other');
catch
    ok = true;
end
if ~ok, error('steady_aux should reject a duplicate aux name.'), end

% A subsequent steady() call referencing the aux must work; checksteady should see
% the aux as a valid node (not an unknown symbol).
m.steady('y', '_aux1');
sorted = m.checksteady();
if ~isequal(sort(sorted), sort({'_aux1', 'y'}))
    error('checksteady should sort aux + var entries; got: %s', strjoin(sorted, ', '))
end

fprintf('t16.m: steady_aux collision detection + checksteady integration OK\n');
