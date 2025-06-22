% Test that deep copy is working as expected.

addpath ../utils

% Instantiate an empty model
model1 = modBuilder();

% Set a model with only one endogenous variable (y) defined as an AR(p)
eqarp = 'y =';
for lag=1:10
    eqarp = sprintf('%s rho%u*y(-%u) +', eqarp, lag, lag);
end
eqarp = sprintf('%s e', eqarp);

model1.add('y', eqarp);

for lag = 1:10
    model1.parameter(sprintf('rho%u', lag), 2*rand-1);
end

% Check that the remaining symbols are the exogenous variables (structural innovations)
if ~isequal(model1.symbols, {'e'})
    error()
end

model1.exogenous('e', 0);

model1.updatesymboltables();

model2 = copy(model1);

model2.parameter('rho10', 0);

if model1==model2
    error('Deep copy is not working as expected.')
end
