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
% model.parameter('phi', 0.1); this parameter is not used in the model

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


m0 = copy(model);

m0.substitute('(?<!\w)k(?!\w)', 'PhysicalCapital');

if ~strcmp(m0{'c'}.equations{2}, 'PhysicalCapital = exp(b)*(y-c)+(1-deltak)*PhysicalCapital(-1)')
    error('Test of substitute method failed.')
end

if ~strcmp(m0{'PhysicalCapital'}.equations{2}, '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/PhysicalCapital+(1-deltak))')
    error('Test of substitute method failed.')
end

if ~strcmp(m0{'y'}.equations{2}, 'y = exp(a)*(PhysicalCapital(-1)^alpha)*(h^(1-alpha))')
    error('Test of substitute method failed.')
end
