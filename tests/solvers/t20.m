% Test newton_system: singular Jacobian must be detected.
% J is rank-deficient (second row is twice the first). The solver must
% report this through flag=2 (no value found), NOT throw.

residual = @(v) [v(1) + v(2) - 1; 2*v(1) + 2*v(2) - 3];
jacobian = @(v) [1 1; 2 2];

[x, fval, iter, flag] = solvers.newton_system(residual, jacobian, [0.5; 0.5], 1e-6, 20);

if flag ~= 2
    error('Expected flag=2 (singular Jacobian), got %d', flag)
end
if ~all(isfinite(fval))
    error('residual should remain finite')
end
