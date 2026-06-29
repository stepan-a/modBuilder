% Tests for newton() error path: non-finite residual/derivative

% f(x) = 1/x evaluated at x0 = 0 yields an infinite residual on the very
% first iterate, which must be reported through flag=2 (no value found),
% NOT thrown.
[x, fval, iter, flag] = solvers.newton(@(x) 1/x, 0, 1e-6, 50);
assert(flag == 2, 'Expected flag=2 (non-finite residual), got %d', flag);
