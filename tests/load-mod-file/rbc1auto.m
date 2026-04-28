addpath ../utils

preprocessedModel = load('rbc1.mat');

M_ = preprocessedModel.M_;
oo_ = preprocessedModel.oo_;

clear('preprocessedModel')

% Strip every equation tag from the JSON to force the constructor to
% bipartite-match equations against endogenous variables.
text = fileread('rbc1-modfile-original.json');
text = regexprep(text, '"tags":\s*\{\s*"name":\s*"\w+"\s*\}', '"tags": {}');
tmpjson = 'rbc1auto-tmp.json';
fid = fopen(tmpjson, 'w');
fprintf(fid, '%s', text);
fclose(fid);

ws = warning('off', 'modBuilder:autoMatch');
cleanupw = onCleanup(@() warning(ws));

model = modBuilder(M_, oo_, tmpjson);

model.write('rbc1auto');

[b, diff] = modiff('rbc1auto.mod', 'rbc1auto.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc1auto.mod
    delete(tmpjson)
end
