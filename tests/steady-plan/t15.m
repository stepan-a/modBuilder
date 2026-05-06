% steady_plan: a simultaneous SCC that is NOT jointly linear remains open.
% The two-equation block has a bilinear term a*b, so ast.linearise_system rejects.

addpath ../utils

m = modBuilder();
m.add('a', 'a = rho*a(-1) + b*c');     % a*b structure: bilinear in (a,b) ; b appears linearly here
m.add('b', 'b = a*b(-1) + u');         % a*b in this equation: bilinear in {a, b}
m.parameter('rho', 0.5);
m.exogenous('c', 1);
m.exogenous('u', 1);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 SCC.'), end
if ~strcmp(plan(1).kind, 'simultaneous'), error('Expected simultaneous block.'), end
if ~isempty(plan(1).closed_form)
    error('Bilinear simultaneous block should NOT be closed; got %d closed forms.', numel(plan(1).closed_form))
end

fprintf('t15.m: bilinear simultaneous block correctly left unclosed OK\n');
