% sw.m — the nonlinear Smets-Wouters model, built with modBuilder.
%
% Builds the 78-equation nonlinear Smets-Wouters model programmatically and
% exports it as sw.mod, steady-state block included. It is the large-model
% counterpart of ../two-country: there the steady state is only CONDITIONALLY
% analytical (a small numerical core remains), here it is analytical
% throughout -- every one of the 78 variables gets a closed form.
%
% Reading order:
% - each equation is added with a comment "Eq N: description -> Variable",
%   where N is the equation number used in tex/swmodel.tex, so the code and
%   the written model can be read side by side;
% - the sections follow the economics: calibration, model (households,
%   prices, wages, policy, markets, shocks, efficient block), declarations
%   (long_name / texname metadata), analytical steady state, export.
%
% What it demonstrates:
% - a model of realistic size stays readable when the equations are named
%   after what they pin rather than numbered;
% - shock processes are generated rather than typed: declare_arma_shock
%   writes an AR(1) -- or any ARMA(p,q), see the block at "Shock Processes" --
%   and declares its parameters and innovation in one call;
% - the steady state is written once, analytically, and exported into the
%   steady_state_model block, so Dynare needs no numerical steady-state solve.
%   ../two-country shows the other route, where steady_plan DERIVES the
%   closed forms instead of the modeller writing them; sw_from_anchors.m
%   applies that route to this very model.
%
% Requirements: MATLAB and this repository. Dynare is needed only to RUN the
% generated sw.mod -- building it, and running sw_from_anchors.m, is pure
% MATLAB.
%
% See also: sw_from_anchors.m (derive the same steady state from declared
% anchors), tex/swmodel.tex (the model written out, same equation numbers).

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'src'));   % modBuilder class
addpath(fullfile(here, 'matlab'));            % ARMA routines (arma_*, declare_arma_shock)

% Include the efficient (flexible price and wage) economy, equations 60-78,
% whose variables carry the "Efficient" prefix and feed the output gap of the
% Taylor rule. Set to false for the core 59-equation model, in which case the
% output gap is defined against a constant instead (see equation 36).
WITH_EFFICIENT_BLOCK = true;

% =========================================================================
%  CALIBRATION
% =========================================================================

% Household
sigmac = 1.3800;
sigmal = 1.9200;
eta    = 0.7100;
investment_cost_size = 0.1753;
capacity_utilization_factor_ss = 0.8012;
depreciation_rate_ss = 0.0250;
household_labour_supply_ss = 0.2712;

% Prices
price_contract_length = 2.9412;
gammap = 0.2400;
steady_state_mark_up_f = 1.1931;

% Wages
wage_contract_length = 3.3333;
gammaw = 0.5800;
steady_state_mark_up_s = 1.2027;

% Steady state values
production_efficiency_growth_ss = 0.0031;
production_efficiency_ss        = 1.0000;
inflation_target_ss             = 1.0050;
steady_state_nominal_interest_factor = 1.0100;
steady_state_real_interest_factor = steady_state_nominal_interest_factor / inflation_target_ss;
consumption_tax_ss              = 1.0000;
income_tax_ss                   = 1.0000;
labour_income_tax_ss            = 1.0000;
labour_tax_ss                   = 1.0000;
preference_ss                   = 1.0000;
investment_relative_price_ss    = 1.0000;
investment_efficiency_ss        = 1.0000;
risk_premium_ss                 = 1.0000;
labour_supply_ss                = 1.0000;
taylor_ss                       = 1.0000;
public_spending_ss              = 0.1800;
price_cost_push_ss              = 1.0000;
wage_cost_push_ss               = 1.0000;
habit_ss                        = 1.0000;

steady_state_labour_share = (1-0.19)/(labour_tax_ss*steady_state_mark_up_f);

kimball_curvature_f = -(-10.0000)*steady_state_mark_up_f/(steady_state_mark_up_f-1);
kimball_curvature_s = -(-10.0000)*steady_state_mark_up_s/(steady_state_mark_up_s-1);

% Monetary authority
nominal_interest_rate_smoothing                          = 0.8100;
elasticity_of_nominal_interest_rate_to_inflation         = 2.0400;
elasticity_of_nominal_interest_rate_to_output_gap        = 0.0800;
elasticity_of_nominal_interest_rate_to_inflation_growth  = 0.0000;
elasticity_of_nominal_interest_rate_to_output_gap_growth = 0.2200;

% AR(1) coefficients. Source of each value given inline:
%   SW2007 = Smets & Wouters (2007, AER), posterior mean
%   SW2003 = Smets & Wouters (2003, JEEA), posterior median (1980-2002)
%   "sw"   = specific to this model, absent from SW2003/2007
production_efficiency_growth_rho1 = .3919;  % sw (trend-growth shock; no SW counterpart)
production_efficiency_rho1       = .9500;   % SW2007 (productivity)
consumption_tax_rho1             = .0000;   % sw (fiscal extension)
labour_income_tax_rho1           = .0000;   % sw (fiscal extension)
income_tax_rho1                  = .0000;   % sw (fiscal extension)
risk_premium_rho1                = .2200;   % SW2007 (risk premium = SW2003 consumption-preference shock)
labour_supply_rho1               = .9390;   % SW2003 (labour supply; dropped in SW2007)
investment_relative_price_rho1   = .7100;   % sw (redundant with investment efficiency)
investment_efficiency_rho1       = .7100;   % SW2007 (investment-specific)
labour_tax_rho1                  = .0000;   % sw (fiscal extension)
price_cost_push_rho1             = .9000;   % SW2007 (price markup; ARMA approximated by AR(1))
wage_cost_push_rho1              = .9700;   % SW2007 (wage markup; ARMA approximated by AR(1))
inflation_target_rho1            = .0000;   % SW2003 (inflation objective; persistence not reported in Table 1)
taylor_rho1                      = .1500;   % SW2007 (monetary policy)
public_spending_rho1             = .9700;   % SW2007 (government spending)
habit_rho1                       = .9800;   % sw (habit is a parameter in SW; this is a shock on it)
preference_rho1                  = .9000;   % sw (additive preference shifter; SW2003 pref. shock is risk_premium)

% Unconditional standard deviations. SW estimates are rescaled by 1/100
% (sw variables are in levels/ratios, not percent). Disabled shocks are set
% to 0; the source value they would take if reactivated is noted inline.
production_efficiency_growth_std = 0.0000;   % sw, disabled
production_efficiency_std        = 0.0045;   % SW2007 (0.45/100)
risk_premium_std                 = 0.0024;   % SW2007 (0.23/100)
consumption_tax_std              = 0.0000;   % sw, disabled
labour_income_tax_std            = 0.0000;   % sw, disabled
income_tax_std                   = 0.0000;   % sw, disabled
labour_supply_std                = 0.0000;   % disabled; SW2003 = 0.0141 (1.411/100) if reactivated
investment_relative_price_std    = 0.0000;   % sw, disabled
investment_efficiency_std        = 0.0045;   % SW2007 (0.45/100)
labour_tax_std                   = 0.0000;   % sw, disabled
price_cost_push_std              = 0.0014;   % SW2007 (0.14/100)
wage_cost_push_std               = 0.0024;   % SW2007 (0.24/100)
inflation_target_std             = 0.0000;   % disabled; SW2003 = 0.0011 (0.106/100) if reactivated
taylor_std                       = 0.0024;   % SW2007 (0.24/100)
public_spending_std              = 0.0053;   % SW2007 (0.53/100)
habit_std                        = 0.0000;   % sw, disabled
preference_std                   = 0.0000;   % sw, disabled

