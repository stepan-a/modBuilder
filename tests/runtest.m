function runtest(unittest)
    whereami = fileparts(mfilename('fullpath'));
    rootfold = whereami(1:end-5);
    addpath([rootfold 'src']);
    run(unittest)
end
