% ast.diff_ast — unsupported functions raise ast:diff_ast:noRule

% diff, adl and EXPECTATIONS are Dynare time-series operators, not pointwise
% functions, so "the derivative w.r.t. x" is not a pointwise-function question.
% Each must raise the documented error id so the Method='auto' solver path can
% detect the gap and fall back to autoDiff1. (abs, sign, min and max ARE
% supported — see t24 — so they are not listed here.)
unsupported = {'diff(x)', 'adl(x)', 'EXPECTATIONS(x)'};

for k = 1:numel(unsupported)
    expr = unsupported{k};
    threw = false;
    try
        ast(expr).diff_ast('x');
    catch err
        threw = true;
        assert(strcmp(err.identifier, 'ast:diff_ast:noRule'), ...
               sprintf('expected ast:diff_ast:noRule for %s, got %s', expr, err.identifier));
    end
    assert(threw, sprintf('diff_ast(%s) should have raised', expr));
end

% A supported outer function around an unsupported one still propagates noRule.
threw = false;
try
    ast('exp(diff(x))').diff_ast('x');
catch err
    threw = true;
    assert(strcmp(err.identifier, 'ast:diff_ast:noRule'), 'nested diff should raise noRule');
end
assert(threw, 'diff_ast(exp(diff(x))) should have raised');

% An unsupported operator that does NOT depend on the target is still a hard
% error (diff_node recurses into every call regardless of dependence).
threw = false;
try
    ast('x + adl(y)').diff_ast('x');
catch err
    threw = true;
    assert(strcmp(err.identifier, 'ast:diff_ast:noRule'), 'adl(y) term should raise noRule');
end
assert(threw, 'diff_ast(x + adl(y)) should have raised');

fprintf('t25.m: ast.diff_ast noRule path OK\n');