% ARMA shock configuration -- the showcase of programmatic model building.
% Each shock is declared as an ARMA(p,q) whose AR/MA coefficients are drawn at
% random (arma_random) subject to two Smets-Wouters moments: the lag-1
% autocorrelation equals <prefix>_rho1 and the unconditional variance equals
% <prefix>_std^2. (p,q)=(1,0) reproduces the AR(1) baseline exactly (the
% innovation std is then std*sqrt(1-rho1^2), as before). Raise (p,q) to give a
% shock richer dynamics while preserving those two moments.
%
% shock_spec columns: {param prefix, shock variable, innovation, innovation TeX,
% TeX tag, p, q}. The (p,q) at the end of each row are the user-facing knobs.
arma_modint = [0.2 0.98];   % allowed moduli of the AR/MA characteristic roots
arma_seed   = 1;            % reproducible random draws

shock_spec = {
  'production_efficiency_growth', 'ProductionEfficiencyGrowth',  'EfficiencyGrowthInnovation',        '\epsilon_g',               'A_T',           1, 0
  'production_efficiency',        'ProductionEfficiencyCycle',   'EfficiencyCycleInnovation',         '\epsilon_A',               'A_C',           1, 0
  'consumption_tax',              'ConsumptionTax',              'ConsumptionTaxInnovation',          '\epsilon_{\tau^C}',        '\tau_C',        1, 0
  'labour_income_tax',            'LabourIncomeTax',             'LabourIncomeTaxInnovation',         '\epsilon_{\tau^W}',        '\tau_W',        1, 0
  'income_tax',                   'IncomeTax',                   'IncomeTaxInnovation',               '\epsilon_{\tau^R}',        '\tau_R',        1, 0
  'risk_premium',                 'RiskPremium',                 'RiskPremiumInnovation',             '\epsilon_B',               '\varepsilon_B', 1, 0
  'labour_supply',                'LabourSupplyShock',           'LabourSupplyInnovation',            '\epsilon_L',               '\varepsilon_L', 1, 0
  'investment_relative_price',    'InvestmentRelativePrice',     'InvestmentRelativePriceInnovation', '\epsilon_{p^I}',           'p_I',           1, 0
  'investment_efficiency',        'InvestmentEfficiencyShock',   'InvestmentEfficiencyInnovation',    '\epsilon_I',               '\varepsilon_I', 1, 0
  'labour_tax',                   'LabourTax',                   'LabourTaxInnovation',               '\epsilon_{\tau^L}',        '\tau_L',        1, 0
  'price_cost_push',              'PriceCostPushShock',          'PriceCostPushInnovation',           '\epsilon_{\nu^p}',         '\nu^p',         1, 1
  'wage_cost_push',               'WageCostPushShock',           'WageCostPushInnovation',            '\epsilon_{\nu^w}',         '\nu^w',         1, 1
  'inflation_target',             'InflationTarget',             'InflationTargetInnovation',         '\epsilon_{\bar\pi}',       '\bar\pi',       1, 0
  'taylor',                       'TaylorShock',                 'TaylorInnovation',                  '\epsilon_R',               '\varepsilon_R', 1, 0
  'public_spending',              'PublicSpendingShare',         'PublicSpendingShareInnovation',     '\epsilon_{\varepsilon^g}', '\varepsilon_g', 1, 0
  'habit',                        'HabitShock',                  'HabitInnovation',                   '\epsilon_{\eta^s}',        '\eta^s',        1, 0
  'preference',                   'PreferenceShock',             'PreferenceInnovation',              '\epsilon_\varsigma',       '\varsigma',     1, 0
};

% Derived structural parameters
NominalInterestFactor_ss = steady_state_nominal_interest_factor;
beta = inflation_target_ss/(risk_premium_ss*NominalInterestFactor_ss) ...
       *(1+production_efficiency_growth_ss)^(sigmac);

RealInterestFactor_ss = NominalInterestFactor_ss / inflation_target_ss;
CapitalReturnRate_ss = ((1+production_efficiency_growth_ss)^sigmac ...
                        - beta*(1-depreciation_rate_ss)) ...
                       / (beta*income_tax_ss*capacity_utilization_factor_ss);
first_derivate_depreciation_rate_ss = CapitalReturnRate_ss*income_tax_ss;
% Elasticity of the depreciation rate to capacity utilization (curvature of the
% utilization cost): calibrated so the utilization FOC delta'(ubar) = r^k*IncomeTax
% holds at the normalised steady-state utilization capacity_utilization_factor_ss.
depreciation_curvature = first_derivate_depreciation_rate_ss/depreciation_rate_ss;

alpha = 1 - labour_tax_ss*steady_state_mark_up_f*steady_state_labour_share;

RealMarginalCost_ss = 1/steady_state_mark_up_f;
RealGrossWage_ss = (RealMarginalCost_ss*(alpha/CapitalReturnRate_ss)^alpha)^(1/(1-alpha)) ...
                   *(1-alpha)/labour_tax_ss*production_efficiency_ss;
ssratio_HouseholdRealWage_RealGrossWage = 1/steady_state_mark_up_s;
HouseholdRealWage_ss = ssratio_HouseholdRealWage_RealGrossWage * RealGrossWage_ss;

ssratio_CapitalDemand_HouseholdLabourSupply = labour_tax_ss*RealGrossWage_ss/CapitalReturnRate_ss*alpha/(1-alpha);
ssratio_GDP_HouseholdLabourSupply = ssratio_CapitalDemand_HouseholdLabourSupply^alpha * production_efficiency_ss^(1-alpha);
ssratio_Investment_GDP = (production_efficiency_growth_ss + depreciation_rate_ss) ...
                         / capacity_utilization_factor_ss ...
                         * ssratio_CapitalDemand_HouseholdLabourSupply^(1-alpha) ...
                         / production_efficiency_ss^(1-alpha);
ssratio_Consumption_GDP = 1 - public_spending_ss - ssratio_Investment_GDP;

labour_supply_ss = HouseholdRealWage_ss ...
                   / (ssratio_Consumption_GDP*ssratio_GDP_HouseholdLabourSupply) ...
                   * income_tax_ss * labour_income_tax_ss / consumption_tax_ss ...
                   / (1-eta/(1+production_efficiency_growth_ss));

thetaf = steady_state_mark_up_f/(steady_state_mark_up_f-1);
thetas = steady_state_mark_up_s/(steady_state_mark_up_s-1);
psif = -kimball_curvature_f / thetaf;
psis = -kimball_curvature_s / thetas;
xip  = (price_contract_length - 1)/price_contract_length;
xiw  = (wage_contract_length - 1)/wage_contract_length;

% Steady-state values for endogenous variables
ProductionEfficiencyGrowth_ss = 1 + production_efficiency_growth_ss;
HouseholdLabourSupply_ss = household_labour_supply_ss;
LabourDemand_ss = HouseholdLabourSupply_ss;
EmploymentAgencyLabourSupply_ss = HouseholdLabourSupply_ss;
GDP_ss = ssratio_GDP_HouseholdLabourSupply * HouseholdLabourSupply_ss;
Consumption_ss = ssratio_Consumption_GDP * GDP_ss;
Investment_ss = ssratio_Investment_GDP * GDP_ss;
HouseholdLagrangeMultiplier_ss = (1/consumption_tax_ss) ...
    * (Consumption_ss*(1-eta/(1+production_efficiency_growth_ss)))^(-sigmac) ...
    * exp(labour_supply_ss*(sigmac-1)/(1+sigmal));
