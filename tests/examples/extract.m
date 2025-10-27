% Test examples from extract method documentation

m = modBuilder();
m.add('c', 'c = w*h');
m.add('y', 'y = c + i');
m.add('i', 'i = delta*k');
m.parameter('w', 1.5);
m.parameter('delta', 0.1);
% Type remaining symbols
m.exogenous('h', NaN);
m.exogenous('k', NaN);

% Extract only consumption and output equations
submodel = m.extract('c', 'y');

% Verify submodel has 2 equations
assert(submodel.size('endogenous') == 2);
assert(any(strcmp(submodel.equations(:,1), 'c')));
assert(any(strcmp(submodel.equations(:,1), 'y')));

% submodel has w parameter, but not delta
assert(any(strcmp(submodel.params(:,1), 'w')));
assert(~any(strcmp(submodel.params(:,1), 'delta')));

fprintf('extract.m: All tests passed\n');
