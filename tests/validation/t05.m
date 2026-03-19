% Test that getsymbols correctly ignores scientific notation and decimals

m = modBuilder();

% Scientific notation (integer exponent) should not produce spurious symbols
m.add('y', 'y = x + 1e5');
assert(any(strcmp('x', m.T.equations.y)), 'x should be extracted');
assert(~any(strcmp('1e5', m.T.equations.y)), '1e5 should not be extracted');
assert(~any(strcmp('e5', m.T.equations.y)), 'e5 should not be extracted');

% Scientific notation (negative exponent) should not produce spurious symbols
m.add('z', 'z = w + 1e-5');
assert(any(strcmp('w', m.T.equations.z)), 'w should be extracted');
assert(~any(strcmp('1e', m.T.equations.z)), '1e should not be extracted');
assert(~any(strcmp('e', m.T.equations.z)), 'e should not be extracted');

% Decimal numbers should not produce spurious symbols
m.add('c', 'c = 0.33*k');
assert(any(strcmp('k', m.T.equations.c)), 'k should be extracted');
assert(~any(strcmp('0', m.symbols)), '0 should not be an untyped symbol');
assert(~any(strcmp('33', m.symbols)), '33 should not be an untyped symbol');

% Mixed: scientific notation, decimals, and valid symbols
m.add('r', 'r = alpha*k + 3.14 + 2e-3');
assert(any(strcmp('alpha', m.T.equations.r)), 'alpha should be extracted');
assert(any(strcmp('k', m.T.equations.r)), 'k should be extracted');
assert(~any(strcmp('2e', m.T.equations.r)), '2e should not be extracted');
assert(~any(strcmp('e', m.T.equations.r)), 'e should not be extracted');
