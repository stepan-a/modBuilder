function [phi, theta, sigma2, info] = arma_random(p, q, rho1, var_target, modint, options)
% Random stationary/invertible ARMA(p,q) matching a target lag-1
% autocorrelation and unconditional variance (Smets-Wouters style).
%
% INPUTS:
% - p           [integer]  AR order
% - q           [integer]  MA order
% - rho1        [double]   target lag-1 autocorrelation rho(1) (= SW persistence)
% - var_target  [double]   target unconditional variance gamma(0) (= SW shock variance)
% - modint      [double]   1×2, [a b] with 0<a<=b<1: allowed range for the MODULI of the
%                          characteristic (companion) roots of the AR and MA polynomials.
%                          a..b near 0 = transient, near 1 = persistent. Stationarity and
%                          invertibility hold by construction (moduli < 1).
% - options.seed     [double]  RNG seed for reproducibility (default: RNG left untouched)
% - options.tol      [double]  bisection tolerance on rho(1) (default 1e-10)
% - options.maxtries [integer] max redraws before declaring infeasibility (default 500)
%
% OUTPUTS:
% - phi     [double]  1×p AR coefficients (phi(i) multiplies x_{t-i}); [] when p=0
% - theta   [double]  1×q MA coefficients (theta(j) multiplies e_{t-j}); [] when q=0
% - sigma2  [double]  innovation variance hitting var_target exactly
% - info    [struct]  realised diagnostics: rho1, variance, ar_root_moduli,
%                     ma_root_moduli, tries
%
% STRATEGY (approach B):
% rho(1) is scale-free, so the variance never constrains the coefficients: we
% draw the shape, then set sigma2 = var_target / gamma0(sigma2=1) exactly. The
% only binding constraint is rho(1) = rho1. We therefore draw p+q-1 characteristic
% roots with moduli in modint and leave ONE real root free, solved (1-D bisection)
% so that rho(1) hits its target. If no admissible solution exists for a given
% draw, the free draw is repeated. The free root is an MA root when q>=1, else an
% AR root.
%
% Special cases: AR(1) -> phi = rho1 (modint irrelevant); white noise (p=q=0)
% requires rho1 = 0.
    arguments
        p          (1,1) double {mustBeNonnegative, mustBeInteger}
        q          (1,1) double {mustBeNonnegative, mustBeInteger}
        rho1       (1,1) double
        var_target (1,1) double {mustBePositive}
        modint     (1,2) double {mustBeNonnegative} = [0.2 0.9]
        options.seed     (1,1) double {mustBeInteger}
        options.tol      (1,1) double {mustBePositive} = 1e-10
        options.maxtries (1,1) double {mustBePositive, mustBeInteger} = 500
    end

    a = modint(1); b = modint(2);
    if ~(a <= b && b < 1)
        error('arma_random:modint', 'modint must satisfy 0 <= a <= b < 1.');
    end
    if isfield(options, 'seed')
        rng(options.seed);
    end

    % White noise: nothing to draw.
    if p == 0 && q == 0
        if abs(rho1) > options.tol
            error('arma_random:infeasible', 'White noise (p=q=0) forces rho(1)=0, but %.4g was requested.', rho1);
        end
        phi = []; theta = []; sigma2 = var_target;
        info = struct('rho1', 0, 'variance', var_target, 'ar_root_moduli', [], 'ma_root_moduli', [], 'tries', 0);
        return
    end

    free_is_ma = (q >= 1);   % free root taken from the MA polynomial when it exists

    for tries = 1:options.maxtries
        % Draw the fixed (conjugate-closed) root sets; one real root is left free.
        if free_is_ma
            ar_roots    = draw_roots(p,     a, b);   % AR fully drawn
            ma_fixed    = draw_roots(q - 1, a, b);   % MA minus the free real root
            phi_fixed   = ar_from_roots(ar_roots);
            objective   = @(x) rho1_of(phi_fixed, ma_from_roots([ma_fixed, x])) - rho1;
        else
            ar_fixed    = draw_roots(p - 1, a, b);   % AR minus the free real root
            objective   = @(x) rho1_of(ar_from_roots([ar_fixed, x]), []) - rho1;
        end

        % Solve the free real root over the stationary/invertible interior (-1,1).
        x = solve_free_root(objective, options.tol);
        if isnan(x)
            continue   % no admissible sign change for this draw; redraw
        end

        if free_is_ma
            phi   = phi_fixed;
            theta = ma_from_roots([ma_fixed, x]);
        else
            phi   = ar_from_roots([ar_fixed, x]);
            theta = [];
        end

        % Admissibility: every characteristic root strictly inside the unit circle.
        arm = root_moduli([1, -phi]);
        mam = root_moduli([1,  theta]);   % MA char. poly z^q + theta_1 z^{q-1} + ...
        if (~isempty(arm) && max(arm) >= 1) || (~isempty(mam) && max(mam) >= 1)
            continue
        end

        % Variance is a pure scale: set sigma2 to hit var_target exactly.
        g0_unit = arma_autocov(phi, theta, 1, 0);
        sigma2  = var_target / g0_unit;

        g = arma_autocov(phi, theta, sigma2, 1);
        info = struct('rho1', g(2)/g(1), 'variance', g(1), ...
                      'ar_root_moduli', arm(:)', 'ma_root_moduli', mam(:)', 'tries', tries);
        return
    end

    error('arma_random:infeasible', ...
          'Could not match rho(1)=%.4g for ARMA(%d,%d) with root moduli in [%.3g, %.3g] after %d tries.', ...
          rho1, p, q, a, b, options.maxtries);
