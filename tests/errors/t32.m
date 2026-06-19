% Tests for handle_implicit_loops argument-parsing errors

m = modBuilder();

% Wrong number of index arrays vs placeholders in the name
thrown = false;
try
    m.parameter('a_$1_$2', {1, 2});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:handle_implicit_loops:indexMismatch');
end
assert(thrown, 'Expected handle_implicit_loops:indexMismatch (2 placeholders, 1 index array).');

% Attribute key provided without a value
thrown = false;
try
    m.parameter('a_$1', 'long_name');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:handle_implicit_loops:missingValue');
end
assert(thrown, 'Expected handle_implicit_loops:missingValue.');

% Unexpected argument type (neither a key/value pair nor an index array)
thrown = false;
try
    m.parameter('a_$1', 'foo', {1});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:handle_implicit_loops:badType');
end
assert(thrown, 'Expected handle_implicit_loops:badType.');

% long_name carries more placeholders than the symbol name
thrown = false;
try
    m.parameter('a_$1', 'long_name', 'Param $1 $2', {1});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:handle_implicit_loops:indexMismatch');
end
assert(thrown, 'Expected handle_implicit_loops:indexMismatch for long_name placeholder count.');
