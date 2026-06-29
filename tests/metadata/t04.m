% Tests for the save/load schema version (saveobj/loadobj versioning).

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1);
m.steady('y', 'alpha*x');

% Test 1: saveobj stamps the current schema version.
s = m.saveobj();
assert(isfield(s, 'version'), 'saveobj must stamp a version field.');
assert(s.version == modBuilder.SCHEMA_VERSION, ...
       'saveobj version (%d) must equal SCHEMA_VERSION (%d).', s.version, modBuilder.SCHEMA_VERSION);

% Test 2: a full save/load round-trip preserves the model.
matfile = [tempname(), '.mat'];
cleaner = onCleanup(@() delete(matfile));
save(matfile, 'm');
clear m
loaded = load(matfile);
m = loaded.m;
assert(m.params{1,2} == 0.5,      'alpha lost on round-trip.');
assert(isequal(m.steady_state, {'y', 'alpha*x'}), 'steady_state lost on round-trip.');

% Test 3: an unversioned legacy struct (no version field, no steady_state /
% calibration_swaps) loads via the version-0 migration with defaults.
legacy = struct();
legacy.params = m.params;
legacy.varexo = m.varexo;
legacy.var = m.var;
legacy.tags = m.tags;
legacy.symbols = m.symbols;
legacy.equations = m.equations;
legacy.T = m.T;
legacy.date = m.date;
m_legacy = modBuilder.loadobj(legacy);
assert(isempty(m_legacy.steady_state),      'legacy load must default steady_state to empty.');
assert(isempty(m_legacy.calibration_swaps), 'legacy load must default calibration_swaps to empty.');
assert(m_legacy.params{1,2} == 0.5,         'legacy load must preserve core data.');

% Test 4: a missing core field is rejected.
broken = rmfield(s, 'equations');
threw = false;
try
    modBuilder.loadobj(broken);
catch e
    threw = strcmp(e.identifier, 'modBuilder:loadobj:invalidObject');
end
assert(threw, 'loadobj must reject a struct missing a core field.');

% Test 5: a file from a newer schema than this class understands is rejected.
future = s;
future.version = modBuilder.SCHEMA_VERSION + 1;
threw = false;
try
    modBuilder.loadobj(future);
catch e
    threw = strcmp(e.identifier, 'modBuilder:loadobj:futureVersion');
end
assert(threw, 'loadobj must reject a future schema version.');

fprintf('metadata/t04.m: schema versioning round-trips and guards correctly\n');
