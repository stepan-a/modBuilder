% Tests for subsref: cell array indexing on properties (o.property{:,k})

m = modBuilder();
m.add('y', 'y = alpha*k^theta');
m.add('c', 'c = y - invest');
m.add('k', 'k = invest + (1-delta)*k(-1)');

m.parameter('alpha', 0.5);
m.parameter('theta', 0.36);
m.parameter('delta', 0.025);
m.exogenous('invest', 10);

% Test 1: Numeric column extraction - o.params{:,2} should return numeric array
vals = m.params{:,2};
assert(isnumeric(vals), 'params{:,2} should return numeric array');
assert(isequal(size(vals), [3, 1]), 'params{:,2} should be 3x1 column vector');
assert(isequal(vals, [0.5; 0.36; 0.025]), 'params{:,2} values incorrect');

% Test 2: String column extraction - o.params{:,1} should return cell array of chars
names = m.params{:,1};
assert(iscell(names), 'params{:,1} should return cell array');
assert(isequal(size(names), [3, 1]), 'params{:,1} should be 3x1');
assert(isequal(names, {'alpha'; 'theta'; 'delta'}), 'params{:,1} names incorrect');

% Test 3: Multiple columns - o.params{:,[1,2]} should return cell array (mixed types)
mixed = m.params{:,[1,2]};
assert(iscell(mixed), 'params{:,[1,2]} should return cell array for mixed types');
assert(isequal(size(mixed), [3, 2]), 'params{:,[1,2]} should be 3x2');

% Test 4: Row subset - o.params{1:2,2} should return numeric array
subset = m.params{1:2,2};
assert(isnumeric(subset), 'params{1:2,2} should return numeric array');
assert(isequal(size(subset), [2, 1]), 'params{1:2,2} should be 2x1');
assert(isequal(subset, [0.5; 0.36]), 'params{1:2,2} values incorrect');

% Test 5: Chained indexing - o.params{:,2}(1) should return scalar
first_val = m.params{:,2}(1);
assert(isscalar(first_val), 'params{:,2}(1) should return scalar');
assert(first_val == 0.5, 'params{:,2}(1) should be 0.5');

% Test 6: Chained indexing with range - o.params{:,1}(2:3)
last_names = m.params{:,1}(2:3);
assert(iscell(last_names), 'params{:,1}(2:3) should return cell array');
assert(isequal(last_names, {'theta'; 'delta'}), 'params{:,1}(2:3) values incorrect');

% Test 7: Single element with {:,k} - should still work
single = m.varexo{:,2};
assert(isnumeric(single), 'varexo{:,2} with single row should return numeric');
assert(single == 10, 'varexo{:,2} should be 10');

% Test 8: Equations - column 2 contains strings
eq_strings = m.equations{:,2};
assert(iscell(eq_strings), 'equations{:,2} should return cell array');
assert(length(eq_strings) == 3, 'equations{:,2} should have 3 elements');

% Test 9: Specific rows with index array
idx_vals = m.params{[1,3],2};
assert(isnumeric(idx_vals), 'params{[1,3],2} should return numeric array');
assert(isequal(idx_vals, [0.5; 0.025]), 'params{[1,3],2} values incorrect');

% Test 10: Single row, single column - scalar result
scalar_val = m.params{2,2};
assert(isscalar(scalar_val), 'params{2,2} should return scalar');
assert(scalar_val == 0.36, 'params{2,2} should be 0.36');
