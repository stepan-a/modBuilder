% simplify: power-of-power collapse and sign-aware power collection.
%
% (x^a)^b -> x^(a*b) under the positive-base convention (excluded: even integer
% inner exponent with non-integer outer, where the collapse would drop |.|);
% (-x)^n for integer n pulls the sign out; and collect_powers matches bases
% MODULO SIGN when exponents are integers, so (1-b) cancels against (-1+b)^(-1)
% with the quotient -1. Together these collapse the nested-power closed forms
% isolate produces for AR shock levels and indexation identities, e.g.
% InflationFactor = (((IT^(1-g))^(1-t))^-1)^((-1+g)^-1/(1-t)) -> IT.

addpath ../utils

checks = { ...
  '(x^a)^b',                                        'x ^ (a * b)'; ...
  '(x^-1)^e',                                       'x ^ (-e)'; ...
  '((x^2)^3)',                                      'x ^ 6'; ...
  '(-x)^3',                                         '-x ^ 3'; ...
  '(-x)^2',                                         'x ^ 2'; ...
  '(1-b)/(-1+b)',                                   '-1'; ...
  '(2-c)*(-2+c)',                                   '-(2 - c) ^ 2'; ...
  '(((x^(1-g))^(1-t))^-1)^((-1+g)^-1/(1-t))',       'x'};
for i = 1:size(checks, 1)
    got = ast(checks{i,1}).simplify().string();
    assert(strcmp(got, checks{i,2}), 'simplify(%s) = "%s", expected "%s"', checks{i,1}, got, checks{i,2});
end

% Guard: (x^2)^0.5 is |x|, NOT x -- the collapse must not apply.
got = ast('(x^2)^0.5').simplify().string();
assert(~strcmp(got, 'x'), '(x^2)^0.5 must not collapse to x');

% Numerical safety net on a sign-cancelling quotient.
v = ast('(1-b)^2/(-1+b)').simplify().eval(struct('b', 0.25));
assert(abs(v - (1-0.25)^2/(-1+0.25)) < 1e-12, 'sign-aware collection must preserve the value');

fprintf('ast/t33: power-of-power collapse and sign-aware power collection\n');
