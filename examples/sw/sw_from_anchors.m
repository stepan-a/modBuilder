% sw_from_anchors.m -- Showcase: derive the FULL SW steady state from DECLARED ANCHORS.
%
% Instead of hand-writing the analytical steady_state_model, we declare only the
% steady-state values a modeller knows a priori -- the symmetric-equilibrium
% normalisations (all = 1), the unit shock levels, the marginal cost, and the hours
% scale -- and let steady_plan(Match, Anchors, PropagateKnown) derive EVERYTHING
% else in closed form. The scale-free Calvo recursion blocks (Z's, H's) are closed
% by the gauge backout: their ratios come from the block equations, their level
% from a consistency equation absorbed by the anchors (aggregate production for
% GDP, labour-market clearing for the wage recursions) -- exactly the hand
% technique of solving in ratios and backing the level out of a discarded equation.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'src'));
addpath(fullfile(here, 'matlab'));
cd(here);
SW_BUILD_ONLY = true; sw; clear SW_BUILD_ONLY   % build the model, NO steady block

% --- 1. Declare the anchors and their known values ---
symmetric = {'FinalGoodLagrangeMultiplier','AveragedRelativePrices','PriceDistorsion','NablaPrice', ...
  'OptimalRelativePrice','EmploymentAgencyLagrangeMultiplier','RealWageGrowthFactor','AveragedRelativeWages', ...
  'OptimalRelativeRealWage','WageDistorsion','NablaWage','TobinQ','OutputGap','EfficientTobinQ'};
constants = {'RealMarginalCost','EfficientRealMarginalCost','CapitalReturnRate','EfficientCapitalReturnRate', ...
  'RealGrossWage','EfficientRealGrossWage','HouseholdRealWage','EfficientHouseholdRealWage'};
scale = {'HouseholdLabourSupply'};
declared = [symmetric, constants, scale];

% Values known a priori: symmetric normalisations and unit shock levels feed the
% known-value propagation (log(shock) -> 0, x/1 -> x), which is what lets the
% recognisers close the consumption FOC blocks.
for s = symmetric, m.steady(s{1}, '1'); end
unit_shocks = {'ProductionEfficiencyCycle','ConsumptionTax','LabourIncomeTax','IncomeTax','RiskPremium', ...
  'InvestmentRelativePrice','InvestmentEfficiencyShock','LabourTax','PriceCostPushShock','WageCostPushShock', ...
  'TaylorShock','HabitShock','PreferenceShock'};
for s = unit_shocks, m.steady(s{1}, '1'); end
m.steady('RealMarginalCost', '(thetaf-1)/thetaf');
m.steady('EfficientRealMarginalCost', '(thetaf-1)/thetaf');
m.steady('HouseholdLabourSupply', 'household_labour_supply_ss');

% --- 2. Structural plan: shocks auto-detected, declared values pulled out ---
b = m.steady_plan(Match=true, Anchors=declared, PropagateKnown=true);

nvar = size(m.var,1);
auto=0; decl=0; closed=0; resid=0;
for k=1:numel(b)
    if strcmp(b(k).kind,'anchor')
        if ismember(b(k).vars{1}, declared), decl=decl+1; else, auto=auto+1; end
    else
        rc = numel(b(k).closed_form);
        closed = closed + rc;
        resid  = resid  + numel(b(k).vars) - rc;
    end
end
fprintf('\n==== SW steady state from anchors ====\n');
fprintf('  total endogenous variables      : %d\n', nvar);
fprintf('  shocks auto-identified (exo)     : %d\n', auto);
fprintf('  anchors declared (known values)  : %d\n', decl);
fprintf('  derived in CLOSED FORM by plan   : %d\n', closed);
fprintf('  residual (numerical solve needed): %d\n', resid);

% --- 3. Scale-free blocks closed by the gauge backout ---
for k = 1:numel(b)
    if isempty(b(k).backout), continue; end
    fprintf('\n  gauge backout in block {%s}:\n', strjoin(b(k).vars, ', '));
    fprintf('    level of %s pinned by consistency equation [%s]\n', b(k).backout.gauge, b(k).backout.eq);
    for jj = 1:numel(b(k).closed_form)
        fprintf('      %s = %s\n', b(k).closed_form(jj).var, b(k).closed_form(jj).expr);
    end
end

% --- 4. Write the closed forms into the steady_state_model ---
m2 = m.copy();
m2 = m2.apply_steady_plan(b);
fprintf('\n  steady_state entries written     : %d (anchors + derived closed forms)\n', size(m2.steady_state,1));
