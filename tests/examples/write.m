% Test examples from write method documentation

m = modBuilder();
m.add('c', 'c = alpha*k');
m.parameter('alpha', 0.33);

% Write to file 'mymodel.mod'
m.write('mymodel.mod');
assert(exist('mymodel.mod', 'file') == 2);
delete mymodel.mod

% Write with higher precision (15 significant digits)
m.write('mymodel.mod', precision=15);
assert(exist('mymodel.mod', 'file') == 2);
delete mymodel.mod

% Write with initval block
m.endogenous('c', 1);  % Set initial value so initval block is generated
m.write('mymodel.mod', initval=true);
assert(exist('mymodel.mod', 'file') == 2);
delete mymodel.mod

% Write with initval, steady, and check
m.write('mymodel.mod', initval=true, steady=true, check=true);
assert(exist('mymodel.mod', 'file') == 2);
delete mymodel.mod

% Write with steady options
m.write('mymodel.mod', initval=true, steady=true, steady_options={'maxit', 100, 'nocheck'});
assert(exist('mymodel.mod', 'file') == 2);
delete mymodel.mod

% Combine options
m.write('mymodel.mod', initval=true, precision=10);
assert(exist('mymodel.mod', 'file') == 2);
delete mymodel.mod

fprintf('write.m: All tests passed\n');
