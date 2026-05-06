% suggest_calibrations: rbc3 with no swap declared. The residual {h} should
% admit at least the (h, theta) full-closure swap. The framework also discovers
% (h, psi) as algebraically valid even though theta is the economically natural
% choice — surfacing both is fine; the user reads the menu critically.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
m.add('b', 'b = tau*a(-1) + rho*b(-1) + u');
m.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
m.add('c', 'k = exp(b)*(y-c) + (1-deltak)*k(-1)');
m.add('h', 'c*theta*h^(1+psi) = (1-alpha)*y');
m.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k + (1-deltak))');
m.parameter('alpha', 0.36);
m.parameter('rho', 0.95);
m.parameter('tau', 0.025);
m.parameter('beta', 0.99);
m.parameter('deltak', 0.025);
m.parameter('psi', 0);
m.parameter('theta', 2.95);
m.exogenous('e', 0);
m.exogenous('u', 0);

s = m.suggest_calibrations();

if isempty(s), error('Expected at least one suggestion for rbc3 residual {h}.'), end

% At least one full-closure (residual=0) candidate must pin h with theta.
found_theta = false;
for i = 1:numel(s)
    if strcmp(s(i).endo, 'h') && strcmp(s(i).param, 'theta') && s(i).residual == 0
        found_theta = true;
        break
    end
end
if ~found_theta
    error('Expected (h, theta) as a full-closure candidate; not found in %d suggestions.', numel(s))
end

% Suggestions are sorted by ascending residual (full closures first).
for i = 2:numel(s)
    if s(i).residual < s(i-1).residual
        error('Suggestions not sorted by ascending residual.')
    end
end

fprintf('t21.m: suggest_calibrations finds (h, theta) on rbc3 OK\n');