CapitalDemand_ss = ssratio_CapitalDemand_HouseholdLabourSupply * HouseholdLabourSupply_ss;
CapitalStock_ss = (1+production_efficiency_growth_ss) ...
                  / (production_efficiency_growth_ss+depreciation_rate_ss) * Investment_ss;
PublicSpending_ss = GDP_ss * public_spending_ss;

NonOptimizingFirmsPriceGrowth_ss = inflation_target_ss;
InflationFactor_ss = inflation_target_ss;
NonOptimizingUnionsWageGrowth_ss = inflation_target_ss;

Z1_ss = RealMarginalCost_ss*HouseholdLagrangeMultiplier_ss*GDP_ss ...
        / (1-beta*xip*(1+production_efficiency_growth_ss)^(1-sigmac));
Z2_ss = Z1_ss/RealMarginalCost_ss;
Z3_ss = Z2_ss;

H1_ss = HouseholdRealWage_ss*HouseholdLagrangeMultiplier_ss*EmploymentAgencyLabourSupply_ss ...
        / (1-beta*xiw*(1+production_efficiency_growth_ss)^(1-sigmac));
H2_ss = H1_ss/ssratio_HouseholdRealWage_RealGrossWage;
H3_ss = H2_ss;

% =========================================================================
%  MODEL CONSTRUCTION
% =========================================================================
% modBuilder requires equations first (add), then symbol classification
% (parameter, exogenous). Untyped symbols are held in 'symbols' until typed.

m = modBuilder();

% =========================================================================
%  MODEL EQUATIONS
% =========================================================================

%% --- Households (Equations 1-11) ---

% Eq 1: Household Consumption FOC → HouseholdLagrangeMultiplier
m.add('HouseholdLagrangeMultiplier', '(Consumption - eta*HabitShock*Consumption(-1)/ProductionEfficiencyGrowth+log(PreferenceShock))^(-sigmac)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(HouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal)) - ConsumptionTax*HouseholdLagrangeMultiplier');

% Eq 2: Household Euler equation → NominalInterestFactor
m.add('NominalInterestFactor', 'beta*RiskPremium*NominalInterestFactor*ProductionEfficiencyGrowth(1)^(-sigmac)*HouseholdLagrangeMultiplier(1)*IncomeTax(1)/InflationFactor(1) - HouseholdLagrangeMultiplier*IncomeTax');

% Eq 3: Household Labour FOC → Consumption
m.add('Consumption', '(Consumption - eta*HabitShock*Consumption(-1)/ProductionEfficiencyGrowth+log(PreferenceShock))^(1-sigmac)*(LabourSupplyShock/household_labour_supply_ss)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(HouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal))*(HouseholdLabourSupply/household_labour_supply_ss)^sigmal - HouseholdLagrangeMultiplier*IncomeTax*LabourIncomeTax*HouseholdRealWage');

% Eq 4: Household Investment FOC → TobinQ
m.add('TobinQ', 'TobinQ*(1-InvestmentCost-Investment/Investment(-1)*ProductionEfficiencyGrowth*dInvestmentCost)+beta*HouseholdLagrangeMultiplier(1)/HouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*TobinQ(1)*InvestmentEfficiencyShock(1)/InvestmentEfficiencyShock*(Investment(1)/Investment*ProductionEfficiencyGrowth(1))^2*dInvestmentCost(1) - InvestmentRelativePrice/InvestmentEfficiencyShock');

% Eq 5: Depreciation rate → DepreciationRate
m.add('DepreciationRate', 'depreciation_rate_ss*exp((CapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - DepreciationRate');

% Eq 6: First derivative of the depreciation rate → dDepreciationRate
m.add('dDepreciationRate', 'depreciation_rate_ss*depreciation_curvature*exp((CapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - dDepreciationRate');

% Eq 7: Household Capacity utilization rate FOC → CapitalReturnRate
m.add('CapitalReturnRate', 'IncomeTax*CapitalReturnRate - TobinQ*dDepreciationRate');

% Eq 8: Household Physical capital FOC → CapacityUtilizationFactor
m.add('CapacityUtilizationFactor', 'beta*HouseholdLagrangeMultiplier(1)/HouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*(TobinQ(1)*(1-DepreciationRate(1))+IncomeTax(1)*CapitalReturnRate(1)*CapacityUtilizationFactor(1)) - TobinQ');

% Eq 9: Physical capital stock law of motion → CapitalStock
m.add('CapitalStock', '(1-DepreciationRate)*CapitalStock(-1)/ProductionEfficiencyGrowth+InvestmentEfficiencyShock*(1-InvestmentCost)*Investment - CapitalStock');

% Eq 10: Investment cost → InvestmentCost
m.add('InvestmentCost', 'InvestmentCost = .5*investment_cost_size*production_efficiency_growth_ss*production_efficiency_growth_ss*(Investment/Investment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)^2');

% Eq 11: First derivative of the investment cost → dInvestmentCost
m.add('dInvestmentCost', 'dInvestmentCost = (Investment/Investment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)*production_efficiency_growth_ss*investment_cost_size');

%% --- Prices (Equations 12-23) ---

% Eq 12: Price growth factor for non optimizing firms → NonOptimizingFirmsPriceGrowth
m.add('NonOptimizingFirmsPriceGrowth', 'InflationTarget^(1-gammap)*InflationFactor(-1)^gammap - NonOptimizingFirmsPriceGrowth');

% Eq 13: Factor Price Frontier → RealGrossWage
m.add('RealGrossWage', 'LabourTax*RealGrossWage*LabourDemand/(CapitalReturnRate*CapitalDemand) - (1-alpha)/alpha');

% Eq 14: Marginal cost → RealMarginalCost
m.add('RealMarginalCost', 'ProductionEfficiencyCycle^(alpha-1)*(CapitalReturnRate/alpha)^alpha*(LabourTax*RealGrossWage/(1-alpha))^(1-alpha) - RealMarginalCost');

% Eq 15: Relative price of an optimizing firm → OptimalRelativePrice
m.add('OptimalRelativePrice', 'thetaf*(1+psif)/(thetaf*(1+psif)-1)*(Z1/Z2)+psif/(thetaf*(1+psif)-1)*OptimalRelativePrice^(1+(1+psif)*thetaf)*Z3/Z2 - OptimalRelativePrice');

% Eq 16: Lagrange multiplier of the final good firm → InflationFactor
m.add('InflationFactor', '(1-xip)*OptimalRelativePrice^(1-thetaf*(1+psif))+xip*(NonOptimizingFirmsPriceGrowth/InflationFactor)^(1-thetaf*(1+psif))*FinalGoodLagrangeMultiplier(-1)^(1-thetaf*(1+psif)) - FinalGoodLagrangeMultiplier^(1-thetaf*(1+psif))');

% Eq 17: Z1 → Z1
m.add('Z1', 'HouseholdLagrangeMultiplier*RealMarginalCost*PriceCostPushShock*FinalGoodLagrangeMultiplier^(thetaf*(1+psif))*GDP+beta*xip*ProductionEfficiencyGrowth(1)^(1-sigmac)*(InflationFactor(1)/NonOptimizingFirmsPriceGrowth)^((1+psif)*thetaf)*Z1(1) - Z1');

% Eq 18: Z2 → Z2
m.add('Z2', 'HouseholdLagrangeMultiplier*FinalGoodLagrangeMultiplier^(thetaf*(1+psif))*GDP+beta*xip*ProductionEfficiencyGrowth(1)^(1-sigmac)*(InflationFactor(1)/NonOptimizingFirmsPriceGrowth)^((1+psif)*thetaf-1)*Z2(1) - Z2');

