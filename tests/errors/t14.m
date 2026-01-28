% Tests for solve errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('e', 0);
m.exogenous('x', 1);
m.endogenous('y', 0);

% Test 1: Symbol not in equation (parameter)
thrown = false;
try
    m.solve('y', 'nonexistent', 1.0);
catch
    thrown = true;
end
assert(thrown, 'Expected error: symbol not in equation.');

% Test 2: Solve for a parameter that appears in the equation
% alpha appears in the equation for y: y = alpha*x + e
% With x=1 and e=0, we have y = alpha*1 + 0. Solve for alpha given y=0.5.
m.endogenous('y', 0.5);
m.solve('y', 'alpha', 0.3);
assert(abs(m.params{1,2} - 0.5) < 1e-6, 'Solve should find alpha = 0.5.');
