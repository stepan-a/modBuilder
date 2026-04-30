% Constructor: leaf nodes (numbers and bare symbols)

n = ast('0.33');
assert(strcmp(n.type, 'num') && n.value == 0.33 && isempty(n.children), 'num leaf');

n = ast('1e-5');
assert(strcmp(n.type, 'num') && n.value == 1e-5, 'num scientific');

n = ast('alpha');
assert(strcmp(n.type, 'sym') && strcmp(n.value, 'alpha') && isempty(n.children), 'sym leaf');

n = ast('GDP_t');
assert(strcmp(n.type, 'sym') && strcmp(n.value, 'GDP_t'), 'sym with underscore and digits');
