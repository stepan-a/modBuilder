var HouseholdLagrangeMultiplier $\lambda$ (long_name='Marginal utility of wealth')
	NominalInterestFactor $R$ (long_name='Gross nominal interest rate')
	Consumption $C$ (long_name='Detrended consumption')
	TobinQ $Q$ (long_name='Tobin Q')
	DepreciationRate $\delta$ (long_name='Depreciation rate')
	dDepreciationRate $\delta'$ (long_name='Marginal depreciation rate')
	CapitalReturnRate $r^k$ (long_name='Real rental rate of capital')
	CapacityUtilizationFactor $z$ (long_name='Capacity utilisation rate')
	CapitalStock $\bar K$ (long_name='Physical capital stock')
	InvestmentCost $S$ (long_name='Investment adjustment cost')
	dInvestmentCost $S'$ (long_name='Marginal investment adj. cost')
	NonOptimizingFirmsPriceGrowth $\pi^{np}$ (long_name='Non-optimiser price growth')
	RealGrossWage $w$ (long_name='Gross real wage')
	RealMarginalCost $mc$ (long_name='Real marginal cost')
	OptimalRelativePrice $\breve p$ (long_name='Optimal relative price')
	InflationFactor $\pi$ (long_name='Gross inflation')
	Z1 $Z_1$ (long_name='Price recursion variable')
	Z2 $Z_2$ (long_name='Price recursion variable')
	Z3 $Z_3$ (long_name='Price recursion variable')
	AveragedRelativePrices $\tilde p$ (long_name='Average relative price')
	FinalGoodLagrangeMultiplier $\Lambda^f$ (long_name='Kimball price aggregator')
	PriceDistorsion $\Delta^p$ (long_name='Price dispersion')
	NablaPrice $\nabla^p$ (long_name='Price recursion variable')
	NonOptimizingUnionsWageGrowth $\omega^{nw}$ (long_name='Non-optimiser wage growth')
	RealWageGrowthFactor $\omega$ (long_name='Real wage growth')
	H1 $H_1$ (long_name='Wage recursion variable')
	OptimalRelativeRealWage $\breve w$ (long_name='Optimal relative wage')
	HouseholdRealWage $w^h$ (long_name='Household real wage')
	H2 $H_2$ (long_name='Wage recursion variable')
	H3 $H_3$ (long_name='Wage recursion variable')
	AveragedRelativeWages $\tilde w$ (long_name='Average relative wage')
	EmploymentAgencyLagrangeMultiplier $\Lambda^s$ (long_name='Kimball wage aggregator')
	WageDistorsion $\Delta^w$ (long_name='Wage dispersion')
	NablaWage $\nabla^w$ (long_name='Wage recursion variable')
	OutputGap $\mathcal{G}$ (long_name='Output gap')
	GDP $Y$ (long_name='Detrended output')
	PublicSpending $G$ (long_name='Government spending')
	CapitalDemand $K$ (long_name='Effective capital')
	HouseholdLabourSupply $L$ (long_name='Household labour supply')
	EmploymentAgencyLabourSupply $L^s$ (long_name='Employment agency labour supply')
	LabourDemand $L^d$ (long_name='Labour demand')
	Investment $I$ (long_name='Detrended investment')
	ProductionEfficiencyGrowth $g$ (long_name='Technology growth rate')
	ProductionEfficiencyCycle $A$ (long_name='Stationary technology level')
	ConsumptionTax $\tau^C$ (long_name='Consumption tax')
	LabourIncomeTax $\tau^W$ (long_name='Labour income tax')
	IncomeTax $\tau^R$ (long_name='Income tax')
	RiskPremium $\varepsilon^B$ (long_name='Risk premium shock')
	LabourSupplyShock $\varepsilon^L$ (long_name='Labour supply shock')
	InvestmentRelativePrice $p^I$ (long_name='Investment relative price')
	InvestmentEfficiencyShock $\varepsilon^I$ (long_name='Investment efficiency')
	LabourTax $\tau^L$ (long_name='Employer labour tax')
	PriceCostPushShock $\nu^p$ (long_name='Price cost-push shock')
	WageCostPushShock $\nu^w$ (long_name='Wage cost-push shock')
	InflationTarget $\bar\pi$ (long_name='Inflation target')
	TaylorShock $\varepsilon^R$ (long_name='Monetary policy shock')
	PublicSpendingShare $\varepsilon^g$ (long_name='Public spending share')
	HabitShock $\eta^s$ (long_name='Habit shock')
	PreferenceShock $\varsigma$ (long_name='Preference shock')
	EfficientHouseholdLagrangeMultiplier $\lambda^e$
	EfficientRealInterestFactor $r^e$
	EfficientConsumption $C^e$
	EfficientTobinQ $Q^e$
	EfficientDepreciationRate $\delta^e$
	dEfficientDepreciationRate $\delta^{\prime e}$
	EfficientCapitalReturnRate $r^{k,e}$
	EfficientCapacityUtilizationFactor $z^e$
	EfficientCapitalStock $\bar K^e$
	EfficientLabourDemand $L^{d,e}$
	EfficientRealGrossWage $w^e$
	EfficientRealMarginalCost $mc^e$
	EfficientHouseholdRealWage $w^{h,e}$
	EfficientHouseholdLabourSupply $L^e$
	EfficientCapitalDemand $K^e$
	EfficientInvestment $I^e$
	EfficientGDP $Y^e$
	EfficientInvestmentCost $S^e$
	dEfficientInvestmentCost $S^{\prime e}$
	;

