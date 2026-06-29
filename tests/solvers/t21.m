% Test newton_system: dimension mismatch must be reported.
% A dimension mismatch is a numerical-contract outcome, reported through
% flag=5 (not thrown). A NaN in x0 is a malformed input, still rejected by
% the arguments block.

% (a) residual_fn returns a 3-vector while x0 is 2-dimensional.
residual = @(v) [v(1); v(2); v(1)+v(2)];   % 3×1, but x is 2×1
jacobian = @(v) eye(2);

[x, fval, iter, flag] = solvers.newton_system(residual, jacobian, [0.5; 0.5]);
if flag ~= 5
    error('Expected flag=5 (dimension mismatch) on residual size, got %d', flag)
end

% (b) jacobian_fn returns a non-square matrix.
residual2 = @(v) v - 1;             % 2×1
jacobian2 = @(v) [1 0; 0 1; 1 1];   % 3×2 instead of 2×2

[x, fval, iter, flag] = solvers.newton_system(residual2, jacobian2, [0.5; 0.5]);
if flag ~= 5
    error('Expected flag=5 (dimension mismatch) on Jacobian size, got %d', flag)
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
