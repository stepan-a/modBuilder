var b y c h k;

varexo u a;

parameters alpha rhob taub beta delta psi theta phi;

alpha = 0.360000;
rhob = 0.950000;
taub = 0.025000;
beta = 0.990000;
delta = 0.025000;
psi = 0.000000;
theta = 2.950000;
phi = 0.100000;

model;

// Eq. #1 -> b
b = taub*a(-1)+rhob*b(-1) + u;

// Eq. #2 -> y
y = exp(a)*(k(-1)^alpha)*(h^(1-alpha));

// Eq. #3 -> c
k = exp(b)*(y-c)+(1-delta)*k(-1);

// Eq. #4 -> h
c*theta*h^(1+psi)=(1-alpha)*y;

// Eq. #5 -> k
1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-delta));

end;
