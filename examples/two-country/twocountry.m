% twocountry.m — Two-country RBC model with perfect risk sharing, using modBuilder
%
% Demonstrates the CONDITIONAL analytical steady state: the technology processes
% close analytically (anchors), while the coupled world core — capital, hours,
% consumptions and outputs of both countries, linked by risk sharing and the world
% resource constraint — has no symbolic closed form. apply_steady_plan with
% GenerateHelpers=true hands that core to a generated MATLAB routine (damped Newton,
% analytic Jacobian inlined), and the exported steady_state_model block calls it at
% its topological position. Dynare then computes the exact steady state without a
% global numerical solve: analytic prologue, one small nonlinear system, analytic
% epilogue. Swap Solver='newton' for Solver='dynare' (SolveAlgo=0 for fsolve) to
% delegate the block solve to the solvers distributed with Dynare.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', '..', 'src'));   % modBuilder class

% =========================================================================
%  CALIBRATION
% =========================================================================

rho   = 0.90;    % persistence of the technology processes
alpha = 0.33;    % capital share
beta  = 0.99;    % discount factor
delta = 0.025;   % depreciation rate
sigma = 2.00;    % relative risk aversion
phi   = 1.50;    % inverse Frisch elasticity
chi   = 1.00;    % labour disutility scale
omega = 1.20;    % Pareto weight of country 2 in the risk-sharing condition

% =========================================================================
%  MODEL
% =========================================================================

m = modBuilder();

for country = {'1', '2'}
    s = country{1};
    % Technology (exogenous AR process, detected as an anchor by steady_plan)
    m.add(['A_' s], ['log(A_' s ') = rho*log(A_' s '(-1)) + e_' s]);
    % Production
    m.add(['y_' s], ['y_' s ' = A_' s '*k_' s '^alpha*h_' s '^(1-alpha)']);
    % Euler equation
    m.add(['k_' s], ['c_' s '^(-sigma) = beta*c_' s '(+1)^(-sigma)*(alpha*y_' s '(+1)/k_' s ' + 1 - delta)']);
    % Intratemporal labour supply
    m.add(['h_' s], ['chi*h_' s '^phi = (1-alpha)*(y_' s '/h_' s ')*c_' s '^(-sigma)']);
    % Capital accumulation
    m.add(['x_' s], ['k_' s ' = (1-delta)*k_' s '(-1) + x_' s]);
end
% Perfect risk sharing with Pareto weight omega, and the world resource constraint
m.add('c_1', 'c_1^(-sigma) = omega*c_2^(-sigma)');
m.add('c_2', 'y_1 + y_2 = c_1 + c_2 + x_1 + x_2');

m.parameter('rho', rho);
m.parameter('alpha', alpha);
m.parameter('beta', beta);
m.parameter('delta', delta);
m.parameter('sigma', sigma);
m.parameter('phi', phi);
m.parameter('chi', chi);
m.parameter('omega', omega);
m.exogenous('e_1', 0);
m.exogenous('e_2', 0);

% Calibrated values double as the initial guess of the generated routine.
for v = {'y_1', 'y_2', 'c_1', 'c_2', 'h_1', 'h_2', 'x_1', 'x_2'}
    m.endogenous(v{1}, 1);
end
m.endogenous('k_1', 10);
m.endogenous('k_2', 10);

% =========================================================================
%  STEADY-STATE PLAN AND EXPORT
% =========================================================================

pl = m.steady_plan(Match=true, MaxBlockSize=10);
m.print_steady_plan(pl);
% -> A_1 and A_2 close analytically (anchor blocks). Elimination shrinks the
%    10-variable world core to a REDUCED 3-unknown system {k_2, h_2, c_1};
%    the other seven variables get closed forms conditional on those three.

cd(here);
m.apply_steady_plan(pl, GenerateHelpers=true, Basename='twocountry');
m.write('twocountry', steady_state_model=true, steady=true);
% -> twocountry.mod whose steady_state_model block reads: the two analytic
%    anchors, then
%      [k_2, h_2, c_1] = twocountry_ssblock_3(...);
%    (the generated Newton routine solves only the reduced 3x3 system), then
%    the seven conditional closed forms as the analytic epilogue.

% =========================================================================
%  VERIFICATION: execute the emitted cascade and check every equation
% =========================================================================

e_1 = 0; e_2 = 0;
rehash;
[~, rows] = m.checksteady();
for i = 1:numel(rows)
    nm = m.steady_state{rows(i), 1};
    expr = m.steady_state{rows(i), 2};
    if ischar(nm)
        eval([nm ' = ' expr ';']);
    else
        eval(['[' strjoin(nm, ', ') '] = ' expr ';']);
    end
end

r = zeros(12, 1);
r(1)  = log(A_1) - rho*log(A_1) - e_1;
r(2)  = y_1 - A_1*k_1^alpha*h_1^(1-alpha);
r(3)  = c_1^(-sigma) - beta*c_1^(-sigma)*(alpha*y_1/k_1 + 1 - delta);
r(4)  = chi*h_1^phi - (1-alpha)*(y_1/h_1)*c_1^(-sigma);
r(5)  = k_1 - (1-delta)*k_1 - x_1;
r(6)  = log(A_2) - rho*log(A_2) - e_2;
r(7)  = y_2 - A_2*k_2^alpha*h_2^(1-alpha);
r(8)  = c_2^(-sigma) - beta*c_2^(-sigma)*(alpha*y_2/k_2 + 1 - delta);
r(9)  = chi*h_2^phi - (1-alpha)*(y_2/h_2)*c_2^(-sigma);
r(10) = k_2 - (1-delta)*k_2 - x_2;
r(11) = c_1^(-sigma) - omega*c_2^(-sigma);
r(12) = y_1 + y_2 - c_1 - c_2 - x_1 - x_2;

assert(max(abs(r)) < 1e-9, 'the steady state recovered from the emitted cascade must solve the model');
fprintf('\nSteady state (max residual %.2e):\n', max(abs(r)));
fprintf('  country 1: y=%.4f c=%.4f h=%.4f k=%.4f x=%.4f\n', y_1, c_1, h_1, k_1, x_1);
fprintf('  country 2: y=%.4f c=%.4f h=%.4f k=%.4f x=%.4f\n', y_2, c_2, h_2, k_2, x_2);
fprintf('  risk sharing with omega = %.2f: c_1/c_2 = %.4f = omega^(-1/sigma) = %.4f\n', omega, c_1/c_2, omega^(-1/sigma));
