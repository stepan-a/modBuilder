% Tests for subs() argument-type and unknown-equation errors

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);

% subs: expr2 is neither a char array nor an ast object
thrown = false;
try
    m.subs('alpha', 5);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subs:badType');
end
assert(thrown, 'Expected subs:badType when expr2 is numeric.');

% subs: equation name does not exist
thrown = false;
try
    m.subs('q', 'r', 'noeq');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:subs:unknownSymbol');
end
assert(thrown, 'Expected subs:unknownSymbol for an unknown equation name.');
