% EXPECTATION(k)(expr): Dynare's dated expectation, carried as an 'expect' node.

% Parses and prints back in the renderer's spacing, the offset with its sign.
n = ast('beta*EXPECTATION(-1)(x(+1)) + EXPECTATION(+2)(z)');
assert(strcmp(n.string(), 'beta * EXPECTATION(-1)(x(1)) + EXPECTATION(2)(z)'), sprintf('Unexpected rendering: %s', n.string()));
e = ast('EXPECTATION(-1)(x(+1))');
assert(strcmp(e.type, 'expect') && e.value == -1 && strcmp(e.children{1}.type, 'tsym'), 'The node should carry the offset and the dated argument.');

% The symbols inside are the equation's.
assert(isequal(sort(n.symbol_names()), sort({'beta', 'x', 'z'})), 'symbol_names should see through the expectation.');

% At the steady state an expectation is the value it expects.
assert(strcmp(e.staticise().string(), 'x'), sprintf('staticise should drop the operator, got %s', e.staticise().string()));

% Shifting moves the information set with the expression: a model-local variable
% #m = EXPECTATION(-1)(x(+1)) used as m(-1) reads EXPECTATION(-2)(x).
r = ast('a*m(-1)').substitute('m', 'EXPECTATION(-1)(x(+1))');
assert(strcmp(r.string(), 'a * EXPECTATION(-2)(x)'), sprintf('Unexpected shift: %s', r.string()));

% An expectation is opaque to the factor test, as a function call is.
[has, cancels] = ast('EXPECTATION(-1)(x(+1))*y').check_factor('x');
assert(has && ~cancels, 'x is inside the expectation: present, not a factor.');

% Evaluation and differentiation see through it.
assert(ast('2*EXPECTATION(-1)(x(+1))').eval(struct('x', 3)) == 6, 'eval should give the expected value.');
d = ast('beta*EXPECTATION(-1)(x(+1)^2)').diff_ast('x', 1);
assert(contains(d.string(), 'EXPECTATION(-1)('), sprintf('The derivative should stay under the expectation, got %s', d.string()));

% LaTeX: the information set as a subscript of the expectation operator.
assert(contains(e.to_latex(), '\mathbb{E}_{t-1}'), sprintf('Unexpected LaTeX: %s', e.to_latex()));

% The information set is a signed integer, followed by the parenthesised argument.
for bad = {'EXPECTATION(a)(x)', 'EXPECTATION(-1)', 'EXPECTATION(1.5)(x)'}
    thrown = false;
    try
        ast(bad{1});
    catch ME
        thrown = strcmp(ME.identifier, 'ast:parse');
    end
    assert(thrown, sprintf('"%s" should be a parse error.', bad{1}));
end
