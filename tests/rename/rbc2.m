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

m0.rename('k', 'PhysicalCapital');
m0.rename('alpha', 'ALPHA');

if ~strcmp(m0.y.equations{2}, 'y = exp(a)*(PhysicalCapital(-1)^ALPHA)*(h^(1-ALPHA))')
    error('Test of rename method failed (y).')
end

if ~strcmp(m0.PhysicalCapital.equations{2}, '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*ALPHA*y(+1)/PhysicalCapital+(1-deltak))')
    error('Test of rename method failed (PhysicalCapital).')
end

if ~strcmp(m0.h.equations{2}, 'c*theta*h^(1+psi)=(1-ALPHA)*y')
    error('Test of rename method failed (h).')
end

if ~isfield(m0.T.params, 'ALPHA')
    error('Test of rename method failed.')
end

if ~isequal(m0.T.equations.PhysicalCapital, {'ALPHA'  'b'  'beta'  'c'  'deltak'  'y'})
    error('Test of rename method failed.')
end
