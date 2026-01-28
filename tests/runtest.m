function runtest(unittest)
    whereami = fileparts(mfilename('fullpath'));
    rootfold = whereami(1:end-5);
    addpath([rootfold 'src']);
    addpath([rootfold 'src/missing/stats']);
    run(unittest)
end
