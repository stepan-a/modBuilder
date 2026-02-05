% Test reassign method

addpath ../utils

% --- Test 1: Pairwise swap ---
m = modBuilder();
m.add('y', 'y = alpha*k');
m.add('k', 'k = (1-delta)*k(-1) + i');
m.parameter('alpha', 0.33);
m.parameter('delta', 0.025);
m.exogenous('i', 0);

% Before swap: y owns 'y = alpha*k', k owns 'k = (1-delta)*k(-1) + i'
m.reassign('y', 'k');
% After swap: y owns 'k = (1-delta)*k(-1) + i', k owns 'y = alpha*k'

m.write('t01_swap.mod');
b = modiff('t01_swap.mod', 't01_swap.true.mod');
if ~b
    error('Pairwise swap test failed.')
end
delete t01_swap.mod

% --- Test 2: Three-way cycle ---
m2 = modBuilder();
m2.add('a', 'a = x + y');
m2.add('b', 'b = y + z');
m2.add('c', 'c = z + x');
m2.exogenous('x', 0);
m2.exogenous('y', 0);
m2.exogenous('z', 0);

% Before: a owns 'a = x + y', b owns 'b = y + z', c owns 'c = z + x'
m2.reassign('a', 'b', 'c');
% After: a owns 'c = z + x', b owns 'a = x + y', c owns 'b = y + z'

m2.write('t01_cycle.mod');
b = modiff('t01_cycle.mod', 't01_cycle.true.mod');
if ~b
    error('Three-way cycle test failed.')
end
delete t01_cycle.mod

% --- Test 3: Tags follow the equation ---
m3 = modBuilder();
m3.add('p', 'p = alpha*q');
m3.add('q', 'q = beta*p');
m3.parameter('alpha', 0.5);
m3.parameter('beta', 0.8);
m3.tag('p', 'description', 'Price equation');
m3.tag('q', 'description', 'Quantity equation');

m3.reassign('p', 'q');

% After swap: p's tag should be q's old tag and vice versa
assert(strcmp(m3.tags.p.description, 'Quantity equation'), 'Tag should follow equation after reassign');
assert(strcmp(m3.tags.q.description, 'Price equation'), 'Tag should follow equation after reassign');

% --- Test 4: Error — not endogenous ---
try
    m.reassign('y', 'alpha');
    error('Should have thrown an error.')
catch e
    if ~contains(e.message, 'not endogenous')
        rethrow(e)
    end
end

% --- Test 5: Error — duplicate name ---
try
    m.reassign('y', 'y');
    error('Should have thrown an error.')
catch e
    if ~contains(e.message, 'distinct')
        rethrow(e)
    end
end

% --- Test 6: Error — single argument ---
try
    m.reassign('y');
    error('Should have thrown an error.')
catch e
    if ~contains(e.message, 'at least two')
        rethrow(e)
    end
end

fprintf('reassign/t01.m: All tests passed\n');