varexo EfficiencyGrowthInnovation $\epsilon_g$
	EfficiencyCycleInnovation $\epsilon_A$
	ConsumptionTaxInnovation $\epsilon_{\tau^C}$
	LabourIncomeTaxInnovation $\epsilon_{\tau^W}$
	IncomeTaxInnovation $\epsilon_{\tau^R}$
	RiskPremiumInnovation $\epsilon_B$
	LabourSupplyInnovation $\epsilon_L$
	InvestmentRelativePriceInnovation $\epsilon_{p^I}$
	InvestmentEfficiencyInnovation $\epsilon_I$
	LabourTaxInnovation $\epsilon_{\tau^L}$
	PriceCostPushInnovation $\epsilon_{\nu^p}$
	WageCostPushInnovation $\epsilon_{\nu^w}$
	InflationTargetInnovation $\epsilon_{\bar\pi}$
	TaylorInnovation $\epsilon_R$
	PublicSpendingShareInnovation $\epsilon_{\varepsilon^g}$
	HabitInnovation $\epsilon_{\eta^s}$
	PreferenceInnovation $\epsilon_\varsigma$
	;

parameters production_efficiency_growth_phi1 $\phi_{A_T,1}$
	production_efficiency_growth_i_std $\sigma_{A_T}$
	production_efficiency_growth_ss ${A_T}^{\star}$
	production_efficiency_phi1 $\phi_{A_C,1}$
	production_efficiency_i_std $\sigma_{A_C}$
	production_efficiency_ss ${A_C}^{\star}$
	consumption_tax_phi1 $\phi_{\tau_C,1}$
	consumption_tax_i_std $\sigma_{\tau_C}$
	consumption_tax_ss ${\tau_C}^{\star}$
	labour_income_tax_phi1 $\phi_{\tau_W,1}$
	labour_income_tax_i_std $\sigma_{\tau_W}$
	labour_income_tax_ss ${\tau_W}^{\star}$
	income_tax_phi1 $\phi_{\tau_R,1}$
	income_tax_i_std $\sigma_{\tau_R}$
	income_tax_ss ${\tau_R}^{\star}$
	risk_premium_phi1 $\phi_{\varepsilon_B,1}$
	risk_premium_i_std $\sigma_{\varepsilon_B}$
	risk_premium_ss ${\varepsilon_B}^{\star}$
	labour_supply_phi1 $\phi_{\varepsilon_L,1}$
	labour_supply_i_std $\sigma_{\varepsilon_L}$
	labour_supply_ss ${\varepsilon_L}^{\star}$
	investment_relative_price_phi1 $\phi_{p_I,1}$
	investment_relative_price_i_std $\sigma_{p_I}$
	investment_relative_price_ss ${p_I}^{\star}$
	investment_efficiency_phi1 $\phi_{\varepsilon_I,1}$
	investment_efficiency_i_std $\sigma_{\varepsilon_I}$
	investment_efficiency_ss ${\varepsilon_I}^{\star}$
	labour_tax_phi1 $\phi_{\tau_L,1}$
	labour_tax_i_std $\sigma_{\tau_L}$
	labour_tax_ss ${\tau_L}^{\star}$
	price_cost_push_phi1 $\phi_{\nu^p,1}$
	price_cost_push_theta1 $\theta_{\nu^p,1}$
	price_cost_push_i_std $\sigma_{\nu^p}$
	price_cost_push_ss ${\nu^p}^{\star}$
	wage_cost_push_phi1 $\phi_{\nu^w,1}$
	wage_cost_push_theta1 $\theta_{\nu^w,1}$
	wage_cost_push_i_std $\sigma_{\nu^w}$
	wage_cost_push_ss ${\nu^w}^{\star}$
	inflation_target_phi1 $\phi_{\bar\pi,1}$
	inflation_target_i_std $\sigma_{\bar\pi}$
	inflation_target_ss ${\bar\pi}^{\star}$
	taylor_phi1 $\phi_{\varepsilon_R,1}$
	taylor_i_std $\sigma_{\varepsilon_R}$
	taylor_ss ${\varepsilon_R}^{\star}$
	public_spending_phi1 $\phi_{\varepsilon_g,1}$
	public_spending_i_std $\sigma_{\varepsilon_g}$
	public_spending_ss ${\varepsilon_g}^{\star}$
	habit_phi1 $\phi_{\eta^s,1}$
	habit_i_std $\sigma_{\eta^s}$
	habit_ss ${\eta^s}^{\star}$
	preference_phi1 $\phi_{\varsigma,1}$
	preference_i_std $\sigma_{\varsigma}$
	preference_ss ${\varsigma}^{\star}$
	sigmac $\sigma_c$ (long_name='Risk aversion')
	sigmal $\sigma_l$ (long_name='Inverse Frisch elasticity')
	household_labour_supply_ss $L^{\star}$ (long_name='Steady-state household labour supply')
	eta $\eta$ (long_name='Habit formation')
	beta $\beta$ (long_name='Discount factor')
	investment_cost_size $\psi$ (long_name='Investment adjustment cost')
	depreciation_rate_ss $\delta^{\star}$ (long_name='Steady-state depreciation rate')
	capacity_utilization_factor_ss $z^{\star}$ (long_name='Steady-state capacity utilisation')
	depreciation_curvature $\kappa_\delta$ (long_name='Depreciation elasticity to utilisation')
	alpha $\alpha$ (long_name='Capital share')
	thetaf $\theta_f$ (long_name='Price elasticity of demand')
	psif $\psi_f$ (long_name='Kimball curvature (goods)')
	xip $\xi_p$ (long_name='Calvo price stickiness')
	gammap $\gamma_p$ (long_name='Price indexation')
	psis $\psi_s$ (long_name='Kimball curvature (labour)')
	thetas $\theta_s$ (long_name='Wage elasticity of demand')
	xiw $\xi_w$ (long_name='Calvo wage stickiness')
	gammaw $\gamma_w$ (long_name='Wage indexation')
	steady_state_nominal_interest_factor $R^{\star}$ (long_name='Steady-state nominal interest factor')
	nominal_interest_rate_smoothing $\rho_R$ (long_name='Interest rate smoothing')
	elasticity_of_nominal_interest_rate_to_inflation $r_{\pi}$ (long_name='Taylor rule inflation coefficient')
	elasticity_of_nominal_interest_rate_to_output_gap $r_y$ (long_name='Taylor rule output gap coefficient')
	elasticity_of_nominal_interest_rate_to_inflation_growth $r_{\Delta \pi}$ (long_name='Taylor rule inflation growth coefficient')
	elasticity_of_nominal_interest_rate_to_output_gap_growth $r_{\Delta y}$ (long_name='Taylor rule output gap growth coefficient')
	;

