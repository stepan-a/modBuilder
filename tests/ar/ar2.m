% Test change method. In the new version of the equation we have the
% same symbols, except for an additional parameter. This new symbol,
% belongs to o.symbols as a type is not explicitely provided.

addpath ../utils

% Instantiate an empty model
model = modBuilder();

% Set a model with only one endogenous variable (y) defined as an AR(p)
eqarp = 'y =';
for lag=1:5
    eqarp = sprintf('%s rho%u*y(-%u) +', eqarp, lag, lag);
end
eqarp = sprintf('%s e', eqarp);

model.add('y', eqarp);

for lag = 1:5
    model.parameters(sprintf('rho%u', lag), 2*rand-1);
end

% Check that the remaining symbols are the exogenous variables (structural innovations)
if ~isequal(model.symbols, {'e'})
    error()
end

model.exogenous('e', 0);

model.updatesymboltables();

eqarp = 'y =';
for lag=1:6
    eqarp = sprintf('%s rho%u*y(-%u) +', eqarp, lag, lag);
end
eqarp = sprintf('%s e', eqarp);

model.change('y', eqarp);

model.updatesymboltables();

if not(length(model.symbols)==1) || not(isequal(model.symbols{1},'rho6'))
    error('Missing one symbol.')
end

if not(isequal(model.T.equations.y, {'e'  'rho1'  'rho2'  'rho3'  'rho4'  'rho5'  'rho6'}))
    error('Wrong list of symbols in equation.')
end

model.parameters('rho6', .1);

if not(isempty(model.symbols))
    error('The list of untyped symbols should be empty.')
end

if not(isequal(model.params(:,1), {'rho1'; 'rho2'; 'rho3'; 'rho4'; 'rho5'; 'rho6'}))
    error('Wrong list of parameters.')
end
