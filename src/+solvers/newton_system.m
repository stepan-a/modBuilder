function [x, fval, iter, flag] = newton_system(residual_fn, jacobian_fn, x0, tol, maxit)
% Nonlinear solver for a multivariate square system (Newton with line search).
%
% INPUTS:
% - residual_fn  [handle]     function returning n×1 residual vector
% - jacobian_fn  [handle]     function returning n×n Jacobian matrix
% - x0           [double]     n×1 initial guess
% - tol          [double]     scalar, convergence tolerance (default 1e-6)
% - maxit        [integer]    scalar, maximum number of iterations (default 100)
%
% OUTPUTS:
% - x            [double]     n×1 approximate solution
% - fval         [double]     n×1 residual at solution
% - iter         [integer]    scalar, number of outer iterations executed
% - flag         [integer]    scalar, exit status:
%                               0 = converged
%                               1 = max iterations exceeded
%                               2 = singular / non-finite Jacobian
%                               3 = backtracking line-search failed
%                               4 = divergence detected
%                               5 = dimension mismatch
%
% REMARKS:
% Convergence is declared at the top of each iteration when the current
% residual already satisfies ||f(x)||_inf < tol. The line search uses an
% Armijo sufficient-decrease condition on ||f(x)||_inf and is bounded
% above by ls_max trials. The accepted residual is reused as the next
% iteration's starting residual, saving one residual_fn evaluation per
% outer iteration.
    arguments
        residual_fn (1,1) function_handle
        jacobian_fn (1,1) function_handle
        x0          (:,1) double {mustBeFinite, mustBeReal}
        tol         (1,1) double {mustBePositive}            = 1e-6
        maxit       (1,1) double {mustBePositive, mustBeInteger} = 100
    end

    armijo_c1   = 1e-4;
    alpha_floor = 1e-10;
    ls_max      = 50;
    div_factor  = 10;
    div_warmup  = 3;

    n        = numel(x0);
    x        = x0;
    flag     = 1;
    fx       = residual_fn(x);

    if ~isequal(size(fx), [n 1])
        flag = 5;
        error('modBuilder:newtonSystem:dimMismatch', ...
              'residual_fn returned size %s, expected [%d 1].', mat2str(size(fx)), n);
    end

    prev_res = Inf;

    for iter = 1:maxit
        if ~all(isfinite(fx))
            flag = 2;
            error('modBuilder:newtonSystem:nonFiniteResidual', ...
                  'Residual contains non-finite values at iter %d.', iter);
        end

        % Residual-based convergence test. Done first, so an iterate that
        % is already at or near the root exits cleanly without entering a
        % line search that has no headroom below machine epsilon.
        if norm(fx, inf) < tol
            flag = 0;
            break
        end

        J = jacobian_fn(x);
        if ~isequal(size(J), [n n])
            flag = 5;
            error('modBuilder:newtonSystem:dimMismatch', ...
                  'jacobian_fn returned size %s, expected [%d %d].', ...
                  mat2str(size(J)), n, n);
        end
        if ~all(isfinite(J(:)))
            flag = 2;
            error('modBuilder:newtonSystem:nonFiniteJacobian', ...
                  'Jacobian contains non-finite values at iter %d.', iter);
        end

        % Solve J*dx = -fx. Detect singularity by checking finiteness of
        % the result (works for both full and sparse Jacobians; avoids the
        % rcond/condest dispatch and remains cheap for large systems).
        wstate    = warning('query');
        cleanupWS = onCleanup(@() warning(wstate));
        warning('off', 'MATLAB:singularMatrix');
        warning('off', 'MATLAB:nearlySingularMatrix');
        dx = -J \ fx;
        clear cleanupWS;

        if ~all(isfinite(dx))
            flag = 2;
            error('modBuilder:newtonSystem:singularJacobian', ...
                  'Jacobian singular or ill-conditioned at iter %d.', iter);
        end

        % Backtracking line search with Armijo condition (inf norm).
        alpha    = 1.0;
        nfx      = norm(fx, inf);
        accepted = false;
        x_try    = x;
        fx_try   = fx;
        for ls = 1:ls_max
            x_try  = x + alpha*dx;
            fx_try = residual_fn(x_try);
            if all(isfinite(fx_try)) && ...
               norm(fx_try, inf) <= (1 - armijo_c1*alpha)*nfx
                accepted = true;
                break
            end
            alpha = alpha / 2;
            if alpha < alpha_floor
                break
            end
        end
        if ~accepted
            flag = 3;
            error('modBuilder:newtonSystem:lineSearchFailed', ...
                  'Backtracking failed at iter %d.', iter);
        end

        x  = x_try;
        fx = fx_try;     % reuse: skip one residual_fn call next iteration

        % Divergence test (after a short warmup).
        if iter > div_warmup && norm(fx, inf) > div_factor*prev_res
            flag = 4;
            error('modBuilder:newtonSystem:diverging', ...
                  'Residual norm grew from %g to %g at iter %d.', ...
                  prev_res, norm(fx, inf), iter);
        end
        prev_res = norm(fx, inf);
    end

    fval = fx;
end
