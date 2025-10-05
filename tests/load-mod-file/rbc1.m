addpath ../utils

preprocessedModel = load('rbc1.mat');

M_ = preprocessedModel.M_;
oo_ = preprocessedModel.oo_;

clear('preprocessedModel')

model = modBuilder(M_, oo_, 'rbc1-modfile-original.json');

model.write('rbc1');

[b, diff] = modiff('rbc1.mod', 'rbc1.true.mod');

if not(b)
    error('Generated mod file might be wrong.')
else
    delete rbc1.mod
end
