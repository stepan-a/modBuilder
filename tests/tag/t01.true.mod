var Y_1 Y_2;

varexo K_1 K_2;

parameters A_1 A_2 alpha;

A_1 = 1.000000;
A_2 = 1.000000;
alpha = 0.330000;

model;

[name = 'Y_1', desc = 'Production function for sector 1']
Y_1 = A_1*K_1^alpha;

[name = 'Y_2', desc = 'Production function for sector 2']
Y_2 = A_2*K_2^alpha;

end;
