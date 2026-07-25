% A macro-driven multi-country .mod file, read into a model without Dynare.

addpath ../utils

source = 't08_macro.mod';
fid = fopen(source, 'w');
fprintf(fid, '@#define Countries = ["US", "EA"]\n');
% Guarding the default with @#ifndef is the usual idiom for a setting meant to be
% overridable from outside, since a plain @#define would overwrite the seeded value.
fprintf(fid, '@#ifndef OpenEconomy\n');
fprintf(fid, '@#define OpenEconomy = true\n');
fprintf(fid, '@#endif\n');
fprintf(fid, '\n');
fprintf(fid, 'var\n');
fprintf(fid, '@#for c in Countries\n');
fprintf(fid, '  y_@{c} k_@{c}\n');
fprintf(fid, '@#endfor\n');
fprintf(fid, '@#if OpenEconomy\n');
fprintf(fid, '  nx\n');
fprintf(fid, '@#endif\n');
fprintf(fid, ';\n\n');
fprintf(fid, 'varexo\n');
fprintf(fid, '@#for c in Countries\n');
fprintf(fid, '  e_@{c}\n');
fprintf(fid, '@#endfor\n');
fprintf(fid, ';\n\n');
fprintf(fid, 'parameters alpha delta;\n');
fprintf(fid, 'alpha = 0.33;\n');
fprintf(fid, 'delta = 0.025;\n\n');
fprintf(fid, 'model;\n');
fprintf(fid, '@#for c in Countries\n');
fprintf(fid, '[name = ''y_@{c}'']\n');
fprintf(fid, 'y_@{c} = k_@{c}^alpha + e_@{c};\n');
fprintf(fid, '[name = ''k_@{c}'']\n');
fprintf(fid, 'k_@{c} = (1-delta)*k_@{c}(-1) + y_@{c};\n');
fprintf(fid, '@#endfor\n');
fprintf(fid, '@#if OpenEconomy\n');
fprintf(fid, '[name = ''nx'']\n');
fprintf(fid, 'nx = y_US - y_EA;\n');
fprintf(fid, '@#endif\n');
fprintf(fid, 'end;\n');
fclose(fid);
cleanup = onCleanup(@() delete(source));

[m, scriptpath] = modfile.load(source, Script='t08_generated.m');
cleanup2 = onCleanup(@() delete(scriptpath));

% The loop and the conditional produced the expected symbols.
assert(isequal(m.var(:,1)', {'y_US', 'k_US', 'y_EA', 'k_EA', 'nx'}), sprintf('Unexpected endogenous variables: %s', strjoin(m.var(:,1)', ' ')));
assert(isequal(m.varexo(:,1)', {'e_US', 'e_EA'}), 'Unexpected exogenous variables.');
assert(m.size('equations') == 5, 'Expected five equations.');
assert(strcmp(m.equations{1,2}, 'y_US = k_US^alpha + e_US'), sprintf('Unexpected first equation: %s', m.equations{1,2}));

% The @#define variables are kept as MATLAB locals, so the settings the file was written
% with remain visible in the script rather than vanishing into the expansion.
text = fileread(scriptpath);
assert(contains(text, 'Countries = macroarray(''US'', ''EA'');'), 'The macro array should appear as a MATLAB local, carrying its kind.');
assert(contains(text, 'OpenEconomy = true;'), 'The macro flag should appear as a MATLAB local.');

% Turning the conditional off changes the model, and Defines is the way to do it without
% editing the file, as Dynare's -D switch does.
m2 = modfile.load(source, Defines=struct('OpenEconomy', false));
assert(~ismember('nx', m2.var(:,1)), 'Defines should override the value set in the file.');
assert(m2.size('equations') == 4, 'The closed-economy model should have four equations.');

% Macro=false refuses a file that needs the macro pass rather than mis-parsing it.
thrown = false;
try
    modfile.read(source, Macro=false);
catch ME
    thrown = strcmp(ME.identifier, 'modfile:read:macroDisabled');
end
assert(thrown, 'Expected read:macroDisabled.');

% The model writes out and reads back to the same thing.
m.write('t08_written');
cleanup3 = onCleanup(@() delete('t08_written.mod'));
again = modBuilder('t08_written.mod');
assert(again == m, 'The expanded model should survive a write/read round trip.');

fprintf('t08_end_to_end.m: All tests passed\n');
