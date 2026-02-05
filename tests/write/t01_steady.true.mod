var y;

varexo x;

parameters alpha beta;

alpha = 0.333333;
beta = 3.141593;

model;

[name = 'y']
y = alpha*x + beta;

end;

initval;

	y = 0.142857;

end; // initval block

steady;
