% Test newton_system: dimension mismatch must be reported.

% (a) residual_fn returns a 3-vector while x0 is 2-dimensional.
residual = @(v) [v(1); v(2); v(1)+v(2)];   % 3×1, but x is 2×1
jacobian = @(v) eye(2);

threw = false;
try
    [x, fval, iter, flag] = solvers.newton_system(residual, jacobian, [0.5; 0.5]);
catch e
    threw = true;
    if ~strcmp(e.identifier, 'modBuilder:newtonSystem:dimMismatch')
        error('Expected modBuilder:newtonSystem:dimMismatch, got %s', e.identifier)
    end
end
if ~threw
    error('newton_system should have thrown on residual dimension mismatch')
end

% (b) jacobian_fn returns a non-square matrix.
residual2 = @(v) v - 1;             % 2×1
jacobian2 = @(v) [1 0; 0 1; 1 1];   % 3×2 instead of 2×2

threw = false;
try
    [x, fval, iter, flag] = solvers.newton_system(residual2, jacobian2, [0.5; 0.5]);
catch e
    threw = true;
    if ~strcmp(e.identifier, 'modBuilder:newtonSystem:dimMismatch')
        error('Expected modBuilder:newtonSystem:dimMismatch, got %s', e.identifier)
    end
end
if ~threw
    error('newton_system should have thrown on Jacobian dimension mismatch')
end

% (c) NaN in x0 must be rejected by the arguments block (mustBeFinite).
threw = false;
try
    solvers.newton_system(residual2, @(v) eye(2), [NaN; 1.0]);
catch
    threw = true;
end
if ~threw
    error('newton_system should reject NaN in x0')
end
