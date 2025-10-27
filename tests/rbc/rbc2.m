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


m0 = copy(model);

model.flip('a', 'e');

if ~isfield(model.T.equations, 'e') || isfield(model.T.equations, 'a')
    error('flip method did not update the fields of o.T.equations correctly.')
end

if ~isequal(model.T.equations.e, {'b'  'a'  'rho'  'tau'})
    error('flip method did not write o.T.equations.e correctly.')
end

model.write('rbc2');

[b, diff] = modiff('rbc2.mod', 'rbc2.true.mod');

expectedhash = '9ea986d0360bc92cf9951ccceaea4855';

if not(b)
    if isequal(numel(diff), 1)
        if ~isequal(hashchararray(diff{1}), expectedhash)
            error('Generated mod file might be wrong.')
        end
    else
        error('Generated mod file might be wrong.')
    end
end

delete rbc2.mod

% Check if we can revert the flip
model.flip('e', 'a');

rm2c = @(x) [x(:,1) x(:,3:4)];

if ~isequal(model.equations, m0.equations)
    error('Cannot revert flip of a and e (equations).')
end

if ~isequal(rm2c(sortrows(model.var, 1)), rm2c(sortrows(m0.var, 1)))
    error('Cannot revert flip of a and e (list of endogenous variables).')
end

if ~isequal(rm2c(sortrows(model.varexo, 1)), rm2c(sortrows(m0.varexo, 1)))
    error('Cannot revert flip of a and e (list of exogenoous variables).')
end

if ~isequal(rm2c(sortrows(model.params, 1)), rm2c(sortrows(m0.params, 1)))
    error('Cannot revert flip of a and e (parameters).')
end

if ~isequal(model.tags, m0.tags)
    error('Cannot revert flip of a and e (tags).')
end
