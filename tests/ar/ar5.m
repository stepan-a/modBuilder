% Test modBuilder object index.

addpath ../utils

% Instantiate an empty model
model = modBuilder();

model.add('y', 'y = rho1*y(-1) + rho2*x(-1) + ey');
model.add('x', 'y = rho2*y(-1) + rho3*x(-1) + ex');

model.exogenous('ey', 0);
model.exogenous('ex', 0);

model.parameter('rho1', .3);
model.parameter('rho2', .8);
model.parameter('rho3', .1);

model.updatesymboltables();

model('rho1') = .2;

if model.params{ismember(model.params(:,1), 'rho1'),2}~=.2
    error('Parameter assignment did not work.')
end

model('ey') = .2;

if model.varexo{ismember(model.varexo(:,1), 'ey'),2}~=.2
    error('Exogenous variable assignment did not work.')
end

model('y') = .2;

if model.var{ismember(model.var(:,1), 'y'),2}~=.2
    error('Endogenous variable assignment did not work.')
end

if ~isequal(model.equations{ismember(model.equations(:,1), 'y'),2}, 'y = rho1*y(-1) + rho2*x(-1) + ey')
    error('Endogenous variable assignment did not work.')
end

model('y') = 'y = rho1*y(-1) + ey';

if ~isequal(model.equations{ismember(model.equations(:,1), 'y'),2}, 'y = rho1*y(-1) + ey')
    error('Equation update did not work.')
end

if model.var{ismember(model.var(:,1), 'y'),2}~=.2
    error('Equation update did not work.')
end
