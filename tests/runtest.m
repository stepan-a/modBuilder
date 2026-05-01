function runtest(unittest)
    unittest = char(unittest);
    whereami = fileparts(mfilename('fullpath'));
    rootfold = whereami(1:end-5);
    addpath([rootfold 'src']);
    addpath([rootfold 'src/missing/stats']);
    % run('subdir/script.m') fails when 'script' clashes with a MATLAB class
    % folder name (e.g. the deprecated 'inline' class), even though the file
    % is on disk. cd into the script's directory first to bypass the lookup.
    [folder, name, ext] = fileparts(unittest);
    if isempty(ext), ext = '.m'; end
    if isempty(folder)
        run(unittest);
        return
    end
    oldcwd = pwd;
    c = onCleanup(@() cd(oldcwd));
    cd(fullfile(whereami, folder));
    % Indirect through a helper so that 'clear all' inside the script (which
    % run() forwards via evalin('caller', ...)) does not wipe oldcwd here.
    run_in_helper([name ext]);
end

function run_in_helper(scriptname)
    run(scriptname);
end
