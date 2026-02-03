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

% Set default values for the exogenous variables
model.exogenous('e', 0);
model.exogenous('u', 0);

model.write('rbc15a', 'with-initval');

% The inival block should not be printed, since none of the endogenous variables are given a value
b = modiff('rbc15a.mod', 'rbc15a.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc15a.mod
end

model.a = 0;
model.y = 1;
model.k = 3;

model.write('rbc15b', 'with-initval');

b = modiff('rbc15b.mod', 'rbc15b.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc15b.mod
end
