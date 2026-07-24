% A small RBC model, without steady state.
model = modBuilder();

model.add('a', 'a = rho*a(-1) + e');
model.add('y', 'y = exp(a)*k(-1)^alpha*h^(1-alpha)');
model.add('k', 'k = (1-delta)*k(-1) + i');
model.add('i', 'y = c + i');
model.add('c', '1/beta = c/c(+1)*(alpha*y(+1)/k + 1 - delta)');
model.add('h', 'theta*c*h^psi = (1-alpha)*y/h');

model.parameter('alpha', 0.36, 'texname', '\alpha');
model.parameter('beta',  0.99, 'texname', '\beta');
model.parameter('delta', 0.025, 'texname', '\delta');
model.parameter('rho',   0.95, 'texname', '\rho');
model.parameter('theta', 2.95, 'texname', '\theta');
model.parameter('psi',   1.00, 'texname', '\psi');

model.exogenous('e', 0, 'texname', '\varepsilon');
