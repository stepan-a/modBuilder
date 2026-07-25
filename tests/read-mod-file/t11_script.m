% The generated MATLAB script is the artifact: it must be readable, valid and re-runnable.

addpath ../utils

source = '../../examples/two-country/twocountry.mod';

% Keeping the script is what Script= is for.
[m, scriptpath] = modfile.load(source, Script='t11_generated.m');
assert(strcmp(scriptpath, 't11_generated.m'), 'The script path should be reported back.');
assert(isfile(scriptpath), 'The script should have been written.');

% Running it again, from the file alone, must rebuild the very same model.
again = modfile.build(scriptpath);
assert(m == again, 'Re-running the generated script does not rebuild the same model.');

% It must go through the public API rather than poking at the tables, so that a user can
% carry on from it by hand.
text = fileread(scriptpath);
assert(contains(text, 'm = modBuilder();'), 'The script should create the object.');
assert(contains(text, 'm.add('), 'The script should add equations.');
assert(contains(text, 'm.parameter('), 'The script should declare parameters.');
assert(contains(text, 'm.steady('), 'The script should carry the steady-state expressions.');
assert(~contains(text, '.params ='), 'The script should not assign the tables directly.');

% The calibration is emitted as locals holding the source expressions, so a chain stays
% readable and re-tunable.
assert(~isempty(regexp(text, '^rho = 0\.900000;$', 'once', 'lineanchors')), 'Calibration should appear as a MATLAB local.');
assert(contains(text, 'm.parameter(''rho'', rho'), 'The parameter should take its value from the local.');

delete(scriptpath)

% Without Script=, the script is temporary and no path is reported.
[m2, nopath] = modfile.load(source);
assert(isempty(nopath), 'No script path should be reported for a temporary script.');
assert(m2 == m, 'The temporary-script route should build the same model.');

% The constructor overload is the documented public face.
m3 = modBuilder(source);
assert(m3 == m, 'modBuilder(filename) should build the same model.');
assert(~isempty(m3.date), 'The constructor must set the creation date.');

fprintf('t11_script.m: All tests passed\n');