% Eq 19: Z3 → Z3
m.add('Z3', 'HouseholdLagrangeMultiplier*GDP+beta*xip*ProductionEfficiencyGrowth(1)^(1-sigmac)*NonOptimizingFirmsPriceGrowth/InflationFactor(1)*Z3(1) - Z3');

% Eq 20: Average of relative prices → AveragedRelativePrices
m.add('AveragedRelativePrices', '(1-xip)*OptimalRelativePrice+xip*NonOptimizingFirmsPriceGrowth/InflationFactor*AveragedRelativePrices(-1) - AveragedRelativePrices');

% Eq 21: Aggregate price (Kimball normalisation) → FinalGoodLagrangeMultiplier
m.add('FinalGoodLagrangeMultiplier', 'psif*AveragedRelativePrices/(1+psif)+FinalGoodLagrangeMultiplier/(1+psif) - 1');

% Eq 22: Price Distortion → PriceDistorsion
m.add('PriceDistorsion', 'psif/(1+psif)+NablaPrice/(1+psif)*FinalGoodLagrangeMultiplier^(thetaf*(1+psif)) - PriceDistorsion');

% Eq 23: nabla (price distortion auxiliary) → NablaPrice
m.add('NablaPrice', '(1-xip)*OptimalRelativePrice^(-(1+psif)*thetaf)+xip*NablaPrice(-1)*(NonOptimizingFirmsPriceGrowth/InflationFactor)^(-thetaf*(1+psif)) - NablaPrice');

%% --- Wages (Equations 24-34) ---

% Eq 24: Wage growth factor of non optimizing unions → NonOptimizingUnionsWageGrowth
m.add('NonOptimizingUnionsWageGrowth', 'InflationFactor^gammaw*InflationTarget^(1-gammaw) - NonOptimizingUnionsWageGrowth');

% Eq 25: Real wage growth definition → RealWageGrowthFactor
m.add('RealWageGrowthFactor', 'RealGrossWage/RealGrossWage(-1) - RealWageGrowthFactor');

% Eq 26: Relative wage of an optimizing union → H1
m.add('H1', 'thetas*(1+psis)/(thetas*(1+psis)-1)*H1/H2+psis/(thetas*(1+psis)-1)*OptimalRelativeRealWage^(1+(1+psis)*thetas)*H3/H2 - OptimalRelativeRealWage');

% Eq 27: Lagrange multiplier of the employment agency → OptimalRelativeRealWage
m.add('OptimalRelativeRealWage', '(1-xiw)*OptimalRelativeRealWage^(1-thetas*(1+psis))+xiw*(NonOptimizingUnionsWageGrowth/(RealWageGrowthFactor*InflationFactor))^(1-thetas*(1+psis))*EmploymentAgencyLagrangeMultiplier(-1)^(1-thetas*(1+psis)) - EmploymentAgencyLagrangeMultiplier^(1-thetas*(1+psis))');

% Eq 28: H1 → HouseholdRealWage
m.add('HouseholdRealWage', 'HouseholdLagrangeMultiplier*HouseholdRealWage*WageCostPushShock*EmploymentAgencyLagrangeMultiplier^(thetas*(1+psis))*EmploymentAgencyLabourSupply+beta*xiw*ProductionEfficiencyGrowth(1)^(1-sigmac)*(RealWageGrowthFactor(1)*InflationFactor(1)/NonOptimizingUnionsWageGrowth)^((1+psis)*thetas)*H1(1) - H1');

% Eq 29: H2 → H2
m.add('H2', 'HouseholdLagrangeMultiplier*RealGrossWage*EmploymentAgencyLagrangeMultiplier^(thetas*(1+psis))*EmploymentAgencyLabourSupply+beta*xiw*ProductionEfficiencyGrowth(1)^(1-sigmac)*(RealWageGrowthFactor(1)*InflationFactor(1)/NonOptimizingUnionsWageGrowth)^((1+psis)*thetas-1)*H2(1) - H2');

% Eq 30: H3 → H3
m.add('H3', 'HouseholdLagrangeMultiplier*RealGrossWage*EmploymentAgencyLabourSupply+beta*xiw*ProductionEfficiencyGrowth(1)^(1-sigmac)*NonOptimizingUnionsWageGrowth/(InflationFactor(1)*RealWageGrowthFactor(1))*H3(1) - H3');

% Eq 31: Average of relative wages → AveragedRelativeWages
m.add('AveragedRelativeWages', '(1-xiw)*OptimalRelativeRealWage+xiw*NonOptimizingUnionsWageGrowth/(RealWageGrowthFactor*InflationFactor)*AveragedRelativeWages(-1) - AveragedRelativeWages');

% Eq 32: Aggregate Wage (Kimball normalisation) → EmploymentAgencyLagrangeMultiplier
m.add('EmploymentAgencyLagrangeMultiplier', 'psis*AveragedRelativeWages/(1+psis)+EmploymentAgencyLagrangeMultiplier/(1+psis) - 1');

% Eq 33: Wage Distortion → WageDistorsion
m.add('WageDistorsion', 'psis/(1+psis)+NablaWage/(1+psis)*EmploymentAgencyLagrangeMultiplier^(thetas*(1+psis)) - WageDistorsion');

% Eq 34: nabla (wage distortion auxiliary) → NablaWage
m.add('NablaWage', '(1-xiw)*OptimalRelativeRealWage^(-(1+psis)*thetas)+xiw*NablaWage(-1)*(NonOptimizingUnionsWageGrowth/(RealWageGrowthFactor*InflationFactor))^(-thetas*(1+psis)) - NablaWage');

%% --- Monetary Authority & Government (Equations 35-37) ---

% Eq 35: Taylor rule → OutputGap
m.add('OutputGap', 'NominalInterestFactor(-1)^nominal_interest_rate_smoothing*(steady_state_nominal_interest_factor*(InflationFactor(-1)/InflationTarget)^elasticity_of_nominal_interest_rate_to_inflation*OutputGap^elasticity_of_nominal_interest_rate_to_output_gap*(InflationFactor/InflationTarget*InflationTarget(-1)/InflationFactor(-1))^elasticity_of_nominal_interest_rate_to_inflation_growth*(OutputGap/OutputGap(-1))^elasticity_of_nominal_interest_rate_to_output_gap_growth)^(1-nominal_interest_rate_smoothing)*TaylorShock - NominalInterestFactor');

% Eq 36: Output gap definition → GDP
if WITH_EFFICIENT_BLOCK
    m.add('GDP', 'GDP/EfficientGDP - OutputGap');
else
    m.add('GDP', 'GDP/ssGDP - OutputGap');
end

% Eq 37: Public Spending → PublicSpending
m.add('PublicSpending', 'PublicSpendingShare*GDP - PublicSpending');

%% --- Markets (Equations 38-42) ---

% Eq 38: Physical capital market equilibrium → CapitalDemand
m.add('CapitalDemand', 'CapacityUtilizationFactor*CapitalStock(-1)/ProductionEfficiencyGrowth - CapitalDemand');

% Eq 39: Labour supply → employment agency relation → HouseholdLabourSupply
m.add('HouseholdLabourSupply', 'HouseholdLabourSupply/WageDistorsion - EmploymentAgencyLabourSupply');

% Eq 40: Labour market equilibrium → EmploymentAgencyLabourSupply
m.add('EmploymentAgencyLabourSupply', 'EmploymentAgencyLabourSupply - LabourDemand');

