% Tests for the "more than one =" guards and solve unknown-symbol error

m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 0);

% solve(): unknown symbol to solve for
thrown = false;
try
    m.solve('y', 'ghost', 0);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:solve:unknownSymbol');
end
assert(thrown, 'Expected solve:unknownSymbol for an unknown symbol.');

% A deliberately malformed equation with two "=" exercises the multipleEquals
% guards of the methods that split an equation on "=".
m.add('z', 'z = a = b');
m.parameter('a', 1);
m.parameter('b', 2);

% solve()
thrown = false;
try
    m.solve('z', 'a', 0);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:solve:multipleEquals');
end
assert(thrown, 'Expected solve:multipleEquals.');

% evaluate()
thrown = false;
try
    m.evaluate('z');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:evaluate:multipleEquals');
end
assert(thrown, 'Expected evaluate:multipleEquals.');

% rename()
thrown = false;
try
    m.rename('a', 'aa');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:rename:multipleEquals');
end
assert(thrown, 'Expected rename:multipleEquals.');

% compile_equations()
thrown = false;
try
    m.compile_equations({'z'}, {'a'});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:compile_equations:multipleEquals');
end
assert(thrown, 'Expected compile_equations:multipleEquals.');
