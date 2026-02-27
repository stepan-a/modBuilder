% Test uminus and uplus in compound AD expressions
x = autoDiff1(2.0);

% -x * x = -4, d/dx(-x*x) = -2x = -4
y = -x * x;
if abs(y.x - (-4.0)) > 1e-12 || abs(y.dx - (-4.0)) > 1e-12
    error('uminus in compound expression failed: got x=%g dx=%g', y.x, y.dx)
end

% +(-x) = -x, value = -2, dx = -1
z = +(-x);
if abs(z.x - (-2.0)) > 1e-12 || abs(z.dx - (-1.0)) > 1e-12
    error('uplus(uminus) failed: got x=%g dx=%g', z.x, z.dx)
end
