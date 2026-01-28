% Tests for eq method: tags differ

% Build reference model
m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: One model has a tag, the other does not
m2 = m.copy();
m2.tag('y', 'description', 'Output equation');
assert(~(m == m2), 'Should differ: m2 has tag, m does not.');

% Test 2: Both have same tags
m3 = m.copy();
m3.tag('y', 'description', 'Output equation');
m4 = m.copy();
m4.tag('y', 'description', 'Output equation');
assert(m3 == m4, 'Models with identical tags should be equal.');

% Test 3: Same tag key, different values
m5 = m.copy();
m5.tag('y', 'description', 'Output equation');
m6 = m.copy();
m6.tag('y', 'description', 'Income equation');
assert(~(m5 == m6), 'Should differ: different tag values.');

% Test 4: Tags on different equations
m7 = m.copy();
m7.tag('y', 'description', 'Output');
m8 = m.copy();
m8.tag('c', 'description', 'Output');
assert(~(m7 == m8), 'Should differ: tags on different equations.');
