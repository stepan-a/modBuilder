% Tests for ast constructor, tokeniser, parser and eval error paths

% Constructor called with an invalid number of arguments (2 args)
thrown = false;
try
    ast('x', 1);
catch ME
    thrown = strcmp(ME.identifier, 'ast:constructor');
end
assert(thrown, 'Expected ast:constructor for a 2-argument call.');

% Parser/tokeniser errors (all reported under the ast:parse identifier)
bad_exprs = {
    '1.2.3'             % malformed number
    'a +'               % operator with no right operand
    'STEADY_STATE(1)'   % STEADY_STATE expects a symbol argument
    'log(a'             % missing closing parenthesis
    'x(y)'              % non-integer time subscript
    'x(-1'              % missing ")" after time subscript
    ')'                 % unexpected token
};
for k = 1:numel(bad_exprs)
    thrown = false;
    try
        ast(bad_exprs{k});
    catch ME
        thrown = strcmp(ME.identifier, 'ast:parse');
    end
    assert(thrown, sprintf('Expected ast:parse for "%s".', bad_exprs{k}));
end

% eval with a symbol that has no provided value
thrown = false;
try
    ast('a + b').eval(struct('a', 1));
catch ME
    thrown = strcmp(ME.identifier, 'ast:eval');
end
assert(thrown, 'Expected ast:eval for a symbol with no value.');
