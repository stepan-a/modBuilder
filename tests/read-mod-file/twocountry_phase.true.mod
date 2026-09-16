var A_1 y_1 k_1 h_1 x_1 A_2 y_2 k_2 h_2 x_2 c_1 c_2;

varexo e_1 e_2;

parameters rho alpha beta delta sigma phi chi omega;

rho = 0.900000;
alpha = 0.330000;
beta = 0.990000;
delta = 0.025000;
sigma = 2.000000;
phi = 1.500000;
chi = 1.000000;
omega = 1.200000;

model;

[name = 'A_1']
log(A_1) = rho*log(A_1(-1)) + e_1;

[name = 'y_1']
y_1 = A_1*k_1^alpha*h_1^(1-alpha);

[name = 'k_1']
c_1^(-sigma) = beta*c_1(+1)^(-sigma)*(alpha*y_1(+1)/k_1 + 1 - delta);

[name = 'h_1']
chi*h_1^phi = (1-alpha)*(y_1/h_1)*c_1^(-sigma);

[name = 'x_1']
k_1 = (1-delta)*k_1(-1) + x_1;

[name = 'A_2']
log(A_2) = rho*log(A_2(-1)) + e_2;

[name = 'y_2']
y_2 = A_2*k_2^alpha*h_2^(1-alpha);

[name = 'k_2']
c_2^(-sigma) = beta*c_2(+1)^(-sigma)*(alpha*y_2(+1)/k_2 + 1 - delta);

[name = 'h_2']
chi*h_2^phi = (1-alpha)*(y_2/h_2)*c_2^(-sigma);

[name = 'x_2']
k_2 = (1-delta)*k_2(-1) + x_2;

[name = 'c_1']
c_1^(-sigma) = omega*c_2^(-sigma);

[name = 'c_2']
y_1 + y_2 = c_1 + c_2 + x_1 + x_2;

end;

steady_state_model;

	A_1 = exp(e_1 / (1 - rho));
	A_2 = exp(e_2 / (1 - rho));
	x_1 = twocountry_phase_ssblock_3(chi, A_1, delta, alpha, beta, phi, sigma, omega, A_2);
	x_2 = ((1 - alpha) * (-(beta * chi / A_1 * delta ^ alpha / omega * x_1 ^ (-alpha) / (1 - alpha) * (-(A_1 ^ -1 / alpha * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) - A_1 ^ -1 / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) - A_1 ^ -1 * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) ^ (alpha / (1 - alpha) + phi / (1 - alpha))) + chi / A_1 * delta ^ alpha / omega * x_1 ^ (-alpha) / (1 - alpha) * (-(A_1 ^ -1 / alpha * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) - A_1 ^ -1 / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) - A_1 ^ -1 * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) ^ (alpha / (1 - alpha) + phi / (1 - alpha)) + beta * chi / A_1 * delta ^ (1 + alpha) / omega * x_1 ^ (-alpha) / (1 - alpha) * (-(A_1 ^ -1 / alpha * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) - A_1 ^ -1 / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) - A_1 ^ -1 * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) ^ (alpha / (1 - alpha) + phi / (1 - alpha))) * A_1 ^ (-(-1 - (alpha + phi) ^ -1 + alpha / (alpha + phi))) * A_2 ^ (-(1 - alpha / (alpha + phi) + (alpha + phi) ^ -1)) / alpha / beta / chi / delta * omega ^ (-(-1 - (alpha + phi) ^ -1 + alpha / (alpha + phi))) * x_1 ^ (-(-alpha - alpha / (alpha + phi) + alpha ^ 2 / (alpha + phi))) * (-(A_1 ^ -1 / alpha * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) - A_1 ^ -1 / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) - A_1 ^ -1 * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha / beta * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 / alpha * delta ^ alpha * x_1 ^ (1 - alpha) / (1 - alpha) + A_1 ^ -1 * delta ^ (-1 + alpha) * x_1 ^ (1 - alpha) / (1 - alpha)) ^ (-(-(alpha * phi / (1 - alpha) / (alpha + phi)) - alpha ^ 2 / (1 - alpha) / (alpha + phi) + alpha / (1 - alpha) + phi / (1 - alpha) + alpha / (1 - alpha) / (alpha + phi) + phi / (1 - alpha) / (alpha + phi)))) ^ ((-1 + alpha - alpha ^ 2 / (alpha + phi) + alpha / (alpha + phi)) ^ -1);
	h_1 = (x_1 * (1 - alpha) * (-(beta * chi / A_1 * delta ^ alpha * x_1 ^ (-alpha) / (1 - alpha)) + chi / A_1 * delta ^ alpha * x_1 ^ (-alpha) / (1 - alpha) + beta * chi / A_1 * delta ^ (1 + alpha) * x_1 ^ (-alpha) / (1 - alpha)) / alpha / beta / chi / delta) ^ ((1 - alpha) ^ -1);
	h_2 = (A_2 / A_1 * h_1 ^ (alpha + phi) / omega * (x_1 / delta) ^ (-alpha) * (x_2 / delta) ^ alpha) ^ ((alpha + phi) ^ -1);
	c_2 = (chi / A_2 * h_2 ^ (alpha + phi) * (x_2 / delta) ^ (-alpha) / (1 - alpha)) ^ (-sigma ^ -1);
	c_1 = (omega * c_2 ^ (-sigma)) ^ (-sigma ^ -1);
	k_2 = x_2 / delta;
	y_2 = A_2 * h_2 ^ (1 - alpha) * k_2 ^ alpha;
	k_1 = x_1 / delta;
	y_1 = A_1 * h_1 ^ (1 - alpha) * k_1 ^ alpha;

end;

steady;