% Eq 41: GDP and intermediate goods → LabourDemand
m.add('LabourDemand', 'CapitalDemand^alpha*(ProductionEfficiencyCycle*LabourDemand)^(1-alpha)/PriceDistorsion - GDP');

% Eq 42: Final good market equilibrium → Investment
m.add('Investment', 'PublicSpending + Consumption + InvestmentRelativePrice*Investment - GDP');

%% --- Shock Processes (Equations 43-59) ---
% Generated programmatically from shock_spec: each shock becomes an ARMA(p,q)
% via declare_arma_shock, with coefficients drawn by arma_random to match the
% Smets-Wouters lag-1 autocorrelation (<prefix>_rho1) and variance
% (<prefix>_std^2). (p,q)=(1,0) reproduces the AR(1) baseline. Disabled shocks
% (std=0) are declared as inert AR(1) carrying the documented persistence.
% declare_arma_shock also declares the shock parameters (<prefix>_phi*/_theta*/
% _i_std, with TeX names) and the exogenous innovation.
% Long-run level <prefix>_ss of each shock (defaults to 1). Non-unit levels are
% either known constants or, for LabourSupplyShock, the calibration lever
% labour_supply_ss (derived above) that pins HouseholdLabourSupply to its target.
shock_level = dictionary( ...
    "ProductionEfficiencyGrowth", 1 + production_efficiency_growth_ss, ...
    "InflationTarget",            inflation_target_ss, ...
    "PublicSpendingShare",        public_spending_ss, ...
    "LabourSupplyShock",          labour_supply_ss);

for k = 1:size(shock_spec, 1)
    prefix   = shock_spec{k, 1};  shockvar = shock_spec{k, 2};  innov = shock_spec{k, 3};
    innovtex = shock_spec{k, 4};  tag      = shock_spec{k, 5};
    pk       = shock_spec{k, 6};  qk       = shock_spec{k, 7};
    rho1 = eval([prefix '_rho1']);
    sdv  = eval([prefix '_std']);
    lvl  = 1;
    if isKey(shock_level, shockvar), lvl = shock_level(shockvar); end
    if sdv == 0
        % Disabled: inert AR(1) (phi1 documents the persistence, i_std = 0).
        declare_arma_shock(m, shockvar, prefix, rho1, [], 0, innov, tag=tag, innovtex=innovtex, level=lvl);
    else
        [phi, theta, sig2] = arma_random(pk, qk, rho1, sdv^2, arma_modint, seed=arma_seed+k);
        declare_arma_shock(m, shockvar, prefix, phi, theta, sqrt(sig2), innov, tag=tag, innovtex=innovtex, level=lvl);
    end
end

%% --- Efficient Block (Equations 60-78) ---

if WITH_EFFICIENT_BLOCK

    % Eq 60: (Efficient) Household Consumption FOC → EfficientHouseholdLagrangeMultiplier
    m.add('EfficientHouseholdLagrangeMultiplier', '(EfficientConsumption - eta*HabitShock*EfficientConsumption(-1)/ProductionEfficiencyGrowth+log(PreferenceShock))^(-sigmac)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(EfficientHouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal)) - ConsumptionTax*EfficientHouseholdLagrangeMultiplier');

    % Eq 61: (Efficient) Household Euler equation → EfficientRealInterestFactor
    m.add('EfficientRealInterestFactor', 'beta*RiskPremium*EfficientRealInterestFactor*ProductionEfficiencyGrowth(1)^(-sigmac)*EfficientHouseholdLagrangeMultiplier(1)*IncomeTax(1) - EfficientHouseholdLagrangeMultiplier*IncomeTax');

    % Eq 62: (Efficient) Household Labour FOC → EfficientConsumption
    m.add('EfficientConsumption', '(EfficientConsumption - eta*HabitShock*EfficientConsumption(-1)/ProductionEfficiencyGrowth+log(PreferenceShock))^(1-sigmac)*(LabourSupplyShock/household_labour_supply_ss)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(EfficientHouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal))*(EfficientHouseholdLabourSupply/household_labour_supply_ss)^sigmal - EfficientHouseholdLagrangeMultiplier*IncomeTax*LabourIncomeTax*EfficientHouseholdRealWage');

    % Eq 63: (Efficient) Household Investment FOC → EfficientTobinQ
    m.add('EfficientTobinQ', 'EfficientTobinQ*(1-EfficientInvestmentCost-EfficientInvestment/EfficientInvestment(-1)*ProductionEfficiencyGrowth*dEfficientInvestmentCost)+beta*EfficientHouseholdLagrangeMultiplier(1)/EfficientHouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*EfficientTobinQ(1)*InvestmentEfficiencyShock(1)/InvestmentEfficiencyShock*(EfficientInvestment(1)/EfficientInvestment*ProductionEfficiencyGrowth(1))^2*dEfficientInvestmentCost(1) - InvestmentRelativePrice/InvestmentEfficiencyShock');

    % Eq 64: (Efficient) Depreciation rate → EfficientDepreciationRate
    m.add('EfficientDepreciationRate', 'depreciation_rate_ss*exp((EfficientCapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - EfficientDepreciationRate');

    % Eq 65: (Efficient) First derivative of the depreciation rate → dEfficientDepreciationRate
    m.add('dEfficientDepreciationRate', 'depreciation_rate_ss*depreciation_curvature*exp((EfficientCapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - dEfficientDepreciationRate');

    % Eq 66: (Efficient) Capacity utilization rate FOC → EfficientCapitalReturnRate
    m.add('EfficientCapitalReturnRate', 'IncomeTax*EfficientCapitalReturnRate - EfficientTobinQ*dEfficientDepreciationRate');

    % Eq 67: (Efficient) Household Physical capital FOC → EfficientCapacityUtilizationFactor
    m.add('EfficientCapacityUtilizationFactor', 'beta*EfficientHouseholdLagrangeMultiplier(1)/EfficientHouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*(EfficientTobinQ(1)*(1-EfficientDepreciationRate(1))+IncomeTax(1)*EfficientCapitalReturnRate(1)*EfficientCapacityUtilizationFactor(1)) - EfficientTobinQ');

    % Eq 68: (Efficient) Physical capital stock law of motion → EfficientCapitalStock
    m.add('EfficientCapitalStock', '(1-EfficientDepreciationRate)*EfficientCapitalStock(-1)/ProductionEfficiencyGrowth+InvestmentEfficiencyShock*(1-EfficientInvestmentCost)*EfficientInvestment - EfficientCapitalStock');

    % Eq 69: (Efficient) Factor Price Frontier → EfficientLabourDemand
    m.add('EfficientLabourDemand', 'LabourTax*EfficientRealGrossWage*EfficientLabourDemand/(EfficientCapitalReturnRate*EfficientCapitalDemand) - (1-alpha)/alpha');

    % Eq 70: (Efficient) Marginal cost → EfficientRealGrossWage
    m.add('EfficientRealGrossWage', 'ProductionEfficiencyCycle^(alpha-1)*(EfficientCapitalReturnRate/alpha)^alpha*(LabourTax*EfficientRealGrossWage/(1-alpha))^(1-alpha) - EfficientRealMarginalCost');

    % Eq 71: (Efficient) Price decision → EfficientRealMarginalCost
    m.add('EfficientRealMarginalCost', 'thetaf*(1+psif)/(thetaf*(1+psif)-1)*EfficientRealMarginalCost+psif/(thetaf*(1+psif)-1) - 1');

    % Eq 72: (Efficient) Wage decision → EfficientHouseholdRealWage
    m.add('EfficientHouseholdRealWage', 'thetas*(1+psis)/(thetas*(1+psis)-1)*EfficientHouseholdRealWage/EfficientRealGrossWage+psis/(thetas*(1+psis)-1) - 1');

    % Eq 73: (Efficient) Labour market equilibrium → EfficientHouseholdLabourSupply
    m.add('EfficientHouseholdLabourSupply', 'EfficientLabourDemand - EfficientHouseholdLabourSupply');

    % Eq 74: (Efficient) Physical capital market equilibrium → EfficientCapitalDemand
    m.add('EfficientCapitalDemand', 'EfficientCapacityUtilizationFactor*EfficientCapitalStock(-1)/ProductionEfficiencyGrowth - EfficientCapitalDemand');

    % Eq 75: (Efficient) Final good market equilibrium → EfficientInvestment
    m.add('EfficientInvestment', 'EfficientConsumption + InvestmentRelativePrice*EfficientInvestment - (1-PublicSpendingShare)*EfficientGDP');

    % Eq 76: (Efficient) GDP → EfficientGDP
    m.add('EfficientGDP', 'EfficientCapitalDemand^alpha*(ProductionEfficiencyCycle*EfficientLabourDemand)^(1-alpha) - EfficientGDP');

    % Eq 77: (Efficient) Investment cost → EfficientInvestmentCost
    m.add('EfficientInvestmentCost', '.5*investment_cost_size*production_efficiency_growth_ss*production_efficiency_growth_ss*(EfficientInvestment/EfficientInvestment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)^2 - EfficientInvestmentCost');

    % Eq 78: (Efficient) First derivative of the investment cost → dEfficientInvestmentCost
    m.add('dEfficientInvestmentCost', '(EfficientInvestment/EfficientInvestment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)*production_efficiency_growth_ss*investment_cost_size - dEfficientInvestmentCost');

