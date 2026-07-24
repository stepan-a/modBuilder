function g = arma_autocov(phi, theta, sigma2, K)
% Autocovariances gamma(0..K) of a stationary, invertible ARMA(p,q).
%
% Model:
%   x_t = phi(1) x_{t-1} + ... + phi(p) x_{t-p}
%         + e_t + theta(1) e_{t-1} + ... + theta(q) e_{t-q},   e_t ~ WN(0, sigma2).
%
% INPUTS:
% - phi     [double]   1×p AR coefficients (phi(i) multiplies x_{t-i}); [] when p=0
% - theta   [double]   1×q MA coefficients (theta(j) multiplies e_{t-j}); [] when q=0
% - sigma2  [double]   scalar, innovation variance (default 1)
% - K       [integer]  highest lag required (default 1)
%
% OUTPUTS:
% - g       [double]   1×(K+1) row, g(k+1) = gamma(k) for k = 0..K
%
% METHOD:
% Via the MA(infinity) representation x_t = sum_{j>=0} psi_j e_{t-j}, with
%   psi_0 = 1,   psi_j = theta_j + sum_{i=1..p} phi_i psi_{j-i}   (theta_j=0 for j>q),
% the autocovariances are gamma(k) = sigma2 * sum_{j>=0} psi_j psi_{j+k}. The
% psi-weights decay geometrically at the rate of the dominant AR characteristic
% root, so the sum is truncated once that tail is negligible. rho(1)=g(2)/g(1)
% is independent of sigma2 (the variance is a pure scale), which the calibration
% routines exploit.
    arguments
        phi    (1,:) double = []
        theta  (1,:) double = []
        sigma2 (1,1) double {mustBePositive} = 1
        K      (1,1) double {mustBeNonnegative, mustBeInteger} = 1
    end

    p = numel(phi);
    q = numel(theta);

    % Truncation length: resolve the slowest-decaying AR characteristic root.
    if p > 0
        rmax = max(abs(roots([1, -phi])));   % moduli of the companion eigenvalues
    else
        rmax = 0;
    end
    rmax = min(max(rmax, 0.10), 1 - 1e-9);
    J = max(K + q + 1, ceil(log(1e-13) / log(rmax)) + K + 2);
    J = min(J, 500000);

    % psi-weights (psi(j+1) holds psi_j).
    psi = zeros(1, J + 1);
    psi(1) = 1;
    for j = 1:J
        s = 0;
        if j <= q
            s = theta(j);
        end
        for i = 1:min(p, j)
            s = s + phi(i) * psi(j - i + 1);
        end
        psi(j + 1) = s;
    end

    % Autocovariances gamma(k) = sigma2 * sum_j psi_j psi_{j+k}.
    g = zeros(1, K + 1);
    for k = 0:K
        g(k + 1) = sigma2 * sum(psi(1:J + 1 - k) .* psi(1 + k:J + 1));
    end
end
