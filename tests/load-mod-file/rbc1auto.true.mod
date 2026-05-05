var a b h k c y;

varexo e (long_name='Productivity shock innovation')
	u (long_name='Preference shock innovation')
	;

parameters alpha $\alpha$
	rho $\rho$
	tau $\tau$
	beta $\beta$
	delta $\delta$
	psi $\psi$
	theta $\theta$
	phi $\phi$
	;

alpha = 0.360000;
rho = 0.950000;
tau = 0.025000;
beta = 0.990000;
delta = 0.025000;
psi = 0.000000;
theta = 2.950000;
phi = 0.100000;

model;

[name = 'a']
a = rho*a(-1)+tau*b(-1)+e;

[name = 'b']
b = tau*a(-1)+rho*b(-1)+u;

[name = 'h']
y = exp(a)*k(-1)^alpha*h^(1-alpha);

[name = 'k']
k = exp(b)*(y-c)+k(-1)*(1-delta);

[name = 'c']
c*theta*h^(1+psi) = y*(1-alpha);

[name = 'y']
1/beta = exp(b)*c/(exp(b(1))*c(1))*(1-delta+alpha*exp(b(1))*y(1)/k);

end;
