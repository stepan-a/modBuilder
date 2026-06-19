% Tests for check_indices_values errors (implicit-loop index validation)

m = modBuilder();

% Mixed integer/char values within a single index array
thrown = false;
try
    m.parameter('a_$1', {1, 'two'});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:check_indices_values:indexMismatch');
end
assert(thrown, 'Expected check_indices_values:indexMismatch for mixed index types.');

% Index values passed as a 2-D (non-vector) cell array
thrown = false;
try
    m.parameter('a_$1', {1, 2; 3, 4});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:check_indices_values:badType');
end
assert(thrown, 'Expected check_indices_values:badType for a 2-D index cell.');
