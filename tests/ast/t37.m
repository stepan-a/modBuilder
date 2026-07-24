% ast.factor_common: common-subexpression elimination over a set of trees.
% The rewritten trees plus the hoisted definitions must evaluate to exactly what
% the originals did, the definitions must be independent of one another, and the
% generated names must not collide with the symbols in scope.

vals = struct('a', 1.7, 'b', 0.3, 'c', 2.9, 'x', 1.3);

% A subexpression repeated inside one tree and shared with another.
shared = '(a*x^2 + b*x + c)';
e1 = ast(sprintf('%s*%s + %s', shared, shared, 'b')).simplify();
e2 = ast(sprintf('%s/(1 + %s)', shared, shared)).simplify();
before = [e1.eval(vals), e2.eval(vals)];

[names, defs, out] = ast.factor_common({e1, e2}, 'cse', 4, {'a', 'b', 'c', 'x'});

assert(~isempty(names), 'a subexpression repeated four times must be hoisted');
assert(numel(names) == numel(defs) && numel(out) == 2, 'output shapes must agree');
assert(all(cellfun(@(n) ~ismember(n, {'a', 'b', 'c', 'x'}), names)), ...
       'generated names must avoid the symbols in scope');

% The rewritten trees must actually reference the names.
refs = union(out{1}.symbol_names(), out{2}.symbol_names());
assert(any(ismember(names, refs)), 'the rewritten trees must reference the hoisted names');

% Definitions are independent: none may reference another generated name.
for k = 1:numel(defs)
    assert(~any(ismember(names, defs{k}.symbol_names())), ...
           'definition %s must not depend on another hoisted name', names{k});
end

% Evaluating definitions then the rewritten trees reproduces the originals.
v2 = vals;
for k = 1:numel(names)
    v2.(names{k}) = defs{k}.eval(v2);
end
after = [out{1}.eval(v2), out{2}.eval(v2)];
assert(max(abs(after - before)) < 1e-12, ...
       'factored form must evaluate to the original values (%g vs %g / %g vs %g)', ...
       after(1), before(1), after(2), before(2));

% Nothing to factor: an expression without repeats comes back untouched.
[n0, d0, o0] = ast.factor_common({ast('a + b*x')}, 'cse', 4, {});
assert(isempty(n0) && isempty(d0) && strcmp(o0{1}.string(), ast('a + b*x').string()), ...
       'an expression without repeats must be returned unchanged');

% The minimum size is honoured: x*x is repeated but tiny.
[n1, ~, ~] = ast.factor_common({ast('a*x + b*x')}, 'cse', 8, {});
assert(isempty(n1), 'subtrees below minsize must not be hoisted');

% Name collision: the generated stem must move out of the way.
[n2, ~, ~] = ast.factor_common({e1, e2}, 'cse', 4, {'cse1', 'cse2', 'a', 'b', 'c', 'x'});
assert(all(cellfun(@(n) ~ismember(n, {'cse1', 'cse2'}), n2)), ...
       'generated names must dodge reserved names that already use the stem');

fprintf('ast/t37: factor_common (CSE) OK -- %d subexpression(s) hoisted\n', numel(names));
