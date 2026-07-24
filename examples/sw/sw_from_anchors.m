% sw_from_anchors.m -- Showcase: derive the FULL SW steady state from DECLARED ANCHORS.
%
% Instead of hand-writing the analytical steady_state_model, we declare the seven
% steady-state values a modeller knows before touching the model -- two wage
% normalisations of the symmetric equilibrium, the efficient Tobin's Q, capacity
% utilisation and its efficient twin, the inverse markup and the hours scale --
% and let steady_plan(Match, Anchors, PropagateKnown) derive the other 54 in
% closed form.
% Every anchor value is a normalisation, a markup or a calibration constant: no
% algebra is written here that the plan could have done itself.
%
% Nothing is declared for the exogenous processes: the plan identifies them
% structurally, makes each an anchor of its own and solves its ARMA equation for
% the level parameter it carries, before anything downstream is attempted. Those
% levels stay symbolic in the derived forms, which therefore hold for any
% calibration of them and not only for unit shocks.
%
% Capacity utilisation is anchored rather than the capital return rate, although
% the latter is what a hand derivation writes down. Equations 5-8 pin utilisation
% only through delta_ss*exp(kappa*(z-z_ss))*(kappa*z-1) = g^sigmac/beta - 1, an
% exponential times a linear factor: no elementary closed form, and z = z_ss is a
% root only because depreciation_curvature is calibrated to make it one (see the
% derived parameters at the top of sw.m). That identity lives in the calibration,
% not in the model, so the plan sees unrelated numbers and cannot discover the
% root -- whereas anchoring z, which is what the modeller actually normalised,
% leaves the depreciation rate, its derivative and the capital return rate to be
% derived, and turns the capital FOC into the consistency condition the anchor
% absorbs.
%
% The scale-free Calvo recursion blocks (Z's, H's) are closed by the gauge
% backout: their ratios come from the block equations, their level from a
% consistency equation absorbed by the anchors (aggregate production for GDP,
% labour-market clearing for the wage recursions) -- exactly the hand technique of
% solving in ratios and backing the level out of a discarded equation.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'src'));
addpath(fullfile(here, 'matlab'));
cd(here);
SW_BUILD_ONLY = true; sw; clear SW_BUILD_ONLY   % build the model, NO steady block

% --- 1. Declare the anchors and their known values ---
anchors = { ...
    'AveragedRelativeWages',              '1';                               ... % no wage dispersion at the
    'OptimalRelativeRealWage',            '1';                               ... % symmetric equilibrium
    'EfficientTobinQ',                    '1';                               ... % no adjustment cost when efficient
    'CapacityUtilizationFactor',          'capacity_utilization_factor_ss';  ... % calibration constant
    'EfficientCapacityUtilizationFactor', 'capacity_utilization_factor_ss';  ...
    'RealMarginalCost',                   '(thetaf-1)/thetaf';               ... % inverse steady-state markup
    'HouseholdLabourSupply',              'household_labour_supply_ss'};         % hours scale
declared = anchors(:,1)';
% The values are inlined into the residuals by the known-value propagation before
% the recognisers run.
for i = 1:size(anchors,1), m.steady(anchors{i,1}, anchors{i,2}); end

% --- 2. Structural plan: shocks auto-detected, declared values pulled out ---
b = m.steady_plan(Match=true, Anchors=declared, PropagateKnown=true);

nvar = size(m.var,1);
auto = 0; closed = 0;
for k = 1:numel(b)
    if strcmp(b(k).kind,'anchor')
        if ~ismember(b(k).vars{1}, declared), auto = auto + numel(b(k).vars); end
    else
        closed = closed + numel(b(k).closed_form);
    end
end
fprintf('\n==== SW steady state from anchors ====\n');
fprintf('  total endogenous variables      : %d\n', nvar);
fprintf('  shocks auto-identified (exo)     : %d\n', auto);
fprintf('  anchors declared (known values)  : %d\n', numel(declared));
fprintf('  derived in CLOSED FORM by plan   : %d\n', closed);
fprintf('  residual (numerical solve needed): %d\n', modBuilder.total_residual_count(b));

% --- 3. Scale-free blocks closed by the gauge backout ---
for k = 1:numel(b)
    if isempty(b(k).backout), continue; end
    fprintf('\n  gauge backout in block {%s}:\n', strjoin(b(k).vars, ', '));
    % A block with several independent scales reports one gauge per closed scale.
    gauges = b(k).backout.gauge; gaugeeqs = b(k).backout.eq;
    if ischar(gauges), gauges = {gauges}; gaugeeqs = {gaugeeqs}; end
    for g = 1:numel(gauges)
        fprintf('    level of %s pinned by consistency equation [%s]\n', gauges{g}, gaugeeqs{g});
    end
    for jj = 1:numel(b(k).closed_form)
        fprintf('      %s = %s\n', b(k).closed_form(jj).var, b(k).closed_form(jj).expr);
    end
end

% --- 4. Write the closed forms into the steady_state_model ---
m2 = m.copy();
m2 = m2.apply_steady_plan(b);
fprintf('\n  steady_state entries written     : %d (anchors + derived closed forms)\n', size(m2.steady_state,1));
assert(size(m2.steady_state,1)==nvar, 'every endogenous variable must get a steady-state expression');

% --- 5. Verification: execute the emitted cascade and check every equation ---
% checksteady sorts the assignments into dependency order; evaluating them in that
% order recovers the steady state the .mod file would compute, and every model
% equation must then hold at that point.
values = struct();
for i = 1:size(m2.params,1), values.(m2.params{i,1}) = m2.params{i,2}; end
for i = 1:size(m2.varexo,1), m2.set_value(m2.varexo{i,1}, 0); values.(m2.varexo{i,1}) = 0; end
[~, rows] = m2.checksteady();
for i = 1:numel(rows)
    name = m2.steady_state{rows(i),1};
    values.(name) = ast(m2.steady_state{rows(i),2}).staticise().eval(values);
    m2.set_value(name, values.(name));
end
resid = zeros(size(m2.equations,1), 1);
for i = 1:numel(resid)
    resid(i) = m2.evaluate(m2.equations{i,1}).resid;
end
assert(max(abs(resid)) < 1e-9, 'the derived steady state must solve the model');
fprintf('  every equation checked at that point (max residual %.2e)\n', max(abs(resid)));
fprintf('    GDP = %.4f, C = %.4f, L = %.4f, w^h = %.4f, r^k = %.4f\n', ...
        values.GDP, values.Consumption, values.HouseholdLabourSupply, values.HouseholdRealWage, values.CapitalReturnRate);
