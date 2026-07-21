% steady_plan: KNIFE-EDGE calibrations are flagged -- the plan is symbolically
% regular but singular at the calibrated point, so the closed forms divide by a
% numerical zero and the levels are undetermined at this calibration only.
%
% Singleton flavour: b = R*b(-1) + x isolates to b = x/(1-R), whose pinning
% coefficient 1-R vanishes at R = 1. Block flavour: a jointly linear 2x2 block
% whose determinant 1-k^2 vanishes at k = 1; bareiss_triangulate only rules out
% symbolic singularity, so the back-substituted forms slip through.

m = modBuilder();
m.add('b', 'b - R*b(-1) - x');
m.parameter('R', 1);
m.exogenous('x', 0.1);

lastwarn('');
m.steady_plan(Match=true);
[msg, id] = lastwarn();
assert(strcmp(id, 'modBuilder:steady_plan:calibrationUnitRoot'), 'R = 1 must raise the calibrationUnitRoot warning');
assert(contains(msg, 'b'), 'the warning must name the knife-edge variable');

% Same equation off the knife edge: closed form b = x/(1-R), no warning.
m2 = modBuilder();
m2.add('b', 'b - R*b(-1) - x');
m2.parameter('R', 0.5);
m2.exogenous('x', 0.1);

lastwarn('');
b2 = m2.steady_plan(Match=true);
[~, id] = lastwarn();
assert(~strcmp(id, 'modBuilder:steady_plan:calibrationUnitRoot'), 'R = 0.5 must stay silent');
assert(numel(b2) == 1 && numel(b2(1).closed_form) == 1, 'the stationary accumulation must close');
vals = struct('R', 0.5, 'x', 0.1);
assert(abs(ast(b2(1).closed_form(1).expr).eval(vals) - 0.2) < 1e-12, 'b* must be x/(1-R) = 0.2');

% Simultaneous block singular at the calibration only: det = 1 - k^2, k = 1.
% The constants are parameters, not innovations: fed by exogenous innovations the
% pair would be detected as a VAR driving process (two anchor singletons) and
% would never reach the Bareiss path.
m3 = modBuilder();
m3.add('u', 'u - k*v - a1');
m3.add('v', 'v - k*u - a2');
m3.parameter('k', 1);
m3.parameter('a1', 0.1);
m3.parameter('a2', 0.2);

lastwarn('');
m3.steady_plan(Match=true);
[~, id] = lastwarn();
assert(strcmp(id, 'modBuilder:steady_plan:calibrationUnitRoot'), 'k = 1 must raise the calibrationUnitRoot warning on the block');

% Same block off the knife edge: closed and consistent, no warning.
m4 = modBuilder();
m4.add('u', 'u - k*v - a1');
m4.add('v', 'v - k*u - a2');
m4.parameter('k', 0.5);
m4.parameter('a1', 0.1);
m4.parameter('a2', 0.2);

lastwarn('');
b4 = m4.steady_plan(Match=true);
[~, id] = lastwarn();
assert(~strcmp(id, 'modBuilder:steady_plan:calibrationUnitRoot'), 'k = 0.5 must stay silent');
vals = struct('k', 0.5, 'a1', 0.1, 'a2', 0.2);
for kk = 1:numel(b4)
    for j = 1:numel(b4(kk).closed_form)
        vals.(b4(kk).closed_form(j).var) = ast(b4(kk).closed_form(j).expr).eval(vals);
    end
end
assert(abs(vals.u - vals.k*vals.v - vals.a1) < 1e-12, 'u equation must hold at the recovered point');
assert(abs(vals.v - vals.k*vals.u - vals.a2) < 1e-12, 'v equation must hold at the recovered point');

fprintf('steady-plan/t37: knife-edge calibrations are flagged, regular calibrations stay silent\n');
