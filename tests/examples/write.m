% Test examples from write method documentation

m = modBuilder();
m.add('c', 'c = alpha*k');
m.parameter('alpha', 0.33);

% Write to file 'mymodel.mod'
m.write('mymodel');

% Verify file was created
assert(exist('mymodel.mod', 'file') == 2);

% Clean up
delete mymodel.mod

fprintf('write.m: All tests passed\n');
