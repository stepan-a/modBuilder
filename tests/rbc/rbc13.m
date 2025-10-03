addpath ../utils

% Instantiate an empty model
model = modBuilder();

% Set equations
model.add('a', 'a = rho*a(-1)+tau*b(-1) + e');
model.add('b', 'b = tau*a(-1)+rho*b(-1) + u');
model.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
model.add('c', 'k = exp(b)*(y-c)+(1-delta)*k(-1)');
model.add('h', 'c*theta*h^(1+psi)=(1-alpha)*exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
model.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*exp(a(1))*(k^(alpha-1))*(h(1)^(1-alpha))+(1-delta))');

% Define parameters and provide calibration
model.parameter('alpha', 0.36);
model.parameter('rho', 0.95);
model.parameter('tau', 0.025);
model.parameter('beta', 0.99);
model.parameter('delta', 0.025);
model.parameter('psi', 0);
model.parameter('theta', 2.95);

% Check that the remaining symbols are the exogenous variables (structural innovations)
if ~isequal(model.symbols, {'e', 'u'})
    error()
end

% Set default values for the exogenous variables
model.exogenous('e', 0);
model.exogenous('u', 0);

model.updatesymboltables();

model.endogenous('a', 0);
model.endogenous('b', 0);
model.endogenous('h', 1/3);
model.endogenous('c', 1);    % Any value would do the trick, will be updated later.

model.solve('k', 'k', 0.5);
model.solve('y', 'y', 1.0);
model.solve('c', 'c', 1.0);  % Correct steady state for consumption

model.solve('h', 'psi', 0); % Find the parameterization consistent with h=1/3

resids = NaN(6,1);

for i=1:6
    s = model.evaluate(model.equations{i,1}, false);
    resids(i) = s.resid;
    fprintf('Residual of the static equation for %s is %f.\n', model.equations{i,1}, s.resid);
end

if any(abs(resids)>1e-8)
    error('Steady state computation failed.')
end
