% Test chain rule: f(x) = exp(sin(x^2))

x0 = 0.5;
x = autoDiff1(x0);
f = exp(sin(x^2));

% Expected value and derivative
val_expected = exp(sin(x0^2));
der_expected = exp(sin(x0^2)) * cos(x0^2) * 2*x0;

assert(abs(f.x - val_expected) < 1e-12, 'Composition: incorrect value');
assert(abs(f.dx - der_expected) < 1e-12, 'Composition: incorrect derivative');
