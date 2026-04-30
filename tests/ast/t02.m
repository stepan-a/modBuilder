% Constructor: binary operators and precedence

n = ast('a + b');
assert(strcmp(n.type, 'binop') && strcmp(n.value, '+'), 'binop +');
assert(strcmp(n.children{1}.type, 'sym') && strcmp(n.children{1}.value, 'a'), 'left of +');
assert(strcmp(n.children{2}.type, 'sym') && strcmp(n.children{2}.value, 'b'), 'right of +');

% a + b * c → +(a, *(b, c))
n = ast('a + b * c');
assert(strcmp(n.type, 'binop') && strcmp(n.value, '+'), 'top is +');
assert(strcmp(n.children{2}.type, 'binop') && strcmp(n.children{2}.value, '*'), '* has higher precedence');

% (a + b) * c → *(+(a, b), c)
n = ast('(a + b) * c');
assert(strcmp(n.type, 'binop') && strcmp(n.value, '*'), 'top is *');
assert(strcmp(n.children{1}.type, 'binop') && strcmp(n.children{1}.value, '+'), 'parens override precedence');

% a - b - c → -(- (a, b), c)  (left-associative)
n = ast('a - b - c');
assert(strcmp(n.type, 'binop') && strcmp(n.value, '-'), 'outer -');
assert(strcmp(n.children{1}.type, 'binop') && strcmp(n.children{1}.value, '-'), 'left of - is -');
assert(strcmp(n.children{2}.value, 'c'), 'right of - is c');

% a^b^c → ^(a, ^(b, c))  (right-associative)
n = ast('a^b^c');
assert(strcmp(n.value, '^'), 'top is ^');
assert(strcmp(n.children{1}.type, 'sym'), 'left of ^ is leaf');
assert(strcmp(n.children{2}.value, '^'), 'right of ^ is ^ (right-assoc)');

% Unary minus: -x*y → *(uminus(x), y)
n = ast('-x*y');
assert(strcmp(n.type, 'binop') && strcmp(n.value, '*'), 'unary minus binds tighter than *');
assert(strcmp(n.children{1}.type, 'uminus'), 'left is uminus');

% -x^y → uminus(^(x, y))  (^ binds tighter than unary -)
n = ast('-x^y');
assert(strcmp(n.type, 'uminus'), 'unary minus outermost');
assert(strcmp(n.children{1}.value, '^'), 'inside is ^');
