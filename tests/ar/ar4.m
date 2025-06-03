% Test the change method. In the updated version of the equation for y, all symbols remain the same except for one — rho2, which has been removed. But
% this parameter also appears in the equation for x.
% The change method should therefore:
% - Not remove rho2 from the list of parameters in o.params and o.T.params,
% - Ensure that rho2 is no longer referenced in o.T.equations.
% - Ensure that only equation for x is referenced in o.T.params.rho2

addpath ../utils

% Instantiate an empty model
model = modBuilder();

model.add('y', 'y = rho1*y(-1) + rho2*x(-1) + ey');
model.add('x', 'y = rho2*y(-1) + rho3*x(-1) + ex');

model.exogenous('ey', 0);
model.exogenous('ex', 0);

model.parameters('rho1', .3);
model.parameters('rho2', .8);
model.parameters('rho3', .1);

model.updatesymboltables();

model.change('y', 'y = rho1*y(-1) + ey');

model.updatesymboltables();


if not(isempty(model.symbols))
    error('List of symbols should be empty.')
end

if model.size('parameters')<3
    error('Missing parameter.')
end

if not(isequal(model.T.equations.y, {'ey' 'rho1'}))
    error('Wrong list of symbols in the equation for y.')
end

if not(isequal(model.T.params.rho2, {'x'}))
    error('Wrong list of references for parameter rho2.')
end
