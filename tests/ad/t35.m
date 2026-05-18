% Test overloaded ln function (alias of log).
% ln is listed in dynare_reserved_function_names, so ast.eval would feval
% 'ln' on an autoDiff1 operand when an equation contains ln(...). Without
% the alias the call would fail to resolve. Verify value, derivative, and
% equivalence with log() on the same input.

a = autoDiff1(2, 3);
c = ln(a);
assert(abs(c.x  - log(2)) < 1e-12 && ...
       abs(c.dx - 3/2)    < 1e-12, 'ln failed');

% Equivalence with log on the same operand.
c_log = log(a);
assert(c.x == c_log.x && c.dx == c_log.dx, 'ln should be exactly equivalent to log');

% Domain error must propagate (delegates to log).
threw = false;
try
    ln(autoDiff1(-1, 1));
catch
    threw = true;
end
assert(threw, 'ln of a non-positive value should error (via log)');
