function declare_arma_shock(m, shockvar, paramprefix, phi, theta, i_std, innov, options)
% Declare (or convert) an endogenous shock process as an ARMA(p,q) in a
% modBuilder model.
%
% The process is written as a multiplicative log form whose long-run level is an
% explicit parameter Xbar = <prefix>_ss (not STEADY_STATE(x)):
%
%   x_t / Xbar = prod_{i=1..p} (x_{t-i}/Xbar)^phi_i
%                * exp( sigma_eps * ( e_t + sum_{j=1..q} theta_j e_{t-j} ) ),
%
% added to the model as the zero residual
%   exp(...) * prod_i (...)^phi_i - x/Xbar = 0.
%
% Since the process is homogeneous in Xbar, that parameter is a pure level knob,
% decoupled from persistence and variance: at the steady state x = Xbar, and Xbar
% can be freed to hit a normalisation target without touching the dynamics.
%
% Lagged innovations e(-j) are written directly: Dynare's preprocessor creates
% the AUX_EXO_LAG auxiliary variables, so modBuilder need not declare them.
%
% INPUTS:
% - m            [modBuilder]
% - shockvar     [char]   endogenous shock variable (e.g. 'ProductionEfficiencyCycle')
% - paramprefix  [char]   base for parameter names (e.g. 'production_efficiency'),
%                         giving <prefix>_phi<i>, <prefix>_theta<j>, <prefix>_i_std,
%                         <prefix>_ss
% - phi          [double] 1×p AR coefficients ([] for a pure MA process)
% - theta        [double] 1×q MA coefficients ([] for a pure AR process)
% - i_std        [double] innovation std sigma_eps (0 leaves the shock inert)
% - innov        [char]   exogenous innovation name (e.g. 'EfficiencyCycleInnovation')
% - options.tag      [char] TeX subscript tag for the parameters (e.g. 'A_C'); when
%                           empty, no TeX names are attached
% - options.innovtex [char] TeX name for the innovation (e.g. '\epsilon_A')
% - options.level    [double] long-run level Xbar = <prefix>_ss (default 1)
%
% REMARKS:
% - If shockvar already has an equation it is replaced (change), otherwise it is
%   added; the shock variable is therefore endogenous.
% - i_std = 0 disables the shock (the exp factor collapses to 1) while keeping the
%   variable, its innovation and its parameters in the model.
    arguments
        m            (1,1) modBuilder
        shockvar     (1,:) char {mustBeNonempty}
        paramprefix  (1,:) char {mustBeNonempty}
        phi          (1,:) double
        theta        (1,:) double
        i_std        (1,1) double {mustBeNonnegative}
        innov        (1,:) char {mustBeNonempty}
        options.tag      (1,:) char = ''
        options.innovtex (1,:) char = ''
        options.level    (1,1) double = 1
    end

    p = numel(phi);
    q = numel(theta);
    ss = sprintf('%s_ss', paramprefix);   % long-run level parameter (replaces STEADY_STATE(x))

    % MA exponent: e_t + theta_1 e(-1) + ... + theta_q e(-q).
    ma = innov;
    for j = 1:q
        ma = sprintf('%s + %s_theta%d*%s(-%d)', ma, paramprefix, j, innov, j);
    end
    expterm = sprintf('exp(%s_i_std*(%s))', paramprefix, ma);

    % AR product: prod_i (x(-i)/Xbar)^phi_i.
    arfac = cell(1, p);
    for i = 1:p
        arfac{i} = sprintf('(%s(-%d)/%s)^%s_phi%d', shockvar, i, ss, paramprefix, i);
    end
    if p >= 1
        eq = sprintf('%s*%s - %s/%s', expterm, strjoin(arfac, '*'), shockvar, ss);
    else
        eq = sprintf('%s - %s/%s', expterm, shockvar, ss);
    end

    % Add or replace the shock equation (keyed to the shock variable).
    if ~isempty(m.equations) && any(strcmp(shockvar, m.equations(:, 1)))
        m.change(shockvar, eq);
    else
        m.add(shockvar, eq);
    end

    % Declare the ARMA parameters with values and TeX names.
    for i = 1:p
        declare_param(m, sprintf('%s_phi%d', paramprefix, i), phi(i), options.tag, sprintf('\\phi_{%s,%d}', options.tag, i));
    end
    for j = 1:q
        declare_param(m, sprintf('%s_theta%d', paramprefix, j), theta(j), options.tag, sprintf('\\theta_{%s,%d}', options.tag, j));
    end
    declare_param(m, sprintf('%s_i_std', paramprefix), i_std, options.tag, sprintf('\\sigma_{%s}', options.tag));
    declare_param(m, sprintf('%s_ss', paramprefix), options.level, options.tag, sprintf('{%s}^{\\star}', options.tag));

    % Declare the innovation as exogenous.
    if isempty(options.innovtex)
        m.exogenous(innov, 0);
    else
        m.exogenous(innov, 0, 'texname', options.innovtex);
    end
end

function declare_param(m, name, value, tag, tex)
    if isempty(tag)
        m.parameter(name, value);
    else
        m.parameter(name, value, 'texname', tex);
    end
end
