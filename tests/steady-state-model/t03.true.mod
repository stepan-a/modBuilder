var x y z;

varexo e_x e_y e_z;

parameters a b c;

a = 1.000000;
b = 2.000000;
c = 3.000000;

model;

[name = 'x']
x = a + e_x;

[name = 'y']
y = b + e_y;

[name = 'z']
z = c + e_z;

end;

steady_state_model;

	z = c;
	x = a;
	y = b;

end;