end

% =========================================================================
%  SYMBOL CLASSIFICATION
% =========================================================================
% Declare parameters and exogenous variables. All symbols already appear
% in the equations above and are currently held in m.symbols.

%% Parameters — Household
m.parameter('sigmac', sigmac, 'long_name', 'Risk aversion', 'texname', '\sigma_c');
m.parameter('sigmal', sigmal, 'long_name', 'Inverse Frisch elasticity', 'texname', '\sigma_l');
m.parameter('household_labour_supply_ss', household_labour_supply_ss, 'long_name', 'Steady-state household labour supply', 'texname', 'L^{\star}');
m.parameter('eta', eta, 'long_name', 'Habit formation', 'texname', '\eta');
m.parameter('beta', beta, 'long_name', 'Discount factor', 'texname', '\beta');
m.parameter('investment_cost_size', investment_cost_size, 'long_name', 'Investment adjustment cost', 'texname', '\psi');

%% Parameters — Capital and depreciation
m.parameter('depreciation_rate_ss', depreciation_rate_ss, 'long_name', 'Steady-state depreciation rate', 'texname', '\delta^{\star}');
m.parameter('capacity_utilization_factor_ss', capacity_utilization_factor_ss, 'long_name', 'Steady-state capacity utilisation', 'texname', 'z^{\star}');
m.parameter('depreciation_curvature', depreciation_curvature, 'long_name', 'Depreciation elasticity to utilisation', 'texname', '\kappa_\delta');

%% Parameters — Prices
m.parameter('alpha', alpha, 'long_name', 'Capital share', 'texname', '\alpha');
m.parameter('thetaf', thetaf, 'long_name', 'Price elasticity of demand', 'texname', '\theta_f');
m.parameter('psif', psif, 'long_name', 'Kimball curvature (goods)', 'texname', '\psi_f');
m.parameter('xip', xip, 'long_name', 'Calvo price stickiness', 'texname', '\xi_p');
m.parameter('gammap', gammap, 'long_name', 'Price indexation', 'texname', '\gamma_p');

%% Parameters — Wages
m.parameter('psis', psis, 'long_name', 'Kimball curvature (labour)', 'texname', '\psi_s');
m.parameter('thetas', thetas, 'long_name', 'Wage elasticity of demand', 'texname', '\theta_s');
m.parameter('xiw', xiw, 'long_name', 'Calvo wage stickiness', 'texname', '\xi_w');
m.parameter('gammaw', gammaw, 'long_name', 'Wage indexation', 'texname', '\gamma_w');

%% Parameters — Monetary authority
if ~WITH_EFFICIENT_BLOCK
    m.parameter('ssGDP', GDP_ss, 'texname', '\bar Y');
end
m.parameter('steady_state_nominal_interest_factor', steady_state_nominal_interest_factor, 'long_name', 'Steady-state nominal interest factor', 'texname', '\bar R');
m.parameter('nominal_interest_rate_smoothing', nominal_interest_rate_smoothing, 'long_name', 'Interest rate smoothing', 'texname', '\rho_R');
m.parameter('elasticity_of_nominal_interest_rate_to_inflation', elasticity_of_nominal_interest_rate_to_inflation, 'long_name', 'Taylor rule inflation coefficient', 'texname', 'r_{\pi}');
m.parameter('elasticity_of_nominal_interest_rate_to_output_gap', elasticity_of_nominal_interest_rate_to_output_gap, 'long_name', 'Taylor rule output gap coefficient', 'texname', 'r_y');
m.parameter('elasticity_of_nominal_interest_rate_to_inflation_growth', elasticity_of_nominal_interest_rate_to_inflation_growth, 'long_name', 'Taylor rule inflation growth coefficient', 'texname', 'r_{\Delta \pi}');
m.parameter('elasticity_of_nominal_interest_rate_to_output_gap_growth', elasticity_of_nominal_interest_rate_to_output_gap_growth, 'long_name', 'Taylor rule output gap growth coefficient', 'texname', 'r_{\Delta y}');

%% Exogenous process parameters and innovations
% Already declared per shock by declare_arma_shock in the shock-processes loop
% above: the ARMA coefficients <prefix>_phi*/<prefix>_theta*/<prefix>_i_std (with
% TeX names) and the exogenous innovations (with their TeX names).

