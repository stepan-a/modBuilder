% Tests for the symbolic linear-system machinery:
% linearise_system, split_linear_set, solve_linear_system, symbolic_det and
% bareiss_triangulate (including row-pivoting and the structurally-singular path).

% --- linearise_system: a 2x2 linear system ---
% 2*x + 3*y - 5 = 0 ;  x - y + 1 = 0
[ok, A, b] = ast.linearise_system({ast('2*x + 3*y - 5'), ast('x - y + 1')}, {'x', 'y'});
assert(ok, 'System should be jointly linear in {x,y}.');
assert(isequal(size(A), [2 2]) && numel(b) == 2, 'A must be 2x2 and b length 2.');
assert(A{1,1}.eval(struct()) == 2, 'A(1,1) should be 2.');
assert(A{1,2}.eval(struct()) == 3, 'A(1,2) should be 3.');
assert(A{2,1}.eval(struct()) == 1, 'A(2,1) should be 1.');
assert(A{2,2}.eval(struct()) == -1, 'A(2,2) should be -1.');
assert(b{1}.eval(struct()) == -5, 'b(1) should be -5.');
assert(b{2}.eval(struct()) == 1, 'b(2) should be 1.');

% --- solve_linear_system: closed form of that system (x = 2/5, y = 7/5) ---
rhs = ast.solve_linear_system(A, b);
assert(abs(rhs{1}.eval(struct()) - 2/5) < 1e-12, 'x should be 2/5.');
assert(abs(rhs{2}.eval(struct()) - 7/5) < 1e-12, 'y should be 7/5.');

% --- linearise_system rejects a non-linear system ---
[ok2, ~, ~] = ast.linearise_system({ast('x*y'), ast('x + y')}, {'x', 'y'});
assert(~ok2, 'x*y is not jointly linear in {x,y}.');

% --- is_linear_in_set: target in a denominator is non-linear ---
assert(~ast('a/x').is_linear_in_set({'x'}), 'a/x is not linear in x.');

% --- linearise_system requires a square system ---
threw = false;
try
    ast.linearise_system({ast('x')}, {'x', 'y'});
catch ME
    threw = strcmp(ME.identifier, 'ast:linearise_system');
end
assert(threw, 'Expected ast:linearise_system for a non-square system.');

% --- symbolic_det: empty matrix is 1 ---
assert(ast.symbolic_det({}).eval(struct()) == 1, 'det of the empty matrix is 1.');

% --- symbolic_det with row pivoting: det([0 1; 1 0]) = -1 ---
swap = {ast('num', 0, {}), ast('num', 1, {}); ast('num', 1, {}), ast('num', 0, {})};
assert(ast.symbolic_det(swap).eval(struct()) == -1, 'det([0 1; 1 0]) should be -1.');

% --- symbolic_det of a structurally singular matrix (zero first column) is 0 ---
sing = {ast('num', 0, {}), ast('num', 1, {}); ast('num', 0, {}), ast('num', 1, {})};
assert(ast.symbolic_det(sing).eval(struct()) == 0, 'structurally singular det should be 0.');

% --- symbolic_det of a 1x1 matrix (bareiss early return) ---
assert(ast.symbolic_det({ast('num', 7, {})}).eval(struct()) == 7, 'det of [7] should be 7.');

% --- symbolic_det of a 3x3 matrix exercises fraction-free division ---
num = @(v) ast('num', v, {});
M3 = {num(2), num(1), num(0); num(1), num(2), num(1); num(0), num(1), num(2)};
assert(ast.symbolic_det(M3).eval(struct()) == 4, 'det of the tridiagonal [2 1 0;1 2 1;0 1 2] should be 4.');

% --- solve_linear_system: the empty system returns an empty result ---
assert(isempty(ast.solve_linear_system({}, {})), 'Empty system should return {}.');

% --- solve_linear_system: a structurally singular system returns empties ---
rsing = ast.solve_linear_system({num(0), num(1); num(0), num(1)}, {num(1); num(2)});
assert(isempty(rsing{1}) && isempty(rsing{2}), 'Singular system should return empty solutions.');

% --- is_linear_in_set treats a lagged target (tsym) as the variable ---
assert(ast('x(-1) + y').is_linear_in_set({'x'}), 'x(-1) + y is linear in x.');
