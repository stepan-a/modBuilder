% steady_plan: equations beyond the recogniser allowlist must remain open.
% h*log(h) = c has h both inside log and outside, so the invertible-call recogniser
% cannot unwrap it (the call wrapper requires x to appear ONLY inside the call). The
% linear and monomial recognisers cannot fire either (log(h) is opaque to them).

addpath ../utils

m = modBuilder();
m.add('h', 'h*log(h) = c');
m.exogenous('c', 1);

plan = m.steady_plan();

if numel(plan) ~= 1, error('Expected 1 block.'), end
if ~isempty(plan(1).closed_form)
    error('steady_plan should NOT close h*log(h)=c; got closed form %s.', plan(1).closed_form.expr)
end

fprintf('t10.m: equation beyond recogniser reach correctly left unclosed OK\n');
