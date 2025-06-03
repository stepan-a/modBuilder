var y c h k;

varexo a b;

parameters alpha beta delta psi theta;

alpha = 0.360000;
beta = 0.990000;
delta = 0.025000;
psi = 0.000000;
theta = 2.950000;

model;

// Eq. #1 -> y
y = exp(a)*(k(-1)^alpha)*(h^(1-alpha));

// Eq. #2 -> c
k = exp(b)*(y-c)+(1-delta)*k(-1);

// Eq. #3 -> h
c*theta*h^(1+psi)=(1-alpha)*y;

// Eq. #4 -> k
1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-delta));

end;
