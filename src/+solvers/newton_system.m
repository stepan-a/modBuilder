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
% - x            [double]     n×1 approximate solution (best iterate reached)
% - fval         [double]     n×1 residual at x
% - iter         [integer]    scalar, number of outer iterations executed
% - flag         [integer]    scalar, exit status:
%                               0 = converged
%                               1 = max iterations exceeded
%                               2 = singular / non-finite Jacobian or residual
%                               3 = backtracking line-search failed
%                               5 = dimension mismatch
%
% REMARKS:
% Convergence is declared at the top of each iteration when the current
% residual already satisfies ||f(x)||_inf < tol. The line search uses an
% Armijo sufficient-decrease condition on ||f(x)||_inf and is bounded
% above by ls_max trials. The accepted residual is reused as the next
% iteration's starting residual, saving one residual_fn evaluation per
% outer iteration. Because a step is accepted only when it strictly reduces
% ||f(x)||_inf, the residual is monotone across iterations and no separate
% divergence test is needed.
%
% This solver does NOT throw on a numerical or dimension failure: every
% outcome is reported through flag, and (x, fval) hold the best iterate
% reached so the caller can diagnose the failure. Only malformed inputs
% (caught by the arguments block below) raise an error. Callers that need a
% solution must check flag ~= 0 — see modBuilder.solve_system, which turns a
% non-zero flag into a contextual modBuilder:solve_system:noConvergence error.
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

    n        = numel(x0);
    x        = x0;
    flag     = 1;
    iter     = 0;
    fx       = residual_fn(x);

    if ~isequal(size(fx), [n 1])
        flag = 5;
        fval = fx;
        return
    end

    for iter = 1:maxit
        if ~all(isfinite(fx))
            flag = 2;
            break
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
            break
        end
        if ~all(isfinite(J(:)))
            flag = 2;
            break
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
            % Jacobian singular or ill-conditioned: the Newton step is undefined.
            flag = 2;
            break
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
            % No sufficient-decrease step found: the step is not a descent
            % direction or the floor underflowed.
            flag = 3;
            break
        end

        x  = x_try;
        fx = fx_try;     % reuse: skip one residual_fn call next iteration
    end

    % The convergence test runs at the top of each iteration, so a step accepted
    % on the LAST allowed iteration that drives the residual below tolerance
    % would otherwise be reported as a max-iteration failure.
    if flag == 1 && all(isfinite(fx)) && norm(fx, inf) < tol
        flag = 0;
    end

    fval = fx;
end
