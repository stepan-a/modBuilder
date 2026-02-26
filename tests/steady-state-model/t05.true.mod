var Y_1 Y_2 Y_3;

varexo K_1 K_2 K_3;

parameters A_1 A_2 A_3;

A_1 = 1.000000;
A_2 = 1.000000;
A_3 = 1.000000;

model;

[name = 'Y_1']
Y_1 = A_1*K_1;

[name = 'Y_2']
Y_2 = A_2*K_2;

[name = 'Y_3']
Y_3 = A_3*K_3;

end;

steady_state_model;

	Y_1 = A_1*K_1;
	Y_2 = A_2*K_2;
	Y_3 = A_3*K_3;

end;
