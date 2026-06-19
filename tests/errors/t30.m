% Tests for collection-name validation in size(), table() and validate_type()

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);
m.exogenous('e', 0);

% size(): the singular symbol-type string is not a valid collection name
thrown = false;
try
    m.size('parameter');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:validate_type:unknownType');
end
assert(thrown, 'Expected validate_type:unknownType for size(''parameter'').');

% size(): unknown collection name
thrown = false;
try
    m.size('bogus');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:validate_type:unknownType');
end
assert(thrown, 'Expected validate_type:unknownType for size(''bogus'').');

% size(): plural collection names are accepted
assert(m.size('parameters') == 1, 'size(''parameters'') should be 1.');
assert(m.size('equations') == 1, 'size(''equations'') should be 1.');

% table(): ''equations'' is a valid size() collection but unsupported by table()
thrown = false;
try
    m.table('equations');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:table:unknownType');
end
assert(thrown, 'Expected table:unknownType for table(''equations'').');

% table(): unknown type
thrown = false;
try
    m.table('bogus');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:table:unknownType');
end
assert(thrown, 'Expected table:unknownType for table(''bogus'').');