production_efficiency_growth_phi1 = 0.391900;
production_efficiency_growth_i_std = 0.000000;
production_efficiency_growth_ss = 1.003100;
production_efficiency_phi1 = 0.950000;
production_efficiency_i_std = 0.001405;
production_efficiency_ss = 1.000000;
consumption_tax_phi1 = 0.000000;
consumption_tax_i_std = 0.000000;
consumption_tax_ss = 1.000000;
labour_income_tax_phi1 = 0.000000;
labour_income_tax_i_std = 0.000000;
labour_income_tax_ss = 1.000000;
income_tax_phi1 = 0.000000;
income_tax_i_std = 0.000000;
income_tax_ss = 1.000000;
risk_premium_phi1 = 0.220000;
risk_premium_i_std = 0.002341;
risk_premium_ss = 1.000000;
labour_supply_phi1 = 0.939000;
labour_supply_i_std = 0.000000;
labour_supply_ss = 2.880332;
investment_relative_price_phi1 = 0.710000;
investment_relative_price_i_std = 0.000000;
investment_relative_price_ss = 1.000000;
investment_efficiency_phi1 = 0.710000;
investment_efficiency_i_std = 0.003169;
investment_efficiency_ss = 1.000000;
labour_tax_phi1 = 0.000000;
labour_tax_i_std = 0.000000;
labour_tax_ss = 1.000000;
price_cost_push_phi1 = 0.902558;
price_cost_push_theta1 = -0.013463;
price_cost_push_i_std = 0.000610;
price_cost_push_ss = 1.000000;
wage_cost_push_phi1 = 0.958629;
wage_cost_push_theta1 = 0.199636;
wage_cost_push_i_std = 0.000573;
wage_cost_push_ss = 1.000000;
inflation_target_phi1 = 0.000000;
inflation_target_i_std = 0.000000;
inflation_target_ss = 1.005000;
taylor_phi1 = 0.150000;
taylor_i_std = 0.002373;
taylor_ss = 1.000000;
public_spending_phi1 = 0.970000;
public_spending_i_std = 0.001288;
public_spending_ss = 0.180000;
habit_phi1 = 0.980000;
habit_i_std = 0.000000;
habit_ss = 1.000000;
preference_phi1 = 0.900000;
preference_i_std = 0.000000;
preference_ss = 1.000000;
sigmac = 1.380000;
sigmal = 1.920000;
household_labour_supply_ss = 0.271200;
eta = 0.710000;
beta = 0.999309;
investment_cost_size = 0.175300;
depreciation_rate_ss = 0.025000;
capacity_utilization_factor_ss = 0.801200;
depreciation_curvature = 1.496511;
alpha = 0.190000;
thetaf = 6.178664;
psif = -10.000000;
xip = 0.660003;
gammap = 0.240000;
psis = -10.000000;
thetas = 5.933399;
xiw = 0.699997;
gammaw = 0.580000;
steady_state_nominal_interest_factor = 1.010000;
nominal_interest_rate_smoothing = 0.810000;
elasticity_of_nominal_interest_rate_to_inflation = 2.040000;
elasticity_of_nominal_interest_rate_to_output_gap = 0.080000;
elasticity_of_nominal_interest_rate_to_inflation_growth = 0.000000;
elasticity_of_nominal_interest_rate_to_output_gap_growth = 0.220000;

