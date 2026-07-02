% steady_plan: a block that is HOMOGENEOUS in its variables closes by a ratio
% change of variables (ratio_reduce). Single-variable elimination reports it as an
% irreducible 2-cycle; the ratio substitution triangularises it.
%
% wp*L/(rp*K) = cc pins the ratio L/K (homogeneous of degree 0); K^aa*L^(1-aa) = YY
% pins the scale. isolate gives K(L) from the first and L(K) from the second -- a
% spurious cycle. Writing L = rho*K makes K cancel in the first equation (solve rho),
% and K then falls out of the second: K = YY/(rho^(1-aa)).

m = modBuilder();
m.add('K', 'wp*L/(rp*K) - cc');
m.add('L', 'K^aa*L^(1-aa) - YY');
m.parameter('wp', 2);
m.parameter('rp', 1);
m.parameter('cc', 0.5);
m.parameter('aa', 0.3);
m.parameter('YY', 10);

b = m.steady_plan(Match=true);

% K and L are one simultaneous block that ratio_reduce closes completely.
cf = struct('var', {}, 'expr', {});
for k = 1:numel(b)
    if any(ismember({'K','L'}, b(k).vars))
        cf = b(k).closed_form;
    end
end
resolved = {cf.var};
assert(all(ismember({'K','L'}, resolved)), 'ratio_reduce must close both K and L');

% Numerical check: L/K = wp/(rp*cc) = 4, K = YY/(4^(1-aa)) via the closed forms.
vals = struct('wp',2,'rp',1,'cc',0.5,'aa',0.3,'YY',10);
for j = 1:numel(cf)
    vals.(cf(j).var) = ast(cf(j).expr).eval(vals);
end
assert(abs(vals.wp*vals.L/(vals.rp*vals.K) - vals.cc) < 1e-9, 'ratio equation must hold');
assert(abs(vals.K^vals.aa*vals.L^(1-vals.aa) - vals.YY) < 1e-9, 'scale equation must hold');

fprintf('steady-plan/t29: ratio_reduce closes a homogeneous block via K,L -> rho,K\n');
