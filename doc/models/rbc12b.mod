var a b y c h k;

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

alpha = 0.360000; rho = 0.950000; tau = 0.025000;
beta = 0.990000; delta = 0.025000; psi = 0.000000;
theta = 2.950000; phi = 0.100000;

model;

[endogenous = 'a']
a = rho*a(-1)+tau*b(-1)+e;

[endogenous = 'b']
b = tau*a(-1)+rho*b(-1)+u;

[endogenous = 'y']
y = exp(a)*k(-1)^alpha*h^(1-alpha);

[endogenous = 'c']
k = exp(b)*(y-c)+k(-1)*(1-delta);

[endogenous = 'h']
c*theta*h^(1+psi) = y*(1-alpha);

[endogenous = 'k']
1/beta = exp(b)*c/(exp(b(1))*c(1))*(1-delta+alpha*exp(b(1))*y(1)/k);

end;
