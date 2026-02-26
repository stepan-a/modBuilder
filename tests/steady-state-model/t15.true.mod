var y c k w;

varexo ;

parameters alpha beta delta labor_share;

alpha = 0.360000;
beta = 0.990000;
delta = 0.025000;

model;

[name = 'y']
y = k^alpha;

[name = 'c']
c = y - delta*k;

[name = 'k']
1/beta = alpha*y(+1)/k + (1-delta);

[name = 'w']
w = labor_share*y;

end;

steady_state_model;

	k = (alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha));
	y = k^alpha;
	c = y - delta*k;
	labor_share = 1 - alpha*y/k;

end;
