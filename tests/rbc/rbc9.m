% Test of the merge method.
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
model.parameter('alpha', 0.36);
model.parameter('rhoa', 0.95);
model.parameter('taua', 0.025);
model.parameter('rhob', 0.95);
model.parameter('taub', 0.025);
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


%
% Create two models. The first one for output, consumption, hours and physical capital stock, where a and b are treated
% -----------------  as exogenous variables. The second model for a and b considering a VAR(1) model. Both models are
%                    obtained by extracting equations from model.
%

model1 = model('y', 'c', 'h', 'k');

model2 = model('a', 'b');

%
% Merge the two models
%

MODEL = merge(model1, model2);

%
% Test that MOODEL and model are identical
%

if not(model==MODEL)
    error('merge method is not working as expected.')
end
