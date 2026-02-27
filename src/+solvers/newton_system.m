function [x, fval, iter] = newton_system(residual_fn, jacobian_fn, x0, tol, maxit)
% Nonlinear solver for a multivariate system (Newton approach with backtracking).
%
% INPUTS:
% - residual_fn  [handle]     function returning m×1 residual vector
% - jacobian_fn  [handle]     function returning m×n Jacobian matrix
% - x0           [double]     n×1 initial guess
% - tol          [double]     scalar, convergence tolerance (default 1e-6)
% - maxit        [integer]    scalar, maximum number of iterations (default 100)
%
% OUTPUTS:
% - x            [double]     n×1 approximate solution
% - fval         [double]     m×1 residual at solution
% - iter         [integer]    scalar, number of iterations

    if nargin < 5
        maxit = 100;
    end

    if nargin < 4
        tol = 1e-6;
    end

    x = x0(:);

    for iter = 1:maxit
        fx = residual_fn(x);
        J = jacobian_fn(x);
        dx = -J \ fx;

        % Backtracking line search
        alpha = 1.0;
        nfx = norm(fx);
        while norm(residual_fn(x + alpha*dx)) > nfx && alpha > 1e-6
            alpha = alpha / 2;
        end

        x = x + alpha * dx;

        if norm(dx) < tol
            break
        end
    end

    fval = residual_fn(x);
end
