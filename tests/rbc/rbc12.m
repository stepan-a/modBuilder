addpath ../utils

preprocessedModel = load('rbc12.mat');

M_ = preprocessedModel.M_;
oo_ = preprocessedModel.oo_;

clear('preprocessedModel')

model = modBuilder(M_, oo_, 'rbc12-modfile-original.json');

model.write('rbc12');

[b, diff] = modiff('rbc12.mod', 'rbc12.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc12.mod
end
