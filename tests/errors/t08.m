% Tests for flip errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: Unknown endogenous variable
thrown = false;
try
    m.flip('nonexistent', 'e');
catch
    thrown = true;
end
assert(thrown, 'Expected error: unknown endogenous variable.');

% Test 2: Unknown exogenous variable
thrown = false;
try
    m.flip('y', 'nonexistent');
catch
    thrown = true;
end
assert(thrown, 'Expected error: unknown exogenous variable.');

% Test 3: Index placeholder mismatch between varname and varexoname
m2 = modBuilder();
m2.add('y_1', 'y_1 = a_1*x_1 + e_1');
m2.add('y_2', 'y_2 = a_2*x_2 + e_2');
m2.parameter('a_1', 0.5);
m2.parameter('a_2', 0.5);
m2.exogenous('x_1', 0);
m2.exogenous('x_2', 0);
m2.exogenous('e_1', 0);
m2.exogenous('e_2', 0);
thrown = false;
try
    m2.flip('y_$1', 'e_$2', {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: index placeholder mismatch.');

% Test 4: Wrong number of index arrays
thrown = false;
try
    m2.flip('y_$1', 'e_$1', {1, 2}, {3, 4});
catch
    thrown = true;
end
assert(thrown, 'Expected error: wrong number of index arrays.');
