function p = normcdf(x, mu, sigma)
    if nargin < 2, mu = 0; end
    if nargin < 3, sigma = 1; end
    z = (x - mu) ./ sigma;
    p = 0.5 * erfc(-z / sqrt(2));
end