end

% ---------------------------------------------------------------------------

function r = draw_roots(k, a, b)
% Draw k characteristic roots (moduli ~ U[a,b]) forming a conjugate-closed set,
% so the resulting polynomial has real coefficients.
    r = [];
    rem = k;
    while rem > 0
        m = a + (b - a) * rand;
        if rem == 1 || rand < 0.5
            r(end+1) = (2*(rand < 0.5) - 1) * m;          %#ok<AGROW> real root +-m
            rem = rem - 1;
        else
            ph = pi * rand;
            r(end+1) = m * exp(1i*ph);                    %#ok<AGROW>
            r(end+1) = m * exp(-1i*ph);                   %#ok<AGROW>
            rem = rem - 2;
        end
    end
end

function phi = ar_from_roots(lambda)
% AR coefficients from characteristic roots: z^p - phi_1 z^{p-1} - ... - phi_p.
    if isempty(lambda), phi = []; return; end
    c = real(poly(lambda));      % [1, -sum lambda, ...]
    phi = -c(2:end);
end

function theta = ma_from_roots(mu)
% MA coefficients from characteristic roots: z^q + theta_1 z^{q-1} + ... + theta_q.
    if isempty(mu), theta = []; return; end
    c = real(poly(mu));          % [1, theta_1, ...]
    theta = c(2:end);
end

function r1 = rho1_of(phi, theta)
    g = arma_autocov(phi, theta, 1, 1);
    r1 = g(2) / g(1);
end

function m = root_moduli(coefs)
    if numel(coefs) <= 1, m = []; else, m = abs(roots(coefs)); end
end

function x = solve_free_root(objective, tol)
% Find a real root x in (-1,1) of a smooth scalar objective by scanning for a
% sign change then bisecting. Returns NaN if no sign change is found.
    grid = linspace(-0.999, 0.999, 81);
    vals = arrayfun(objective, grid);
    x = NaN;
    for i = 1:numel(grid)-1
        if isfinite(vals(i)) && isfinite(vals(i+1)) && vals(i)*vals(i+1) <= 0
            lo = grid(i); hi = grid(i+1); flo = vals(i);
            for it = 1:200
                mid = 0.5*(lo+hi); fmid = objective(mid);
                if abs(fmid) < tol || (hi-lo) < tol
                    x = mid; return
                end
                if flo*fmid <= 0, hi = mid; else, lo = mid; flo = fmid; end
            end
            x = 0.5*(lo+hi); return
        end
    end
end
