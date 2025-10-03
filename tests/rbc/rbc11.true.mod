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
	;

alpha = 0.360000;
rho = 0.950000;
tau = 0.025000;
beta = 0.990000;
delta = 0.025000;
psi = 0.000000;
theta = 2.950000;

model;

[name = 'a']
a = rho*a(-1)+tau*b(-1) + e;

[name = 'b']
b = tau*a(-1)+rho*b(-1) + u;

[name = 'y']
y = exp(a)*(k(-1)^alpha)*(h^(1-alpha));

[name = 'c']
k = exp(b)*(y-c)+(1-delta)*k(-1);

[name = 'h']
c*theta*h^(1+psi)=(1-alpha)*y;

[name = 'k']
1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-delta));

end;
