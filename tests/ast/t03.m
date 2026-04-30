% Time-subscripted variables (tsym)

n = ast('Consumption(-1)');
assert(strcmp(n.type, 'tsym'), 'tsym for x(-1)');
assert(strcmp(n.value{1}, 'Consumption') && n.value{2} == -1, 'name and lag');

n = ast('K(+1)');
assert(strcmp(n.type, 'tsym') && strcmp(n.value{1}, 'K') && n.value{2} == 1, 'positive lag with +');

n = ast('K(1)');
assert(strcmp(n.type, 'tsym') && n.value{2} == 1, 'positive lag without +');

% lag 0 collapses to a plain symbol
n = ast('K(0)');
assert(strcmp(n.type, 'sym') && strcmp(n.value, 'K'), 'x(0) collapses to sym');

% Inside a binop
n = ast('alpha * K(-1) + beta');
assert(strcmp(n.value, '+'), 'top is +');
left = n.children{1};
assert(strcmp(left.value, '*'), 'left is *');
assert(strcmp(left.children{2}.type, 'tsym'), 'K(-1) parsed as tsym');
