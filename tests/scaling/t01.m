% scaling_symmetries: detect the scale freedoms of the steady-state system by
% homogeneity analysis of the static residuals (exponent null space).
%
% Y = K^alpha*L^(1-alpha), K = phi*Y, L = psi*Y is scale-free: multiplying Y, K, L
% by a common factor leaves every equation homogeneous (degree 1). The analysis
% must find exactly one symmetry, scaling Y, K, L with equal exponent.

m = modBuilder();
m.add('Y', 'Y = K^alpha*L^(1-alpha)');
m.add('K', 'K = phi*Y');
m.add('L', 'L = psi*Y');
m.parameter('alpha', 0.3);
m.parameter('phi', 2);
m.parameter('psi', 3);

sym = m.scaling_symmetries();
assert(numel(sym) == 1, 'expected exactly one scale symmetry, got %d', numel(sym));

% All three variables participate with the same (non-zero) exponent.
s = sym(1);
assert(numel(s.vars) == 3, 'the symmetry must involve Y, K and L');
assert(all(ismember({'Y', 'K', 'L'}, s.vars)), 'Y, K, L must all be in the symmetry');
assert(all(abs(s.exponents - s.exponents(1)) < 1e-9), 'Y, K, L must share one scaling exponent');
assert(abs(s.exponents(1)) > 1e-9, 'the shared exponent must be non-zero');

% An additive constant breaks the scale freedom: no non-trivial symmetry remains.
m2 = modBuilder();
m2.add('Y', 'Y = K^alpha*L^(1-alpha) + 1');
m2.add('K', 'K = phi*Y');
m2.add('L', 'L = psi*Y');
m2.parameter('alpha', 0.3);
m2.parameter('phi', 2);
m2.parameter('psi', 3);
sym2 = m2.scaling_symmetries();
assert(isempty(sym2), 'an additive constant must pin the scale (no symmetry), got %d', numel(sym2));

% A level parameter pins the scale (as in SW): with L = L_bar, the endogenous-only
% analysis finds no symmetry, but letting parameters scale (IncludeParameters)
% reveals the latent symmetry tying Y, K, L and the level parameter L_bar.
m3 = modBuilder();
m3.add('Y', 'Y = K^alpha*L^(1-alpha)');
m3.add('K', 'K = phi*Y');
m3.add('L', 'L = L_bar');
m3.parameter('alpha', 0.3);
m3.parameter('phi', 2);
m3.parameter('L_bar', 0.3);
assert(isempty(m3.scaling_symmetries()), 'a level parameter must pin the scale');
latent = m3.scaling_symmetries(IncludeParameters=true);
assert(~isempty(latent), 'latent analysis must reveal the scaling structure');
% Among the co-scaling groups, one ties the extensive variables to the level
% parameter L_bar (other groups may rescale proportionality coefficients like phi).
ties_scale = arrayfun(@(s) all(ismember({'Y', 'K', 'L', 'L_bar'}, s.vars)), latent);
assert(any(ties_scale), 'a co-scaling group must tie Y, K, L and the level parameter L_bar');

fprintf('scaling/t01: scale symmetry detected; additive constant and level parameter pin it\n');
