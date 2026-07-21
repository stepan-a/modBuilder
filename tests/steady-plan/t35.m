% steady_plan: a unit-root process is flagged -- the equation pins the growth rate,
% not the level, and the user must fix the level (declared value or anchor).
%
% Two flavours reach the diagnostic: the literal random walk log(Z) - log(Z(-1)) - ez,
% whose Z occurrences cancel outright when the static residual is simplified, and the
% split-persistence form log(Z) - (1-lam)*log(Z(-1)) - lam*log(Z(-1)) - ez, whose
% symbolic coefficients only cancel once the invertible-call recogniser sums them.

m = modBuilder();
m.add('Z', 'log(Z) - log(Z(-1)) - ez');
m.add('Y', 'Y - Z*K^alpha');
m.add('K', 'K - s*Y');
m.parameter('alpha', 0.3);
m.parameter('s', 0.2);
m.exogenous('ez', 0);

lastwarn('');
b = m.steady_plan(Match=true);
[msg, id] = lastwarn();
assert(strcmp(id, 'modBuilder:steady_plan:unitRoot'), 'the random walk must raise the unitRoot warning');
assert(contains(msg, '"Z"') || contains(msg, ' Z'),   'the warning must name the unit-root variable');
for k = 1:numel(b)
    if isequal(b(k).vars, {'Z'})
        assert(isempty(b(k).closed_form), 'no closed form must be derived for the unit-root process');
    end
end

m2 = modBuilder();
m2.add('Z', 'log(Z) - (1-lam)*log(Z(-1)) - lam*log(Z(-1)) - ez');
m2.add('Y', 'Y - Z*K^alpha');
m2.add('K', 'K - s*Y');
m2.parameter('lam', 0.4);
m2.parameter('alpha', 0.3);
m2.parameter('s', 0.2);
m2.exogenous('ez', 0);

lastwarn('');
m2.steady_plan(Match=true);
[~, id] = lastwarn();
assert(strcmp(id, 'modBuilder:steady_plan:unitRoot'), 'symbolic zero-sum coefficients must raise the unitRoot warning');

% A stationary process must stay silent.
m3 = modBuilder();
m3.add('Z', 'log(Z) - rho*log(Z(-1)) - ez');
m3.add('Y', 'Y - Z*K^alpha');
m3.add('K', 'K - s*Y');
m3.parameter('rho', 0.9);
m3.parameter('alpha', 0.3);
m3.parameter('s', 0.2);
m3.exogenous('ez', 0);

lastwarn('');
m3.steady_plan(Match=true);
[~, id] = lastwarn();
assert(~strcmp(id, 'modBuilder:steady_plan:unitRoot'), 'a stationary AR process must not raise the unitRoot warning');

fprintf('steady-plan/t35: unit-root processes are flagged, the level is left to the user\n');