%% Endogenous variables — tex_names and long_names
m.endogenous('Consumption', [], 'long_name', 'Detrended consumption', 'texname', 'C');
m.endogenous('HouseholdLabourSupply', [], 'long_name', 'Household labour supply', 'texname', 'L');
m.endogenous('HouseholdLagrangeMultiplier', [], 'long_name', 'Marginal utility of wealth', 'texname', '\lambda');
m.endogenous('Investment', [], 'long_name', 'Detrended investment', 'texname', 'I');
m.endogenous('CapitalStock', [], 'long_name', 'Physical capital stock', 'texname', '\bar K');
m.endogenous('DepreciationRate', [], 'long_name', 'Depreciation rate', 'texname', '\delta');
m.endogenous('dDepreciationRate', [], 'long_name', 'Marginal depreciation rate', 'texname', '\delta''');
m.endogenous('InvestmentCost', [], 'long_name', 'Investment adjustment cost', 'texname', 'S');
m.endogenous('dInvestmentCost', [], 'long_name', 'Marginal investment adj. cost', 'texname', 'S''');
m.endogenous('CapacityUtilizationFactor', [], 'long_name', 'Capacity utilisation rate', 'texname', 'z');
m.endogenous('CapitalReturnRate', [], 'long_name', 'Real rental rate of capital', 'texname', 'r^k');
m.endogenous('HouseholdRealWage', [], 'long_name', 'Household real wage', 'texname', 'w^h');
m.endogenous('TobinQ', [], 'long_name', 'Tobin Q', 'texname', 'Q');
m.endogenous('RealGrossWage', [], 'long_name', 'Gross real wage', 'texname', 'w');
m.endogenous('LabourDemand', [], 'long_name', 'Labour demand', 'texname', 'L^d');
m.endogenous('CapitalDemand', [], 'long_name', 'Effective capital', 'texname', 'K');
m.endogenous('RealMarginalCost', [], 'long_name', 'Real marginal cost', 'texname', 'mc');
m.endogenous('OptimalRelativePrice', [], 'long_name', 'Optimal relative price', 'texname', '\breve p');
m.endogenous('Z1', [], 'long_name', 'Price recursion variable', 'texname', 'Z_1');
m.endogenous('Z2', [], 'long_name', 'Price recursion variable', 'texname', 'Z_2');
m.endogenous('Z3', [], 'long_name', 'Price recursion variable', 'texname', 'Z_3');
m.endogenous('GDP', [], 'long_name', 'Detrended output', 'texname', 'Y');
m.endogenous('FinalGoodLagrangeMultiplier', [], 'long_name', 'Kimball price aggregator', 'texname', '\Lambda^f');
m.endogenous('NonOptimizingFirmsPriceGrowth', [], 'long_name', 'Non-optimiser price growth', 'texname', '\pi^{np}');
m.endogenous('AveragedRelativePrices', [], 'long_name', 'Average relative price', 'texname', '\tilde p');
m.endogenous('PriceDistorsion', [], 'long_name', 'Price dispersion', 'texname', '\Delta^p');
m.endogenous('NablaPrice', [], 'long_name', 'Price recursion variable', 'texname', '\nabla^p');
m.endogenous('InflationFactor', [], 'long_name', 'Gross inflation', 'texname', '\pi');
m.endogenous('RealWageGrowthFactor', [], 'long_name', 'Real wage growth', 'texname', '\omega');
m.endogenous('AveragedRelativeWages', [], 'long_name', 'Average relative wage', 'texname', '\tilde w');
m.endogenous('OptimalRelativeRealWage', [], 'long_name', 'Optimal relative wage', 'texname', '\breve w');
m.endogenous('H1', [], 'long_name', 'Wage recursion variable', 'texname', 'H_1');
m.endogenous('H2', [], 'long_name', 'Wage recursion variable', 'texname', 'H_2');
m.endogenous('H3', [], 'long_name', 'Wage recursion variable', 'texname', 'H_3');
m.endogenous('EmploymentAgencyLagrangeMultiplier', [], 'long_name', 'Kimball wage aggregator', 'texname', '\Lambda^s');
m.endogenous('EmploymentAgencyLabourSupply', [], 'long_name', 'Employment agency labour supply', 'texname', 'L^s');
m.endogenous('NonOptimizingUnionsWageGrowth', [], 'long_name', 'Non-optimiser wage growth', 'texname', '\omega^{nw}');
m.endogenous('WageDistorsion', [], 'long_name', 'Wage dispersion', 'texname', '\Delta^w');
m.endogenous('NablaWage', [], 'long_name', 'Wage recursion variable', 'texname', '\nabla^w');
m.endogenous('NominalInterestFactor', [], 'long_name', 'Gross nominal interest rate', 'texname', 'R');
m.endogenous('OutputGap', [], 'long_name', 'Output gap', 'texname', '\mathcal{G}');
m.endogenous('PublicSpending', [], 'long_name', 'Government spending', 'texname', 'G');
% Shock endogenous variables
m.endogenous('ProductionEfficiencyGrowth', [], 'long_name', 'Technology growth rate', 'texname', 'g');
m.endogenous('ProductionEfficiencyCycle', [], 'long_name', 'Stationary technology level', 'texname', 'A');
m.endogenous('ConsumptionTax', [], 'long_name', 'Consumption tax', 'texname', '\tau^C');
m.endogenous('LabourIncomeTax', [], 'long_name', 'Labour income tax', 'texname', '\tau^W');
m.endogenous('IncomeTax', [], 'long_name', 'Income tax', 'texname', '\tau^R');
m.endogenous('RiskPremium', [], 'long_name', 'Risk premium shock', 'texname', '\varepsilon^B');
m.endogenous('LabourSupplyShock', [], 'long_name', 'Labour supply shock', 'texname', '\varepsilon^L');
m.endogenous('InvestmentRelativePrice', [], 'long_name', 'Investment relative price', 'texname', 'p^I');
m.endogenous('InvestmentEfficiencyShock', [], 'long_name', 'Investment efficiency', 'texname', '\varepsilon^I');
m.endogenous('LabourTax', [], 'long_name', 'Employer labour tax', 'texname', '\tau^L');
m.endogenous('PriceCostPushShock', [], 'long_name', 'Price cost-push shock', 'texname', '\nu^p');
m.endogenous('WageCostPushShock', [], 'long_name', 'Wage cost-push shock', 'texname', '\nu^w');
m.endogenous('InflationTarget', [], 'long_name', 'Inflation target', 'texname', '\bar\pi');
m.endogenous('TaylorShock', [], 'long_name', 'Monetary policy shock', 'texname', '\varepsilon^R');
m.endogenous('PublicSpendingShare', [], 'long_name', 'Public spending share', 'texname', '\varepsilon^g');
m.endogenous('HabitShock', [], 'long_name', 'Habit shock', 'texname', '\eta^s');
m.endogenous('PreferenceShock', [], 'long_name', 'Preference shock', 'texname', '\varsigma');
% Efficient block endogenous variables
if WITH_EFFICIENT_BLOCK
    m.endogenous('EfficientConsumption', [], 'texname', 'C^e');
    m.endogenous('EfficientHouseholdLabourSupply', [], 'texname', 'L^e');
    m.endogenous('EfficientHouseholdLagrangeMultiplier', [], 'texname', '\lambda^e');
    m.endogenous('EfficientInvestment', [], 'texname', 'I^e');
    m.endogenous('EfficientCapitalStock', [], 'texname', '\bar K^e');
    m.endogenous('EfficientDepreciationRate', [], 'texname', '\delta^e');
    m.endogenous('dEfficientDepreciationRate', [], 'texname', '\delta^{\prime e}');
    m.endogenous('EfficientInvestmentCost', [], 'texname', 'S^e');
    m.endogenous('dEfficientInvestmentCost', [], 'texname', 'S^{\prime e}');
    m.endogenous('EfficientCapacityUtilizationFactor', [], 'texname', 'z^e');
    m.endogenous('EfficientCapitalReturnRate', [], 'texname', 'r^{k,e}');
    m.endogenous('EfficientHouseholdRealWage', [], 'texname', 'w^{h,e}');
    m.endogenous('EfficientTobinQ', [], 'texname', 'Q^e');
    m.endogenous('EfficientRealInterestFactor', [], 'texname', 'r^e');
    m.endogenous('EfficientLabourDemand', [], 'texname', 'L^{d,e}');
    m.endogenous('EfficientRealMarginalCost', [], 'texname', 'mc^e');
    m.endogenous('EfficientGDP', [], 'texname', 'Y^e');
    m.endogenous('EfficientCapitalDemand', [], 'texname', 'K^e');
    m.endogenous('EfficientRealGrossWage', [], 'texname', 'w^e');
end

