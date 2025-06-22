% Test the change method. In the updated version of the equation, all symbols remain the same except for one — rho5, which has been removed.
% The change method should therefore:
% - Remove rho5 from the list of parameters in o.params and o.T.params,
% - Ensure that rho5 is no longer referenced in o.T.equations.

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
    model.parameter(sprintf('rho%u', lag), 2*rand-1);
end

% Check that the remaining symbols are the exogenous variables (structural innovations)
if ~isequal(model.symbols, {'e'})
    error()
end

model.exogenous('e', 0);

model.updatesymboltables();

eqarp = 'y =';
for lag=1:4
    eqarp = sprintf('%s rho%u*y(-%u) +', eqarp, lag, lag);
end
eqarp = sprintf('%s e', eqarp);

model.updatesymboltables();

model.change('y', eqarp);

model.updatesymboltables();


if not(isempty(model.symbols))
    error('List of symbols should be empty.')
end

if not(isequal(model.params(:,1), {'rho1'; 'rho2'; 'rho3'; 'rho4'}))
    error('Wrong list of parameters')
end

if not(isequal(model.T.equations.y, {'e' 'rho1' 'rho2' 'rho3' 'rho4'}))
    error('Wrong list of symbols in equation.')
end
