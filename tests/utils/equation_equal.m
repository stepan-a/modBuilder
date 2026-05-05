function b = equation_equal(eq1, eq2)
% Test whether two equation strings are mathematically equivalent.
%
% INPUTS:
% - eq1, eq2  [char]  equation strings (either "LHS = RHS" or pure expressions)
%
% OUTPUTS:
% - b         [logical]  scalar, true iff the parsed (LHS - RHS) trees are
%                        structurally equal.
%
% REMARKS:
% - Used in tests where the AST renderer's spacing differs from the input
%   text (e.g. after subs / rename / substitute → rename rewrites). Direct
%   strcmp is brittle; this helper compares the parsed forms.
    b = ast.ast_equal(parse_eq(eq1), parse_eq(eq2));
end

function tree = parse_eq(eq_str)
    LHSRHS = strsplit(eq_str, '=');
    if length(LHSRHS) == 2
        L = ast(strtrim(LHSRHS{1}));
        R = ast(strtrim(LHSRHS{2}));
        tree = ast('binop', '-', {L, R});
    elseif isscalar(LHSRHS)
        tree = ast(strtrim(LHSRHS{1}));
    else
        error('equation_equal: equation contains more than one "=" symbol: %s', eq_str)
    end
end
