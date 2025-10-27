% Test examples from lookfor method documentation

m = modBuilder();
m.add('c', 'c = w*h');
m.add('y', 'y = c + i');
m.add('i', 'i = delta*k');
m.parameter('w', 1.5);
m.parameter('delta', 0.1);

% Find all equations containing 'c'
% This will print output to console
m.lookfor('c');
% Output should show: Endogenous variable c appears in 2 equations:
%         [c]  c = w*h
%         [y]  y = c + i

% Verify c appears in the symbol table
assert(length(m.T.var.c) == 2);

fprintf('lookfor.m: All tests passed\n');
