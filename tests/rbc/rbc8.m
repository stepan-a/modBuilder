addpath ../utils

% Instantiate an empty model
model = modBuilder();

% Set equations
model.add('a', 'a = rhoa*a(-1)+taua*b(-1) + e');
model.add('b', 'b = taub*a(-1)+rhob*b(-1) + u');
model.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
model.add('c', 'k = exp(b)*(y-c)+(1-delta)*k(-1)');
model.add('h', 'c*theta*h^(1+psi)=(1-alpha)*y');
model.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-delta))');

% Define parameters and provide calibration
model.parameters('alpha', 0.36);
model.parameters('rhoa', 0.95);
model.parameters('taua', 0.025);
model.parameters('rhob', 0.95);
model.parameters('taub', 0.025);
model.parameters('beta', 0.99);
model.parameters('delta', 0.025);
model.parameters('psi', 0);
model.parameters('theta', 2.95);

% Check that the remaining symbols are the exogenous variables (structural innovations)
if ~isequal(model.symbols, {'e', 'u'})
    error()
end

% Set default values for the exogenous variables
model.exogenous('e', 0);
model.exogenous('u', 0);

model.updatesymboltables();

MODEL = model.extract('y', 'c', 'h', 'k');

MODEL.write('rbc8');

b = modiff('rbc8.mod', 'rbc8.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc8.mod
end

if not(MODEL.size('parameters')==5)
    error('Wrong number of parameters in the extracted model.')
end

if not(isequal(fields(MODEL.T.params), {'alpha'; 'beta'; 'delta'; 'psi'; 'theta'}))
    error('Wrong number of parameters in the extracted model (T).')
end

if not(isequal(MODEL.varexo(:,1), {'a'; 'b'}))
    error('Wrong list of exogenoous variables in the extracted model.')
end

if not(isequal(fields(MODEL.T.varexo), {'a'; 'b'}))
    error('Wrong list of exogenous variables in the extracted model (T).')
end