model;

[name = 'HouseholdLagrangeMultiplier']
PreferenceShock*(Consumption - eta*HabitShock*Consumption(-1)/ProductionEfficiencyGrowth)^(-sigmac)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(HouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal)) - ConsumptionTax*HouseholdLagrangeMultiplier;

[name = 'NominalInterestFactor']
beta*RiskPremium*NominalInterestFactor*ProductionEfficiencyGrowth(1)^(-sigmac)*HouseholdLagrangeMultiplier(1)*IncomeTax(1)/InflationFactor(1) - HouseholdLagrangeMultiplier*IncomeTax;

[name = 'Consumption']
PreferenceShock*(Consumption - eta*HabitShock*Consumption(-1)/ProductionEfficiencyGrowth)^(1-sigmac)*(LabourSupplyShock/household_labour_supply_ss)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(HouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal))*(HouseholdLabourSupply/household_labour_supply_ss)^sigmal - HouseholdLagrangeMultiplier*IncomeTax*LabourIncomeTax*HouseholdRealWage;

[name = 'TobinQ']
TobinQ*(1-InvestmentCost-Investment/Investment(-1)*ProductionEfficiencyGrowth*dInvestmentCost)+beta*HouseholdLagrangeMultiplier(1)/HouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*TobinQ(1)*InvestmentEfficiencyShock(1)/InvestmentEfficiencyShock*(Investment(1)/Investment*ProductionEfficiencyGrowth(1))^2*dInvestmentCost(1) - InvestmentRelativePrice/InvestmentEfficiencyShock;

