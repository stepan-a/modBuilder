% modBuilder.eliminate — solve an endogenous variable's own equation for it, substitute the
% result throughout, and drop the equation. Recovers the textbook Euler from an augmented model.

addpath ../utils

% ---------------------------------------------------------------------------
% Optimal growth: augment introduces mult_1 (= 1/c); eliminate it to get the
% standard consumption Euler in a square (W, k, c) system.
% ---------------------------------------------------------------------------
m = modBuilder();
m.add('W', 'W = log(c) + beta*W(+1)');
m.add('k', 'A*k(-1)^alpha + (1-delta)*k(-1) = c + k');
m.parameter('beta', 0.99);
m.parameter('A', 1);
m.parameter('alpha', 0.33);
m.parameter('delta', 0.025);
r = m.lagrangian_foc('W', {'k'}, {'c', 'k'});
m.augment(r);

assert(m.isendogenous('mult_1'), 'augment added mult_1');
m.eliminate('mult_1');

% mult_1 is gone, the model stays square in (W, k, c).
assert(~m.issymbol('mult_1'),    'mult_1 removed entirely');
assert(size(m.var, 1) == 3 && size(m.equations, 1) == 3, 'square (W, k, c)');
assert(isequal(sort(m.var(:,1)), {'W'; 'c'; 'k'}), 'endogenous are W, c, k');

% The equation keyed to c is now the standard consumption Euler (multiplier substituted out).
% Compare up to algebra and overall sign: the residual is determined only up to a factor.
euler = m{'c'}.equations{2};
assert(same_equation(euler, '1/c = beta*(1/c(+1))*(1 - delta + A*alpha*k^(alpha-1))'), ...
       sprintf('consumption Euler wrong: %s', euler));

% The objective and the resource constraint are untouched.
assert(equation_equal(m{'W'}.equations{2}, 'W = log(c) + beta*W(+1)'),                'objective kept');
assert(equation_equal(m{'k'}.equations{2}, 'A*k(-1)^alpha + (1-delta)*k(-1) = c + k'), 'resource constraint kept');

% ---------------------------------------------------------------------------
% Only endogenous variables can be eliminated.
% ---------------------------------------------------------------------------
caught = false;
try
    m.eliminate('beta');          % a parameter
catch e
    caught = strcmp(e.identifier, 'modBuilder:eliminate:notEndogenous');
end
assert(caught, 'eliminating a parameter must raise notEndogenous');

m2 = modBuilder();
m2.add('y', 'y = a + e');
m2.parameter('a', 1);
m2.exogenous('e', 0);
caught = false;
try
    m2.eliminate('e');            % an exogenous variable
catch e
    caught = strcmp(e.identifier, 'modBuilder:eliminate:notEndogenous');
end
assert(caught, 'eliminating an exogenous variable must raise notEndogenous');

caught = false;
try
    m2.eliminate('nope');         % an unknown symbol
catch e
    caught = strcmp(e.identifier, 'modBuilder:eliminate:notEndogenous');
end
assert(caught, 'eliminating an unknown symbol must raise notEndogenous');

% ---------------------------------------------------------------------------
% A variable that cannot be isolated in closed form raises notClosedForm.
% ---------------------------------------------------------------------------
m3 = modBuilder();
m3.add('y', 'log(y) + y^3 = x');   % y enters non-invertibly (sum of log and a cubic)
m3.exogenous('x', 1);
caught = false;
try
    m3.eliminate('y');
catch e
    caught = strcmp(e.identifier, 'modBuilder:eliminate:notClosedForm');
end
assert(caught, 'a non-closed-form variable must raise notClosedForm');

fprintf('eliminate/t01.m: eliminate OK\n');

% Equal up to algebra AND overall sign (a residual = 0 is unchanged by negation): expand+simplify
% the sum and the difference of the two residuals and accept if either vanishes.
function tf = same_equation(eqA, eqB)
    rA = residual_of(eqA);
    rB = residual_of(eqB);
    d1 = ast('binop', '-', {rA, rB}).expand().simplify();
    d2 = ast('binop', '+', {rA, rB}).expand().simplify();
    tf = (strcmp(d1.type, 'num') && abs(d1.value) < 1e-12) || ...
         (strcmp(d2.type, 'num') && abs(d2.value) < 1e-12);
end

function r = residual_of(eqstr)
    p = strsplit(eqstr, '=');
    if isscalar(p)
        r = ast(strtrim(p{1}));
    else
        r = ast('binop', '-', {ast(strtrim(p{1})), ast(strtrim(p{2}))});
    end
end
