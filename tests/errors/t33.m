% Tests for rm()/remove() argument and lookup errors

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);

% rm() with no arguments
thrown = false;
try
    m.rm();
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rm:missingArg');
end
assert(thrown, 'Expected rm:missingArg.');

% rm() with a non-char first argument
thrown = false;
try
    m.rm(42);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rm:badType');
end
assert(thrown, 'Expected rm:badType.');

% remove() of an unknown equation
thrown = false;
try
    m.remove('ghost');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:remove:unknownSymbol');
end
assert(thrown, 'Expected remove:unknownSymbol.');