[name = 'DepreciationRate']
depreciation_rate_ss*exp((CapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - DepreciationRate;

[name = 'dDepreciationRate']
depreciation_rate_ss*depreciation_curvature*exp((CapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - dDepreciationRate;

[name = 'CapitalReturnRate']
IncomeTax*CapitalReturnRate - TobinQ*dDepreciationRate;

[name = 'CapacityUtilizationFactor']
beta*HouseholdLagrangeMultiplier(1)/HouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*(TobinQ(1)*(1-DepreciationRate(1))+IncomeTax(1)*CapitalReturnRate(1)*CapacityUtilizationFactor(1)) - TobinQ;

[name = 'CapitalStock']
(1-DepreciationRate)*CapitalStock(-1)/ProductionEfficiencyGrowth+InvestmentEfficiencyShock*(1-InvestmentCost)*Investment - CapitalStock;

[name = 'InvestmentCost']
InvestmentCost = .5*investment_cost_size*production_efficiency_growth_ss*production_efficiency_growth_ss*(Investment/Investment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)^2;

[name = 'dInvestmentCost']
dInvestmentCost = (Investment/Investment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)*production_efficiency_growth_ss*investment_cost_size;

[name = 'NonOptimizingFirmsPriceGrowth']
InflationTarget^(1-gammap)*InflationFactor(-1)^gammap - NonOptimizingFirmsPriceGrowth;

[name = 'RealGrossWage']
LabourTax*RealGrossWage*LabourDemand/(CapitalReturnRate*CapitalDemand) - (1-alpha)/alpha;

[name = 'RealMarginalCost']
ProductionEfficiencyCycle^(alpha-1)*(CapitalReturnRate/alpha)^alpha*(LabourTax*RealGrossWage/(1-alpha))^(1-alpha) - RealMarginalCost;

[name = 'OptimalRelativePrice']
thetaf*(1+psif)/(thetaf*(1+psif)-1)*(Z1/Z2)+psif/(thetaf*(1+psif)-1)*OptimalRelativePrice^(1+(1+psif)*thetaf)*Z3/Z2 - OptimalRelativePrice;

[name = 'InflationFactor']
(1-xip)*OptimalRelativePrice^(1-thetaf*(1+psif))+xip*(NonOptimizingFirmsPriceGrowth/InflationFactor)^(1-thetaf*(1+psif))*FinalGoodLagrangeMultiplier(-1)^(1-thetaf*(1+psif)) - FinalGoodLagrangeMultiplier^(1-thetaf*(1+psif));

[name = 'Z1']
HouseholdLagrangeMultiplier*RealMarginalCost*PriceCostPushShock*FinalGoodLagrangeMultiplier^(thetaf*(1+psif))*GDP+beta*xip*ProductionEfficiencyGrowth(1)^(1-sigmac)*(InflationFactor(1)/NonOptimizingFirmsPriceGrowth)^((1+psif)*thetaf)*Z1(1) - Z1;

[name = 'Z2']
HouseholdLagrangeMultiplier*FinalGoodLagrangeMultiplier^(thetaf*(1+psif))*GDP+beta*xip*ProductionEfficiencyGrowth(1)^(1-sigmac)*(InflationFactor(1)/NonOptimizingFirmsPriceGrowth)^((1+psif)*thetaf-1)*Z2(1) - Z2;

[name = 'Z3']
HouseholdLagrangeMultiplier*GDP+beta*xip*ProductionEfficiencyGrowth(1)^(1-sigmac)*NonOptimizingFirmsPriceGrowth/InflationFactor(1)*Z3(1) - Z3;

[name = 'AveragedRelativePrices']
(1-xip)*OptimalRelativePrice+xip*NonOptimizingFirmsPriceGrowth/InflationFactor*AveragedRelativePrices(-1) - AveragedRelativePrices;

[name = 'FinalGoodLagrangeMultiplier']
psif*AveragedRelativePrices/(1+psif)+FinalGoodLagrangeMultiplier/(1+psif) - 1;

[name = 'PriceDistorsion']
psif/(1+psif)+NablaPrice/(1+psif)*FinalGoodLagrangeMultiplier^(thetaf*(1+psif)) - PriceDistorsion;

[name = 'NablaPrice']
(1-xip)*OptimalRelativePrice^(-(1+psif)*thetaf)+xip*NablaPrice(-1)*(NonOptimizingFirmsPriceGrowth/InflationFactor)^(-thetaf*(1+psif)) - NablaPrice;

[name = 'NonOptimizingUnionsWageGrowth']
InflationFactor^gammaw*InflationTarget^(1-gammaw) - NonOptimizingUnionsWageGrowth;

[name = 'RealWageGrowthFactor']
RealGrossWage/RealGrossWage(-1) - RealWageGrowthFactor;

[name = 'H1']
thetas*(1+psis)/(thetas*(1+psis)-1)*H1/H2+psis/(thetas*(1+psis)-1)*OptimalRelativeRealWage^(1+(1+psis)*thetas)*H3/H2 - OptimalRelativeRealWage;

[name = 'OptimalRelativeRealWage']
(1-xiw)*OptimalRelativeRealWage^(1-thetas*(1+psis))+xiw*(NonOptimizingUnionsWageGrowth/(RealWageGrowthFactor*InflationFactor))^(1-thetas*(1+psis))*EmploymentAgencyLagrangeMultiplier(-1)^(1-thetas*(1+psis)) - EmploymentAgencyLagrangeMultiplier^(1-thetas*(1+psis));

[name = 'HouseholdRealWage']
HouseholdLagrangeMultiplier*HouseholdRealWage*WageCostPushShock*EmploymentAgencyLagrangeMultiplier^(thetas*(1+psis))*EmploymentAgencyLabourSupply+beta*xiw*ProductionEfficiencyGrowth(1)^(1-sigmac)*(RealWageGrowthFactor(1)*InflationFactor(1)/NonOptimizingUnionsWageGrowth)^((1+psis)*thetas)*H1(1) - H1;

[name = 'H2']
HouseholdLagrangeMultiplier*RealGrossWage*EmploymentAgencyLagrangeMultiplier^(thetas*(1+psis))*EmploymentAgencyLabourSupply+beta*xiw*ProductionEfficiencyGrowth(1)^(1-sigmac)*(RealWageGrowthFactor(1)*InflationFactor(1)/NonOptimizingUnionsWageGrowth)^((1+psis)*thetas-1)*H2(1) - H2;

[name = 'H3']
HouseholdLagrangeMultiplier*RealGrossWage*EmploymentAgencyLabourSupply+beta*xiw*ProductionEfficiencyGrowth(1)^(1-sigmac)*NonOptimizingUnionsWageGrowth/(InflationFactor(1)*RealWageGrowthFactor(1))*H3(1) - H3;

[name = 'AveragedRelativeWages']
(1-xiw)*OptimalRelativeRealWage+xiw*NonOptimizingUnionsWageGrowth/(RealWageGrowthFactor*InflationFactor)*AveragedRelativeWages(-1) - AveragedRelativeWages;

[name = 'EmploymentAgencyLagrangeMultiplier']
psis*AveragedRelativeWages/(1+psis)+EmploymentAgencyLagrangeMultiplier/(1+psis) - 1;

[name = 'WageDistorsion']
psis/(1+psis)+NablaWage/(1+psis)*EmploymentAgencyLagrangeMultiplier^(thetas*(1+psis)) - WageDistorsion;

[name = 'NablaWage']
(1-xiw)*OptimalRelativeRealWage^(-(1+psis)*thetas)+xiw*NablaWage(-1)*(NonOptimizingUnionsWageGrowth/(RealWageGrowthFactor*InflationFactor))^(-thetas*(1+psis)) - NablaWage;

[name = 'OutputGap']
NominalInterestFactor(-1)^nominal_interest_rate_smoothing*(steady_state_nominal_interest_factor*(InflationFactor(-1)/InflationTarget)^elasticity_of_nominal_interest_rate_to_inflation*OutputGap^elasticity_of_nominal_interest_rate_to_output_gap*(InflationFactor/InflationTarget*InflationTarget(-1)/InflationFactor(-1))^elasticity_of_nominal_interest_rate_to_inflation_growth*(OutputGap/OutputGap(-1))^elasticity_of_nominal_interest_rate_to_output_gap_growth)^(1-nominal_interest_rate_smoothing)*TaylorShock - NominalInterestFactor;

[name = 'GDP']
GDP/EfficientGDP - OutputGap;

[name = 'PublicSpending']
PublicSpendingShare*GDP - PublicSpending;

[name = 'CapitalDemand']
CapacityUtilizationFactor*CapitalStock(-1)/ProductionEfficiencyGrowth - CapitalDemand;

[name = 'HouseholdLabourSupply']
HouseholdLabourSupply/WageDistorsion - EmploymentAgencyLabourSupply;

[name = 'EmploymentAgencyLabourSupply']
EmploymentAgencyLabourSupply - LabourDemand;

[name = 'LabourDemand']
CapitalDemand^alpha*(ProductionEfficiencyCycle*LabourDemand)^(1-alpha)/PriceDistorsion - GDP;

[name = 'Investment']
PublicSpending + Consumption + InvestmentRelativePrice*Investment - GDP;

[name = 'ProductionEfficiencyGrowth']
exp(production_efficiency_growth_i_std*(EfficiencyGrowthInnovation))*(ProductionEfficiencyGrowth(-1)/production_efficiency_growth_ss)^production_efficiency_growth_phi1 - ProductionEfficiencyGrowth/production_efficiency_growth_ss;

[name = 'ProductionEfficiencyCycle']
exp(production_efficiency_i_std*(EfficiencyCycleInnovation))*(ProductionEfficiencyCycle(-1)/production_efficiency_ss)^production_efficiency_phi1 - ProductionEfficiencyCycle/production_efficiency_ss;

[name = 'ConsumptionTax']
exp(consumption_tax_i_std*(ConsumptionTaxInnovation))*(ConsumptionTax(-1)/consumption_tax_ss)^consumption_tax_phi1 - ConsumptionTax/consumption_tax_ss;

[name = 'LabourIncomeTax']
exp(labour_income_tax_i_std*(LabourIncomeTaxInnovation))*(LabourIncomeTax(-1)/labour_income_tax_ss)^labour_income_tax_phi1 - LabourIncomeTax/labour_income_tax_ss;

[name = 'IncomeTax']
exp(income_tax_i_std*(IncomeTaxInnovation))*(IncomeTax(-1)/income_tax_ss)^income_tax_phi1 - IncomeTax/income_tax_ss;

[name = 'RiskPremium']
exp(risk_premium_i_std*(RiskPremiumInnovation))*(RiskPremium(-1)/risk_premium_ss)^risk_premium_phi1 - RiskPremium/risk_premium_ss;

[name = 'LabourSupplyShock']
exp(labour_supply_i_std*(LabourSupplyInnovation))*(LabourSupplyShock(-1)/labour_supply_ss)^labour_supply_phi1 - LabourSupplyShock/labour_supply_ss;

[name = 'InvestmentRelativePrice']
exp(investment_relative_price_i_std*(InvestmentRelativePriceInnovation))*(InvestmentRelativePrice(-1)/investment_relative_price_ss)^investment_relative_price_phi1 - InvestmentRelativePrice/investment_relative_price_ss;

[name = 'InvestmentEfficiencyShock']
exp(investment_efficiency_i_std*(InvestmentEfficiencyInnovation))*(InvestmentEfficiencyShock(-1)/investment_efficiency_ss)^investment_efficiency_phi1 - InvestmentEfficiencyShock/investment_efficiency_ss;

[name = 'LabourTax']
exp(labour_tax_i_std*(LabourTaxInnovation))*(LabourTax(-1)/labour_tax_ss)^labour_tax_phi1 - LabourTax/labour_tax_ss;

[name = 'PriceCostPushShock']
exp(price_cost_push_i_std*(PriceCostPushInnovation + price_cost_push_theta1*PriceCostPushInnovation(-1)))*(PriceCostPushShock(-1)/price_cost_push_ss)^price_cost_push_phi1 - PriceCostPushShock/price_cost_push_ss;

[name = 'WageCostPushShock']
exp(wage_cost_push_i_std*(WageCostPushInnovation + wage_cost_push_theta1*WageCostPushInnovation(-1)))*(WageCostPushShock(-1)/wage_cost_push_ss)^wage_cost_push_phi1 - WageCostPushShock/wage_cost_push_ss;

[name = 'InflationTarget']
exp(inflation_target_i_std*(InflationTargetInnovation))*(InflationTarget(-1)/inflation_target_ss)^inflation_target_phi1 - InflationTarget/inflation_target_ss;

[name = 'TaylorShock']
exp(taylor_i_std*(TaylorInnovation))*(TaylorShock(-1)/taylor_ss)^taylor_phi1 - TaylorShock/taylor_ss;

[name = 'PublicSpendingShare']
exp(public_spending_i_std*(PublicSpendingShareInnovation))*(PublicSpendingShare(-1)/public_spending_ss)^public_spending_phi1 - PublicSpendingShare/public_spending_ss;

[name = 'HabitShock']
exp(habit_i_std*(HabitInnovation))*(HabitShock(-1)/habit_ss)^habit_phi1 - HabitShock/habit_ss;

[name = 'PreferenceShock']
exp(preference_i_std*(PreferenceInnovation))*(PreferenceShock(-1)/preference_ss)^preference_phi1 - PreferenceShock/preference_ss;

[name = 'EfficientHouseholdLagrangeMultiplier']
PreferenceShock*(EfficientConsumption - eta*HabitShock*EfficientConsumption(-1)/ProductionEfficiencyGrowth)^(-sigmac)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(EfficientHouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal)) - ConsumptionTax*EfficientHouseholdLagrangeMultiplier;

[name = 'EfficientRealInterestFactor']
beta*RiskPremium*EfficientRealInterestFactor*ProductionEfficiencyGrowth(1)^(-sigmac)*EfficientHouseholdLagrangeMultiplier(1)*IncomeTax(1) - EfficientHouseholdLagrangeMultiplier*IncomeTax;

[name = 'EfficientConsumption']
PreferenceShock*(EfficientConsumption - eta*HabitShock*EfficientConsumption(-1)/ProductionEfficiencyGrowth)^(1-sigmac)*(LabourSupplyShock/household_labour_supply_ss)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal)*(EfficientHouseholdLabourSupply/household_labour_supply_ss)^(1+sigmal))*(EfficientHouseholdLabourSupply/household_labour_supply_ss)^sigmal - EfficientHouseholdLagrangeMultiplier*IncomeTax*LabourIncomeTax*EfficientHouseholdRealWage;

[name = 'EfficientTobinQ']
EfficientTobinQ*(1-EfficientInvestmentCost-EfficientInvestment/EfficientInvestment(-1)*ProductionEfficiencyGrowth*dEfficientInvestmentCost)+beta*EfficientHouseholdLagrangeMultiplier(1)/EfficientHouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*EfficientTobinQ(1)*InvestmentEfficiencyShock(1)/InvestmentEfficiencyShock*(EfficientInvestment(1)/EfficientInvestment*ProductionEfficiencyGrowth(1))^2*dEfficientInvestmentCost(1) - InvestmentRelativePrice/InvestmentEfficiencyShock;

[name = 'EfficientDepreciationRate']
depreciation_rate_ss*exp((EfficientCapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - EfficientDepreciationRate;

[name = 'dEfficientDepreciationRate']
depreciation_rate_ss*depreciation_curvature*exp((EfficientCapacityUtilizationFactor-capacity_utilization_factor_ss)*depreciation_curvature) - dEfficientDepreciationRate;

[name = 'EfficientCapitalReturnRate']
IncomeTax*EfficientCapitalReturnRate - EfficientTobinQ*dEfficientDepreciationRate;

[name = 'EfficientCapacityUtilizationFactor']
beta*EfficientHouseholdLagrangeMultiplier(1)/EfficientHouseholdLagrangeMultiplier*ProductionEfficiencyGrowth(1)^(-sigmac)*(EfficientTobinQ(1)*(1-EfficientDepreciationRate(1))+IncomeTax(1)*EfficientCapitalReturnRate(1)*EfficientCapacityUtilizationFactor(1)) - EfficientTobinQ;

[name = 'EfficientCapitalStock']
(1-EfficientDepreciationRate)*EfficientCapitalStock(-1)/ProductionEfficiencyGrowth+InvestmentEfficiencyShock*(1-EfficientInvestmentCost)*EfficientInvestment - EfficientCapitalStock;

[name = 'EfficientLabourDemand']
LabourTax*EfficientRealGrossWage*EfficientLabourDemand/(EfficientCapitalReturnRate*EfficientCapitalDemand) - (1-alpha)/alpha;

[name = 'EfficientRealGrossWage']
ProductionEfficiencyCycle^(alpha-1)*(EfficientCapitalReturnRate/alpha)^alpha*(LabourTax*EfficientRealGrossWage/(1-alpha))^(1-alpha) - EfficientRealMarginalCost;

[name = 'EfficientRealMarginalCost']
thetaf*(1+psif)/(thetaf*(1+psif)-1)*EfficientRealMarginalCost+psif/(thetaf*(1+psif)-1) - 1;

[name = 'EfficientHouseholdRealWage']
thetas*(1+psis)/(thetas*(1+psis)-1)*EfficientHouseholdRealWage/EfficientRealGrossWage+psis/(thetas*(1+psis)-1) - 1;

[name = 'EfficientHouseholdLabourSupply']
EfficientLabourDemand - EfficientHouseholdLabourSupply;

[name = 'EfficientCapitalDemand']
EfficientCapacityUtilizationFactor*EfficientCapitalStock(-1)/ProductionEfficiencyGrowth - EfficientCapitalDemand;

[name = 'EfficientInvestment']
EfficientConsumption + InvestmentRelativePrice*EfficientInvestment - (1-PublicSpendingShare)*EfficientGDP;

[name = 'EfficientGDP']
EfficientCapitalDemand^alpha*(ProductionEfficiencyCycle*EfficientLabourDemand)^(1-alpha) - EfficientGDP;

[name = 'EfficientInvestmentCost']
.5*investment_cost_size*production_efficiency_growth_ss*production_efficiency_growth_ss*(EfficientInvestment/EfficientInvestment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)^2 - EfficientInvestmentCost;

[name = 'dEfficientInvestmentCost']
(EfficientInvestment/EfficientInvestment(-1)*ProductionEfficiencyGrowth/production_efficiency_growth_ss-1)*production_efficiency_growth_ss*investment_cost_size - dEfficientInvestmentCost;

end;

steady_state_model;

	FinalGoodLagrangeMultiplier = 1;
	AveragedRelativePrices = 1;
	PriceDistorsion = 1;
	NablaPrice = 1;
	OptimalRelativePrice = 1;
	EmploymentAgencyLagrangeMultiplier = 1;
	RealWageGrowthFactor = 1;
	AveragedRelativeWages = 1;
	OptimalRelativeRealWage = 1;
	WageDistorsion = 1;
	NablaWage = 1;
	TobinQ = 1;
	OutputGap = 1;
	InvestmentCost = 0;
	dInvestmentCost = 0;
	ProductionEfficiencyCycle = 1;
	ConsumptionTax = 1;
	LabourIncomeTax = 1;
	IncomeTax = 1;
	RiskPremium = 1;
	InvestmentRelativePrice = 1;
	InvestmentEfficiencyShock = 1;
	LabourTax = 1;
	PriceCostPushShock = 1;
	WageCostPushShock = 1;
	TaylorShock = 1;
	HabitShock = 1;
	PreferenceShock = 1;
	InflationTarget = 1.005;
	PublicSpendingShare = 0.18;
	CapacityUtilizationFactor = capacity_utilization_factor_ss;
	DepreciationRate = depreciation_rate_ss;
	HouseholdLabourSupply = household_labour_supply_ss;
	NominalInterestFactor = steady_state_nominal_interest_factor;
	ProductionEfficiencyGrowth = (beta*RiskPremium*NominalInterestFactor/InflationTarget)^(1/sigmac);
	NonOptimizingFirmsPriceGrowth = InflationTarget;
	InflationFactor = InflationTarget;
	NonOptimizingUnionsWageGrowth = InflationTarget;
	RealMarginalCost = (thetaf-1)/thetaf;
	CapitalReturnRate = (ProductionEfficiencyGrowth^sigmac-beta*(1-DepreciationRate))/(beta*IncomeTax*CapacityUtilizationFactor);
	dDepreciationRate = CapitalReturnRate*IncomeTax;
	RealGrossWage = (RealMarginalCost*(alpha/CapitalReturnRate)^alpha)^(1/(1-alpha))*(1-alpha)/LabourTax*ProductionEfficiencyCycle;
	HouseholdRealWage = RealGrossWage*(thetas-1)/thetas;
	LabourDemand = HouseholdLabourSupply;
	EmploymentAgencyLabourSupply = HouseholdLabourSupply;
	CapitalDemand = LabourTax*RealGrossWage/CapitalReturnRate*alpha/(1-alpha)*HouseholdLabourSupply;
	GDP = CapitalDemand^alpha*(ProductionEfficiencyCycle*LabourDemand)^(1-alpha);
	CapitalStock = CapitalDemand*ProductionEfficiencyGrowth/CapacityUtilizationFactor;
	Investment = CapitalDemand*(ProductionEfficiencyGrowth-1+DepreciationRate)/CapacityUtilizationFactor;
	Consumption = (1-PublicSpendingShare)*GDP-Investment;
	PublicSpending = PublicSpendingShare*GDP;
	LabourSupplyShock = HouseholdLabourSupply*IncomeTax*LabourIncomeTax*HouseholdRealWage/(ConsumptionTax*Consumption*(1-eta/ProductionEfficiencyGrowth));
	HouseholdLagrangeMultiplier = (1/ConsumptionTax)*(Consumption*(1-eta/ProductionEfficiencyGrowth))^(-sigmac)*exp(LabourSupplyShock*(sigmac-1)/(1+sigmal));
	Z1 = RealMarginalCost*HouseholdLagrangeMultiplier*GDP/(1-beta*xip*ProductionEfficiencyGrowth^(1-sigmac));
	Z2 = Z1/RealMarginalCost;
	Z3 = Z2;
	H1 = HouseholdRealWage*HouseholdLagrangeMultiplier*EmploymentAgencyLabourSupply/(1-beta*xiw*ProductionEfficiencyGrowth^(1-sigmac));
	H2 = H1*thetas/(thetas-1);
	H3 = H2;
	EfficientConsumption = Consumption;
	EfficientHouseholdLabourSupply = HouseholdLabourSupply;
	EfficientHouseholdLagrangeMultiplier = HouseholdLagrangeMultiplier;
	EfficientInvestment = Investment;
	EfficientCapitalStock = CapitalStock;
	EfficientDepreciationRate = DepreciationRate;
	dEfficientDepreciationRate = dDepreciationRate;
	EfficientInvestmentCost = 0;
	dEfficientInvestmentCost = 0;
	EfficientCapacityUtilizationFactor = CapacityUtilizationFactor;
	EfficientCapitalReturnRate = CapitalReturnRate;
	EfficientHouseholdRealWage = HouseholdRealWage;
	EfficientTobinQ = 1;
	EfficientRealInterestFactor = NominalInterestFactor/InflationTarget;
	EfficientLabourDemand = LabourDemand;
	EfficientRealMarginalCost = RealMarginalCost;
	EfficientGDP = GDP;
	EfficientCapitalDemand = CapitalDemand;
	EfficientRealGrossWage = RealGrossWage;

end;

steady;

check;
