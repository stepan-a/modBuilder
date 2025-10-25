% Test examples from remove method documentation

m = modBuilder();
m.add('c', 'c = w*h');
m.add('y', 'y = c + i');
m.parameter('w', 1.5);
% Type remaining symbols
m.exogenous('h', NaN);
m.exogenous('i', NaN);
m.updatesymboltables();

% Remove the consumption equation
initial_eqs = m.size('endogenous');
m.remove('c');  % Also removes h if it doesn't appear elsewhere

% Verify equation was removed
assert(m.size('endogenous') == initial_eqs - 1);
assert(~any(strcmp(m.equations(:,1), 'c')));

fprintf('remove.m: All tests passed\n');
