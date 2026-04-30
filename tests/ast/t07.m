% staticise: collapse all time subscripts to plain symbols.

% Single tsym → sym
n = ast('x(-1)').staticise();
assert(strcmp(n.type, 'sym') && strcmp(n.value, 'x'), 'tsym(x,-1) → sym(x)');

% Tree with a mix of tsym, sym, and other nodes
n = ast('alpha * K(-1)^theta * L(+1)^(1 - theta)').staticise();
% After staticisation the tree must be equal to the static version
expected = ast('alpha * K^theta * L^(1 - theta)');
assert(ast.ast_equal(n, expected), 'compound tsym → sym');

% staticise leaves num, ss, sym untouched
n = ast('STEADY_STATE(K) + alpha + 0.5').staticise();
expected = ast('STEADY_STATE(K) + alpha + 0.5');
assert(ast.ast_equal(n, expected), 'staticise is identity on tsym-free trees');

% staticise inside a function call
n = ast('exp(x(-1))').staticise();
expected = ast('exp(x)');
assert(ast.ast_equal(n, expected), 'staticise descends into call args');
