addpath ../utils

preprocessedModel = load('rbc1.mat');

M_ = preprocessedModel.M_;
oo_ = preprocessedModel.oo_;

clear('preprocessedModel')

% Strip every tag, then rewrite a few LHS into nonlinear forms that mix the
% lone endogenous variable with parameters. The bipartite matcher should still
% pick the correct endogenous from each LHS via the LHS-bonus tiebreaker.
text = fileread('rbc1-modfile-original.json');
JSON = jsondecode(text);
for i = 1:numel(JSON.model)
    JSON.model(i).tags = struct();
end
JSON.model(1).lhs = 'log(a)';
JSON.model(1).rhs = 'log(rho*a(-1)+tau*b(-1)+e)';
JSON.model(2).lhs = 'b^(1+psi)';
JSON.model(3).lhs = 'theta*log(y)';
JSON.model(3).rhs = 'theta*(a + alpha*log(k(-1)) + (1-alpha)*log(h))';

tmpjson = 'rbc1autononlinear-tmp.json';
fid = fopen(tmpjson, 'w');
fprintf(fid, '%s', jsonencode(JSON, 'PrettyPrint', true));
fclose(fid);

ws = warning('off', 'modBuilder:autoMatch');
cleanupw = onCleanup(@() warning(ws));

m = modBuilder(M_, oo_, tmpjson);

mapping = containers.Map();
for i = 1:size(m.equations, 1)
    mapping(m.equations{i, 2}) = m.equations{i, 1};
end

assert(strcmp(mapping('log(a) = log(rho*a(-1)+tau*b(-1)+e)'), 'a'));
assert(strcmp(mapping('b^(1+psi) = tau*a(-1)+rho*b(-1)+u'), 'b'));
assert(strcmp(mapping('theta*log(y) = theta*(a + alpha*log(k(-1)) + (1-alpha)*log(h))'), 'y'));

assert(m.size('endogenous') == 6);
assert(numel(unique(m.equations(:, 1))) == 6);

delete(tmpjson);

fprintf('rbc1autononlinear.m: All tests passed\n');
