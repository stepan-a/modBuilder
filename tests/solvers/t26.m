% Tests for newton() error path: non-finite residual/derivative

% f(x) = 1/x evaluated at x0 = 0 yields an infinite residual on the very
% first iterate, which must be reported as a non-finite-value error.
threw = false;
try
    solvers.newton(@(x) 1/x, 0, 1e-6, 50);
catch e
    threw = strcmp(e.identifier, 'modBuilder:newton:nonFinite');
end
assert(threw, 'Expected modBuilder:newton:nonFinite for an infinite residual.');
