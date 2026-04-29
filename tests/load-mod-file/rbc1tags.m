addpath ../utils

preprocessedModel = load('rbc1.mat');

M_ = preprocessedModel.M_;
oo_ = preprocessedModel.oo_;

clear('preprocessedModel')

% Inject a custom equation tag (mcp) on the equation associated with c.
% The constructor must import non-'name' tags from the JSON; before the
% fix, the loop building o.tags only ever copied the 'name' field.
text = fileread('rbc1-modfile-original.json');
JSON = jsondecode(text);
% Locate the equation tagged with name='c' and add an mcp tag to it.
k = 0;
for i = 1:numel(JSON.model)
    if isfield(JSON.model(i).tags, 'name') && strcmp(JSON.model(i).tags.name, 'c')
        k = i;
        break
    end
end
assert(k > 0);
JSON.model(k).tags.mcp = 'c > 0';

tmpjson = 'rbc1tags-tmp.json';
fid = fopen(tmpjson, 'w');
fprintf(fid, '%s', jsonencode(JSON, 'PrettyPrint', true));
fclose(fid);

m = modBuilder(M_, oo_, tmpjson);

assert(isfield(m.tags, 'c'));
assert(isfield(m.tags.c, 'mcp'));
assert(strcmp(m.tags.c.mcp, 'c > 0'));
assert(strcmp(m.tags.c.name, 'c'));

delete(tmpjson);

fprintf('rbc1tags.m: All tests passed\n');
