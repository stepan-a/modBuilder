addpath ../utils

% Test equation-syntax validation for subs() and substitute() methods.
%
% subs() is AST-based: malformed targets / replacements are rejected at parse
% time. substitute() is text-based (regexprep): malformed substitution results
% are rejected by validate_equation_syntax after the fact.

% --- subs() rejects malformed input at parse time ---

% Unbalanced parens in the replacement: ast() throws Missing closing ")".
m1 = modBuilder();
m1.add('y', 'y = a*x');
m1.parameter('a', 0.8);
try
    m1.subs('x', '(b + c', 'y')  %#ok<NOPRT>
    error('subs should have thrown for unbalanced parentheses in the replacement')
catch ME
    if ~contains(ME.message, ')') && ~contains(ME.message, 'parse')
        error('subs: expected a parse-time error mentioning closing parenthesis, got: %s', ME.message)
    end
end

% A non-symbol target (the bare '=' character): ast() throws on the unexpected token.
m2 = modBuilder();
m2.add('y', 'y = a*x');
m2.parameter('a', 0.8);
try
    m2.subs('=', '==', 'y')  %#ok<NOPRT>
    error('subs should have thrown for a non-parseable target')
catch ME
    if ~contains(ME.message, 'Unexpected') && ~contains(ME.message, 'parse')
        error('subs: expected a parse-time error mentioning unexpected character, got: %s', ME.message)
    end
end

% Valid expression target with structurally well-formed replacement.
m3 = modBuilder();
m3.add('y', 'y = a+b');
m3.parameter('a', 0.8);
m3.parameter('b', 0.2);
m3.subs('a+b', 'a*a + b*b', 'y');
LHSRHS = strsplit(m3.equations{1,2}, '=');
got = ast(strtrim(LHSRHS{2}));
expected = ast('a*a + b*b');
if ~ast.ast_equal(got.simplify(), expected.simplify())
    error('valid subs should have produced y = a*a + b*b, got: %s', m3.equations{1,2})
end

% --- substitute() rejects malformed results at validate-equation-syntax time ---

% Unbalanced parens via regexprep: validate_equation_syntax catches them.
m4 = modBuilder();
m4.add('y', 'y = a*x');
m4.parameter('a', 0.8);
try
    m4.substitute('x', '(b + c', 'y')  %#ok<NOPRT>
    error('substitute should have thrown for unbalanced parentheses')
catch ME
    if ~contains(ME.message, 'unbalanced parentheses')
        error('substitute: expected error mentioning unbalanced parentheses, got: %s', ME.message)
    end
end

% Replacement introducing == is rejected too.
m5 = modBuilder();
m5.add('y', 'y = a*x');
m5.parameter('a', 0.8);
try
    m5.substitute('=', '==', 'y')  %#ok<NOPRT>
    error('substitute should have thrown for ==')
catch ME
    if ~contains(ME.message, '==')
        error('substitute: expected error mentioning ==, got: %s', ME.message)
    end
end

fprintf('t02.m: All tests passed\n');
