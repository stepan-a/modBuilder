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

% Check that all symbols have a type
if not(isempty(model.symbols))
    error()
end

model.updatesymboltables();

m0 = copy(model);

model.remove('a');

model.write('rbc3');

b = modiff('rbc3.mod', 'rbc3.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc3.mod
end

m1 = copy(model);

model.add('a', 'a = rho*a(-1)+tau*b(-1) + e');
model.exogenous('e', 0);

model.updatesymboltables();

rm2c = @(x) [x(:,1) x(:,3:4)];

if ~isequal(sortrows(model.equations, 1), sortrows(m0.equations, 1))
    error('Cannot revert flip of a and e (equations).')
end

if ~isequal(rm2c(sortrows(model.var, 1)), rm2c(sortrows(m0.var, 1)))
    error('Cannot revert flip of a and e (list of endogenous variables).')
end

if ~isequal(sortrows(model.varexo, 1), sortrows(m0.varexo, 1))
    error('Cannot revert flip of a and e (list of exogenoous variables).')
end

if ~isequal(sortrows(model.params, 1), sortrows(m0.params, 1))
    error('Cannot revert flip of a and e (parameters).')
end

if ~isequal(model.tags, m0.tags)
    error('Cannot revert flip of a and e (tags).')
end
