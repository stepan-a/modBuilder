% Test that ln(...) in an equation is evaluable numerically.
% ast.eval dispatches 'call' nodes via feval(name, args{:}); 'ln' is
% listed in dynare_reserved_function_names, so the parser produces a
% 'call' node with name 'ln'. With src/missing/math/ln.m on the path,
% feval('ln', x) for plain numeric x resolves to log(x).

m = modBuilder();
m.add('y', 'y = ln(x)');
m.exogenous('x', exp(1));
m.endogenous('y', 1.0);

evaleq = m.evaluate('y');
assert(abs(evaleq.lhs   - 1) < 1e-12, 'LHS y should be 1.0');
assert(abs(evaleq.rhs   - 1) < 1e-12, 'RHS ln(e) should be 1.0');
assert(abs(evaleq.resid)     < 1e-12, 'residual should be ~0');

% Same equation re-evaluated with x = 1 ⇒ ln(1) = 0.
m.exogenous('x', 1.0);
m.endogenous('y', 0.0);
evaleq = m.evaluate('y');
assert(abs(evaleq.rhs)   < 1e-12, 'ln(1) should be 0');
assert(abs(evaleq.resid) < 1e-12, 'residual should be ~0');

% Non-positive argument: the numeric path mirrors MATLAB's built-in log,
% which returns a complex value (ln(-1) = i*pi). This differs from the
% autoDiff1 path which errors on non-positive input — checked in ad/t35.
m.exogenous('x', -1.0);
evaleq = m.evaluate('y');
assert(~isreal(evaleq.rhs),                'ln(-1) should be non-real on the numeric path');
assert(abs(imag(evaleq.rhs) - pi) < 1e-12, 'ln(-1) should have imag part pi');
