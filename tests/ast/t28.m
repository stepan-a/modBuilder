% Tests for ast defensive guards on malformed nodes.
% These node-type/operator guards cannot be reached through normal parsing,
% but the raw 3-argument constructor ast(type, value, children) builds nodes
% without validation, so the guards can be exercised directly.

bad = ast('bogus', 0, {});                                   % unknown node type
opbad = ast('binop', '@', {ast('num', 1, {}), ast('num', 2, {})});  % unknown operator

% string() on an unknown node type
thrown = false;
try
    bad.string();
catch ME
    thrown = strcmp(ME.identifier, 'ast:string');
end
assert(thrown, 'Expected ast:string for an unknown node type.');

% eval() on an unknown node type
thrown = false;
try
    bad.eval(struct());
catch ME
    thrown = strcmp(ME.identifier, 'ast:eval');
end
assert(thrown, 'Expected ast:eval for an unknown node type.');

% to_latex() on an unknown node type
thrown = false;
try
    bad.to_latex(containers.Map(), false);
catch ME
    thrown = strcmp(ME.identifier, 'ast:to_latex');
end
assert(thrown, 'Expected ast:to_latex for an unknown node type.');

% diff_ast() on an unknown node type
thrown = false;
try
    bad.diff_ast('x', 0);
catch ME
    thrown = strcmp(ME.identifier, 'ast:diff_ast:badNode');
end
assert(thrown, 'Expected ast:diff_ast:badNode for an unknown node type.');

% eval_binop via a binop node carrying an unknown operator
thrown = false;
try
    opbad.eval(struct());
catch ME
    thrown = strcmp(ME.identifier, 'ast:eval_binop');
end
assert(thrown, 'Expected ast:eval_binop for an unknown operator.');

% diff of a binop node carrying an unknown operator
thrown = false;
try
    opbad.diff_ast('x', 0);
catch ME
    thrown = strcmp(ME.identifier, 'ast:diff_ast:badOp');
end
assert(thrown, 'Expected ast:diff_ast:badOp for an unknown operator.');
