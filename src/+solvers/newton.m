function [x, fval, iter] = newton(f, x0, tol, maxit)
% Nonlinear solver for a univariate equation (Newton approach).
%
% INPUTS:
% - f      [handle]     function returning the residual of the equation to be solved.
% - x0     [double]     scalar, initial condition
% - tol    [souble]     scalar, tolerance parameter
% - maxit  [integer]    scalar, maximum number of iterations
%
% OUTPUTS:
% - x      [double]     scalar, approximate solution
% - fval   [double]     scalar, f(x)
% - iter   [integer]    scalar, number of iterations
%
% REMARKS:
% Automatic differentiation is used (fowrward ).
    if nargin<4
        maxit = 100;
    end

    if nargin<3
        tol = 1e-6;
    end

    x0 = autoDiff1(x0);

    alpha = 1.0;

    iter = 1;

    while iter<=maxit
        r = f(x0);
        dx = -r.x / r.dx;
        while abs(f(x0 + alpha*dx))>abs(r)
            alpha = alpha/2.0;
            if alpha < 1e-6
                break
            end
        end
        x0 = x0 + alpha*dx;
        if abs(dx)<tol
            break
        end
        iter = iter+1;
    end
    x = x0.x;
    r = f(x0);
    fval = r.x;
end
