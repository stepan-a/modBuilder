% Test examples from typeof method documentation

m = modBuilder();
m.add('c', 'c = alpha*k + epsilon');
m.parameter('alpha', 0.33);
m.exogenous('epsilon', 0);

% Check symbol types
[type, id] = typeof(m, 'alpha');    % Returns 'parameter'
assert(strcmp(type, 'parameter'));

[type, id] = typeof(m, 'c');        % Returns 'endogenous'
assert(strcmp(type, 'endogenous'));

[type, id] = typeof(m, 'epsilon');  % Returns 'exogenous'
assert(strcmp(type, 'exogenous'));

fprintf('typeof.m: All tests passed\n');
