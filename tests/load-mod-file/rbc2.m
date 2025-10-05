addpath ../utils

preprocessedModel = load('rbc2.mat');

M_ = preprocessedModel.M_;
oo_ = preprocessedModel.oo_;

clear('preprocessedModel')

model = modBuilder(M_, oo_, 'rbc2-modfile-original.json', 'endogenous');

model.write('rbc2');

[b, diff] = modiff('rbc2.mod', 'rbc2.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc2.mod
end
