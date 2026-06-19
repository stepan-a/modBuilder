% Tests for subsref/subsasgn/rm access errors

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);

% subsref: reference to a non-existent field or method
thrown = false;
try
    v = m.bogusfield; %#ok<NASGU>
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subsref:unknownSymbol');
end
assert(thrown, 'Expected subsref:unknownSymbol for an unknown field.');

% subsasgn: assignment to a non-existent symbol
thrown = false;
try
    m.bogus = 5;
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subsasgn:unknownSymbol');
end
assert(thrown, 'Expected subsasgn:unknownSymbol for an unknown symbol.');

% rm: indexed equation name with invalid (mixed-type) index values
thrown = false;
try
    m.rm('y$1', {1, 'two'});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rm:indexMismatch');
end
assert(thrown, 'Expected rm:indexMismatch for invalid index values.');
