function [x, fval, iter, flag] = newton(f, x0, tol, maxit)
% Nonlinear solver for a univariate equation (Newton with line search).
%
% INPUTS:
% - f      [handle]     function returning the residual of the equation to be solved.
% - x0     [double]     scalar, initial condition
% - tol    [double]     scalar, tolerance parameter (default 1e-6)
% - maxit  [integer]    scalar, maximum number of iterations (default 100)
%
% OUTPUTS:
% - x      [double]     scalar, approximate solution (best iterate reached)
% - fval   [double]     scalar, f(x)
% - iter   [integer]    scalar, number of outer iterations executed
% - flag   [integer]    scalar, exit status:
%                         0 = converged
%                         1 = max iterations exceeded
%                         2 = singular / non-finite Jacobian or residual
%                         3 = backtracking line-search failed
%
% REMARKS:
% Forward-mode automatic differentiation is used (autoDiff1). The line
% search uses an Armijo sufficient-decrease condition on |f(x)|. Because a
% step is accepted only when it strictly reduces |f(x)|, the residual is
% monotone across iterations and no separate divergence test is needed.
% Convergence is declared at the top of each iteration when the current
% residual already satisfies |f(x)| < tol; this avoids re-running the
% line search at machine-epsilon residual where Armijo's relative test
% has no headroom below eps.
%
% This solver does NOT throw on a numerical failure: every outcome is
% reported through flag, and (x, fval) hold the best iterate reached so the
% caller can diagnose the failure. Only malformed inputs (caught by the
% arguments block below) raise an error. Callers that need a solution must
% check flag ~= 0 — see modBuilder.solve, which turns a non-zero flag into a
% contextual modBuilder:solve:noConvergence error.
    arguments
        f      (1,1) function_handle
        x0     (1,1) double {mustBeFinite, mustBeReal}
        tol    (1,1) double {mustBePositive}            = 1e-6
        maxit  (1,1) double {mustBePositive, mustBeInteger} = 100
    end

    armijo_c1   = 1e-4;
    alpha_floor = 1e-10;
    ls_max      = 50;

    x_ad     = autoDiff1(x0);     % seed: dx = 1
    flag     = 1;                  % presume max-iter exit
    r        = f(x_ad);

    for iter = 1:maxit
        if ~isfinite(r.x) || ~isfinite(r.dx)
            % Residual or derivative blew up (e.g. f(x) = 1/x at x = 0).
            flag = 2;
            break
        end

        % Residual-based convergence test. Done first, so an iterate that
        % is already at or near the root (e.g. after the previous step
        % drove the residual to machine precision) exits cleanly without
        % a line search that cannot find any sufficient-decrease step.
        if abs(r.x) < tol
            flag = 0;
            break
        end

        if abs(r.dx) < eps*max(1, abs(r.x))
            % Derivative ~0: the Newton step is undefined (singular Jacobian).
            flag = 2;
            break
        end

        dx_step = -r.x / r.dx;

        % Backtracking line search with Armijo condition.
        alpha = 1.0;
        phi0  = abs(r.x);
        accepted = false;
        trial = r;
        for ls = 1:ls_max
            trial = f(x_ad + alpha*dx_step);
            if isfinite(trial.x) && abs(trial.x) <= (1 - armijo_c1*alpha)*phi0
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
            % direction (e.g. wrong-sign derivative) or the floor underflowed.
            flag = 3;
            break
        end

        x_ad = x_ad + alpha*dx_step;
        r    = trial;                 % reuse residual at accepted point
    end

    % The convergence test runs at the top of each iteration, so a step accepted
    % on the LAST allowed iteration that drives the residual below tolerance
    % would otherwise be reported as a max-iteration failure.
    if flag == 1 && isfinite(r.x) && abs(r.x) < tol
        flag = 0;
    end

    x    = x_ad.x;
    fval = r.x;
end
