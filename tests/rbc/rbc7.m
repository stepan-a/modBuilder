addpath ../utils

% Instantiate an empty model
model = modBuilder();

% Set equations
model.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
model.add('c', 'k = exp(b)*(y-c)+(1-delta)*k(-1)');
model.add('h', 'c*theta*h^(1+psi)=(1-alpha)*y');
model.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-delta))');

% Define parameters and provide calibration
model.parameters('alpha', 0.36);
model.parameters('beta', 0.99);
model.parameters('delta', 0.025);
model.parameters('psi', 0);
model.parameters('theta', 2.95);
model.parameters('phi', 0.1);

% Set default values for the exogenous variables
model.exogenous('a', 0);
model.exogenous('b', 0);

% Redefine a as a parameter
model.parameters('a', .1);

model.updatesymboltables();

if not(model.size('exogenous')==1)
    error('Wrong number of exogenous variables.')
end

if not(model.size('parameters')==7)
    error('Wrong number of exogenous variables.')
end

if not(model.params{7,1}=='a') || not(model.params{7,2}==0.1)
    error('Conversion from exogenous variable to parameter is not working properly.')
end

model.exogenous('a', 0);

model.updatesymboltables();

if not(model.size('exogenous')==2)
    error('Wrong number of exogenous variables.')
end

if not(model.size('parameters')==6)
    error('Wrong number of exogenous variables.')
end

if not(model.varexo{2,1}=='a') || not(model.varexo{2,2}==0)
    error('Conversion from parameter to exogenous variable is not working properly.')
end

model.updatesymboltables();
