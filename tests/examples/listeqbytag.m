% Test examples from listeqbytag method documentation

% Build a model with tagged equations
m = modBuilder();
m.add('Y_m', 'Y_m = A_m*K_m^alpha_m*L_m^(1-alpha_m)');
m.add('Y_s', 'Y_s = A_s*K_s^alpha_s*L_s^(1-alpha_s)');
m.add('C', 'C = Y_m + Y_s');
m.add('K_m', 'K_m = (1-delta)*K_m(-1) + I_m');
m.parameter('A_m', 1.0);
m.parameter('A_s', 1.0);
m.parameter('alpha_m', 0.33);
m.parameter('alpha_s', 0.50);
m.parameter('delta', 0.025);
m.exogenous('L_m', 1.0);
m.exogenous('L_s', 1.0);
m.exogenous('I_m', 0.0);

% Tag equations
m.tag('Y_m', 'sector', 'manufacturing');
m.tag('Y_m', 'type', 'production');
m.tag('Y_s', 'sector', 'services');
m.tag('Y_s', 'type', 'production');
m.tag('C', 'type', 'aggregation');
m.tag('K_m', 'sector', 'manufacturing');
m.tag('K_m', 'type', 'accumulation');

% Test 1: exact match on a single tag
eqs = m.listeqbytag('sector', 'manufacturing');
assert(numel(eqs) == 2);
assert(all(ismember({'Y_m', 'K_m'}, eqs)));

% Test 2: regex match
eqs = m.listeqbytag('sector', 'manuf.*');
assert(numel(eqs) == 2);
assert(all(ismember({'Y_m', 'K_m'}, eqs)));

% Test 3: single match
eqs = m.listeqbytag('sector', 'services');
assert(numel(eqs) == 1);
assert(strcmp(eqs{1}, 'Y_s'));

% Test 4: match all production equations
eqs = m.listeqbytag('type', 'production');
assert(numel(eqs) == 2);
assert(all(ismember({'Y_m', 'Y_s'}, eqs)));

% Test 5: multiple criteria (AND)
eqs = m.listeqbytag('sector', 'manufacturing', 'type', 'production');
assert(numel(eqs) == 1);
assert(strcmp(eqs{1}, 'Y_m'));

% Test 6: regex matching multiple values
eqs = m.listeqbytag('type', 'production|accumulation');
assert(numel(eqs) == 3);
assert(all(ismember({'Y_m', 'Y_s', 'K_m'}, eqs)));

% Test 7: no match raises error
try
    m.listeqbytag('sector', 'agriculture');
    error('Expected an error for non-matching criteria.')
catch e
    assert(strcmp(e.message, 'No equation matches the given tag criteria.'));
end

% Test 8: no duplicates in result
eqs = m.listeqbytag('type', '.*');
assert(numel(eqs) == numel(unique(eqs)));

fprintf('listeqbytag.m: All tests passed\n');