% Entry point for the companion scripts: setting SW_BUILD_ONLY = true before
% running sw.m returns the model -- equations, parameters, shocks, metadata --
% WITHOUT the analytical steady state below and without exporting anything, so
% the caller can derive the steady state itself instead of reading the one
% written here. sw_from_anchors.m uses it that way, deriving all 78 closed
% forms with steady_plan from a handful of declared anchors.
if exist('SW_BUILD_ONLY', 'var') && SW_BUILD_ONLY
    return
end

% =========================================================================
%  STEADY STATE (analytical expressions)
% =========================================================================
% Only 5 irreducible calibration constants require numerical values.
% Everything else is derived from model parameters and other steady-state
% endogenous variables.

ss = @(x) sprintf('%.16g', x);

%% No price/wage dispersion at steady state
m.steady('FinalGoodLagrangeMultiplier', '1');
m.steady('AveragedRelativePrices', '1');
m.steady('PriceDistorsion', '1');
m.steady('NablaPrice', '1');
m.steady('OptimalRelativePrice', '1');
m.steady('EmploymentAgencyLagrangeMultiplier', '1');
m.steady('RealWageGrowthFactor', '1');
m.steady('AveragedRelativeWages', '1');
m.steady('OptimalRelativeRealWage', '1');
m.steady('WageDistorsion', '1');
m.steady('NablaWage', '1');
m.steady('TobinQ', '1');
m.steady('OutputGap', '1');
m.steady('InvestmentCost', '0');
m.steady('dInvestmentCost', '0');

%% Shock processes with trivial steady state
m.steady('ProductionEfficiencyCycle', '1');
m.steady('ConsumptionTax', '1');
m.steady('LabourIncomeTax', '1');
m.steady('IncomeTax', '1');
m.steady('RiskPremium', '1');
m.steady('InvestmentRelativePrice', '1');
m.steady('InvestmentEfficiencyShock', '1');
m.steady('LabourTax', '1');
m.steady('PriceCostPushShock', '1');
m.steady('WageCostPushShock', '1');
m.steady('TaylorShock', '1');
m.steady('HabitShock', '1');
m.steady('PreferenceShock', '1');

%% Calibration anchors (irreducible numerical values)
m.steady('InflationTarget', ss(inflation_target_ss));
m.steady('PublicSpendingShare', ss(public_spending_ss));
m.steady('CapacityUtilizationFactor', 'capacity_utilization_factor_ss');
m.steady('DepreciationRate', 'depreciation_rate_ss');
m.steady('HouseholdLabourSupply', 'household_labour_supply_ss');

%% Nominal block
m.steady('NominalInterestFactor', 'steady_state_nominal_interest_factor');
m.steady('ProductionEfficiencyGrowth', '(beta*RiskPremium*NominalInterestFactor/InflationTarget)^(1/sigmac)');
m.steady('NonOptimizingFirmsPriceGrowth', 'InflationTarget');
m.steady('InflationFactor', 'InflationTarget');
m.steady('NonOptimizingUnionsWageGrowth', 'InflationTarget');

%% Prices and markups (from Kimball price/wage decisions)
m.steady('RealMarginalCost', '(thetaf-1)/thetaf');
m.steady('CapitalReturnRate', '(ProductionEfficiencyGrowth^sigmac-beta*(1-DepreciationRate))/(beta*IncomeTax*CapacityUtilizationFactor)');
m.steady('dDepreciationRate', 'CapitalReturnRate*IncomeTax');

%% Wages
m.steady('RealGrossWage', '(RealMarginalCost*(alpha/CapitalReturnRate)^alpha)^(1/(1-alpha))*(1-alpha)/LabourTax*ProductionEfficiencyCycle');
m.steady('HouseholdRealWage', 'RealGrossWage*(thetas-1)/thetas');

%% Labour market
m.steady('LabourDemand', 'HouseholdLabourSupply');
m.steady('EmploymentAgencyLabourSupply', 'HouseholdLabourSupply');

%% Output, capital, and expenditure
m.steady('CapitalDemand', 'LabourTax*RealGrossWage/CapitalReturnRate*alpha/(1-alpha)*HouseholdLabourSupply');
m.steady('GDP', 'CapitalDemand^alpha*(ProductionEfficiencyCycle*LabourDemand)^(1-alpha)');
m.steady('CapitalStock', 'CapitalDemand*ProductionEfficiencyGrowth/CapacityUtilizationFactor');
m.steady('Investment', 'CapitalDemand*(ProductionEfficiencyGrowth-1+DepreciationRate)/CapacityUtilizationFactor');
m.steady('Consumption', '(1-PublicSpendingShare)*GDP-Investment');
m.steady('PublicSpending', 'PublicSpendingShare*GDP');

%% Labour supply shock: its long-run level labour_supply_ss is the calibration
%% lever pinning HouseholdLabourSupply (set from the consumption-leisure FOC above).
m.steady('LabourSupplyShock', 'HouseholdLabourSupply*IncomeTax*LabourIncomeTax*HouseholdRealWage/(ConsumptionTax*Consumption*(1-eta/ProductionEfficiencyGrowth))');

%% Household Lagrange multiplier (from consumption FOC)
m.steady('HouseholdLagrangeMultiplier', '(1/ConsumptionTax)*(Consumption*(1-eta/ProductionEfficiencyGrowth))^(-sigmac)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal))');

%% Recursive price and wage setting auxiliaries
m.steady('Z1', 'RealMarginalCost*HouseholdLagrangeMultiplier*GDP/(1-beta*xip*ProductionEfficiencyGrowth^(1-sigmac))');
m.steady('Z2', 'Z1/RealMarginalCost');
m.steady('Z3', 'Z2');
m.steady('H1', 'HouseholdRealWage*HouseholdLagrangeMultiplier*EmploymentAgencyLabourSupply/(1-beta*xiw*ProductionEfficiencyGrowth^(1-sigmac))');
m.steady('H2', 'H1*thetas/(thetas-1)');
m.steady('H3', 'H2');

%% Efficient block (equals core model at steady state)
if WITH_EFFICIENT_BLOCK
    m.steady('EfficientConsumption', 'Consumption');
    m.steady('EfficientHouseholdLabourSupply', 'HouseholdLabourSupply');
    m.steady('EfficientHouseholdLagrangeMultiplier', 'HouseholdLagrangeMultiplier');
    m.steady('EfficientInvestment', 'Investment');
    m.steady('EfficientCapitalStock', 'CapitalStock');
    m.steady('EfficientDepreciationRate', 'DepreciationRate');
    m.steady('dEfficientDepreciationRate', 'dDepreciationRate');
    m.steady('EfficientInvestmentCost', '0');
    m.steady('dEfficientInvestmentCost', '0');
    m.steady('EfficientCapacityUtilizationFactor', 'CapacityUtilizationFactor');
    m.steady('EfficientCapitalReturnRate', 'CapitalReturnRate');
    m.steady('EfficientHouseholdRealWage', 'HouseholdRealWage');
    m.steady('EfficientTobinQ', '1');
    m.steady('EfficientRealInterestFactor', 'NominalInterestFactor/InflationTarget');
    m.steady('EfficientLabourDemand', 'LabourDemand');
    m.steady('EfficientRealMarginalCost', 'RealMarginalCost');
    m.steady('EfficientGDP', 'GDP');
    m.steady('EfficientCapitalDemand', 'CapitalDemand');
    m.steady('EfficientRealGrossWage', 'RealGrossWage');
end

% =========================================================================
%  WRITE MOD FILE
% =========================================================================

m.write('sw', steady_state_model=true, steady=true, check=true);
