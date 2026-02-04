var y;

varexo x;

parameters alpha beta;

alpha = 0.3333333333;
beta = 3.141592654;

model;

[name = 'y']
y = alpha*x + beta;

end;

initval;

	y = 0.1428571429;

end; // initval block
