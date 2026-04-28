addpath ../utils

preprocessedModel = load('rbc1.mat');

M_ = preprocessedModel.M_;
oo_ = preprocessedModel.oo_;

clear('preprocessedModel')

% Strip the tag of the first equation only. The bipartite matcher must
% pick the only endogenous still available (a) for that equation, while
% the remaining equations keep their explicit tags.
text = fileread('rbc1-modfile-original.json');
text = regexprep(text, '"tags":\s*\{\s*"name":\s*"a"\s*\}', '"tags": {}', 'once');
tmpjson = 'rbc1autopartial-tmp.json';
fid = fopen(tmpjson, 'w');
fprintf(fid, '%s', text);
fclose(fid);

ws = warning('off', 'modBuilder:autoMatch');
cleanupw = onCleanup(@() warning(ws));

model = modBuilder(M_, oo_, tmpjson);

model.write('rbc1autopartial');

[b, diff] = modiff('rbc1autopartial.mod', 'rbc1.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc1autopartial.mod
    delete(tmpjson)
end
