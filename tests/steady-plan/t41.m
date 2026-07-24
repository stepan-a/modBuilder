% apply_steady_plan(Jacobian=...): the generated helper obtains its Jacobian either
% by complex-step differentiation (default, when the residuals can be evaluated at a
% complex argument) or from the inlined symbolic derivatives. Both must solve the
% block; the choice must fall back automatically on a residual that complex-step
% cannot handle, and an explicit impossible request must fail loudly.

cleanup = onCleanup(@() cellfun(@delete_if_exists, ...
    {'t41c_ssblock_2.m', 't41s_ssblock_2.m', 't41a_ssblock_2.m'}));

% --- analytic residual: log(q) + q = z, no closed form, one unknown ---
m = modBuilder();
m.add('z', 'log(z) = rho*log(z(-1)) + ez');
m.add('q', 'log(q) + q = z + qbar');
m.parameter('rho', 0.5);
m.parameter('qbar', 2);
m.exogenous('ez', 0);
m.endogenous('q', 1);

pl = m.steady_plan(Match=true);

% Default (auto) must pick complex-step: the residual only uses log.
mc = m.copy();
mc.apply_steady_plan(pl, GenerateHelpers=true, Basename='t41c');
src = fileread('t41c_ssblock_2.m');
assert(contains(src, 'imag(block_residual('), 'auto must emit the complex-step Jacobian on an analytic residual');
assert(~contains(src, 'J(1, 1) ='), 'the complex-step variant must not inline a symbolic Jacobian');

% Forcing the symbolic strategy must inline the derivative instead.
ms = m.copy();
ms.apply_steady_plan(pl, GenerateHelpers=true, Basename='t41s', Jacobian='symbolic');
srcs = fileread('t41s_ssblock_2.m');
assert(contains(srcs, 'J(1, 1) ='), 'Jacobian=symbolic must inline the derivative');
assert(~contains(srcs, 'imag(block_residual('), 'Jacobian=symbolic must not use the complex step');

% Both must solve the block to the same root: log(q) + q = z + qbar with z = 1.
rho = 0.5; qbar = 2; ez = 0; %#ok<NASGU>
rehash;
qc = t41c_ssblock_2(1, qbar);
qs = t41s_ssblock_2(1, qbar);
assert(abs(log(qc) + qc - 1 - qbar) < 1e-9, 'complex-step helper must solve the block');
assert(abs(log(qs) + qs - 1 - qbar) < 1e-9, 'symbolic helper must solve the block');
assert(abs(qc - qs) < 1e-9, 'both strategies must reach the same root (got %g and %g)', qc, qs);

% --- non-analytic residual: abs() destroys the imaginary part ---
ma = modBuilder();
ma.add('z', 'log(z) = rho*log(z(-1)) + ez');
ma.add('q', 'log(q) + q + abs(q)/10 = z + qbar');
ma.parameter('rho', 0.5);
ma.parameter('qbar', 2);
ma.exogenous('ez', 0);
ma.endogenous('q', 1);
pla = ma.steady_plan(Match=true);

% auto must fall back to the symbolic Jacobian, silently and correctly.
maa = ma.copy();
maa.apply_steady_plan(pla, GenerateHelpers=true, Basename='t41a');
srca = fileread('t41a_ssblock_2.m');
assert(contains(srca, 'J(1, 1) ='), 'auto must fall back to the symbolic Jacobian when abs() is present');
assert(~contains(srca, 'imag(block_residual('), 'auto must not use the complex step on a non-analytic residual');

% Asking for complex-step explicitly on that block must raise, not downgrade.
threw = false;
try
    mae = ma.copy();
    mae.apply_steady_plan(pla, GenerateHelpers=true, Basename='t41e', Jacobian='complex-step');
catch err
    threw = strcmp(err.identifier, 'modBuilder:generate_ss_helper:notAnalytic');
end
assert(threw, 'Jacobian=complex-step must raise notAnalytic on a residual calling abs()');

% The eligibility test itself.
assert(isempty(ast.nonanalytic_calls(ast('log(q) + q - z'))), 'log/arithmetic must be complex-safe');
% (the walk order is unspecified, only the set matters)
assert(isempty(setxor(ast.nonanalytic_calls(ast('abs(q) + max(a, b)')), {'abs', 'max'})), ...
       'abs and max must be reported as complex-unsafe');

fprintf('steady-plan/t41: complex-step Jacobian, symbolic fallback and eligibility test OK\n');

function delete_if_exists(f)
    if exist(f, 'file') == 2
        delete(f);
    end
end
