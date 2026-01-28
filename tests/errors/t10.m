% Tests for subs errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: Multiple equation names
thrown = false;
try
    m.subs('x', 'z', 'y', 'c');
catch
    thrown = true;
end
assert(thrown, 'Expected error: only one equation name allowed.');

% Test 2: Index placeholder mismatch between expr1 and expr2
thrown = false;
try
    m.subs('x_$1', 'z_$2', {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: index placeholder mismatch.');

% Test 3: Index values provided but no placeholders
thrown = false;
try
    m.subs('x', 'z', {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: no placeholders but index values provided.');

% Test 4: Wrong number of index arrays
m2 = modBuilder();
m2.add('y_1', 'y_1 = a_1*x_1');
m2.add('y_2', 'y_2 = a_2*x_2');
m2.parameter('a_1', 0.5);
m2.parameter('a_2', 0.5);
m2.exogenous('x_1', 0);
m2.exogenous('x_2', 0);
thrown = false;
try
    m2.subs('x_$1_$2', 'z_$1_$2', {1, 2});
catch
    thrown = true;
end
assert(thrown, 'Expected error: wrong number of index arrays.');
