% The .mod reader must be a drop-in replacement for the Dynare-based constructor.
%
% Build the same model twice, once from the preprocessor's M_/oo_/JSON and once from the
% .mod file alone, then compare the internals. This is what "removing the dependence on
% Dynare" has to mean in practice.

addpath ../utils

preprocessed = load('../load-mod-file/rbc1.mat');
viaDynare = modBuilder(preprocessed.M_, preprocessed.oo_, '../load-mod-file/rbc1-modfile-original.json');

viaModFile = modBuilder('../load-mod-file/rbc1.true.mod');

assert(isequal(viaDynare.params, viaModFile.params), 'Parameter tables differ.');
assert(isequal(viaDynare.varexo(:,1), viaModFile.varexo(:,1)), 'Exogenous names differ.');
assert(isequal(viaDynare.varexo(:,3:4), viaModFile.varexo(:,3:4)), 'Exogenous attributes differ.');
assert(isequal(viaDynare.equations, viaModFile.equations), 'Equation tables differ.');
assert(isequal(viaDynare.tags, viaModFile.tags), 'Equation tags differ.');
assert(isequal(viaDynare.T, viaModFile.T), 'Symbol tables differ.');
assert(isequal(viaDynare.symbols, viaModFile.symbols), 'Untyped symbol lists differ.');

% The value columns are the one legitimate difference: Dynare supplies the computed
% steady state through oo_, whereas the .mod file only carries what an initval block
% states, and rbc1.true.mod has none.
assert(isequal(viaDynare.var(:,1), viaModFile.var(:,1)), 'Endogenous names differ.');
assert(isequal(viaDynare.var(:,3:4), viaModFile.var(:,3:4)), 'Endogenous attributes differ.');
assert(all(isnan([viaModFile.var{:,2}])), 'Endogenous values should be NaN without an initval block.');

% A model read through either route must write the same file.
viaDynare.write('parity_dynare');
viaModFile.write('parity_modfile');
b = modiff('parity_dynare.mod', 'parity_modfile.mod');
assert(b, 'The two routes do not write the same .mod file.');
delete parity_dynare.mod
delete parity_modfile.mod

% The 4-argument form has its .mod counterpart in the Tag option.
viaDynare2 = modBuilder(load('../load-mod-file/rbc2.mat').M_, load('../load-mod-file/rbc2.mat').oo_, '../load-mod-file/rbc2-modfile-original.json', 'endogenous');
viaModFile2 = modBuilder('../load-mod-file/rbc2.true.mod');
assert(isequal(viaDynare2.equations, viaModFile2.equations), 'rbc2 equation tables differ.');
assert(isequal(viaDynare2.var(:,1), viaModFile2.var(:,1)), 'rbc2 endogenous names differ.');

fprintf('t10_json_parity.m: All tests passed\n');
