addpath ../utils

% Instantiate an empty model
model = modBuilder();

% Set equations
model.add('a', 'a = rho*a(-1)+tau*b(-1) + e');
model.add('b', 'b = tau*a(-1)+rho*b(-1) + u');
model.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
model.add('c', 'k = exp(b)*(y-c)+(1-deltak)*k(-1)');
model.add('h', 'c*theta*h^(1+psi)=(1-alpha)*y');
model.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-deltak))');

% Define parameters and provide calibration
model.parameter('alpha', 0.36);
model.parameter('rho', 0.95);
model.parameter('tau', 0.025);
model.parameter('beta', 0.99);
model.parameter('deltak', 0.025);
model.parameter('psi', 0);
model.parameter('theta', 2.95);
model.parameter('phi', 0.1);

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

m0 = copy(model);

m0.substitute('b\(-1\)', 'a(-2)', 'a');

if ~strcmp(m0.a.equations{2}, 'a = rho*a(-1)+tau*a(-2) + e')
    error('Test of substitute method failed.')
end

if ismember('a', m0.T.var.b)
    error('Test of substitute method failed (T.var is not consistent with the updated version of the model).')
end
