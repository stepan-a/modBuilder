var y k;

varexo i;

parameters alpha delta;

alpha = 0.330000;
delta = 0.025000;

model;

[name = 'k']
k = (1-delta)*k(-1) + i;

[name = 'y']
y = alpha*k;

end;
