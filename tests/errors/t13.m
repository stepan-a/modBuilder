% Tests for extract and listeqbytag errors

m = modBuilder();
m.add('y', 'y = alpha*x + e');
m.add('c', 'c = beta*y');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.8);
m.exogenous('e', 0);
m.exogenous('x', 0);

% Test 1: extract with missing equation
thrown = false;
try
    m.extract('y', 'nonexistent');
catch
    thrown = true;
end
assert(thrown, 'Expected error: missing equation in extract.');

% Test 2: listeqbytag with odd number of arguments
thrown = false;
try
    m.listeqbytag('sector');
catch
    thrown = true;
end
assert(thrown, 'Expected error: odd number of arguments in listeqbytag.');
