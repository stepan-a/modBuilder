addpath ../utils

% Instantiate an empty model
model = modBuilder();

% Set equations
model.add('a', 'a = rho*a(-1)+tau*b(-1) + e');
model.add('b', 'b = tau*a(-1)+rho*b(-1) + u');
model.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
model.add('c', 'k = exp(b)*(y-c)+(1-delta)*k(-1)');
model.add('h', 'c*theta*h^(1+psi)=(1-alpha)*y');
model.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-delta))');

% Define parameters and provide calibration
model.parameters('alpha', 0.36);
model.parameters('rho', 0.95);
model.parameters('tau', 0.025);
model.parameters('beta', 0.99);
model.parameters('delta', 0.025);
model.parameters('psi', 0);
model.parameters('theta', 2.95);
model.parameters('phi', 0.1);

% Check that the remaining symbols are the exogenous variables (structural innovations)
if ~isequal(model.symbols, {'e', 'u'})
    error()
end

% Set default values for the exogenous variables
model.exogenous('e', 0);
model.exogenous('u', 0);

% Check that all symbols have a type
if not(isempty(model.symbols))
    error()
end

model.updatesymboltables();

model.flip('a', 'e');

model.write('rbc2');

b = modiff('rbc2.mod', 'rbc2.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
end

delete rbc2.mod
