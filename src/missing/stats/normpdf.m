function y = normpdf(x, mu, sigma)
    if nargin < 2, mu = 0; end
    if nargin < 3, sigma = 1; end
    coef = 1 ./ (sqrt(2*pi) * sigma);
    arg = -0.5 * ((x - mu) ./ sigma).^2;
    y = coef .* exp(arg);
end
