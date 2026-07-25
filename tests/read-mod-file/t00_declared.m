% Declaring symbols that appear in no equation, and the constructor's badType guard.
%
% A .mod file may declare a parameter or an exogenous variable that no equation
% references (tests/load-mod-file/rbc1.true.mod declares phi, examples/sw/sw.mod has
% several). The reader emits 'declared', true for those.

m = modBuilder();
m.add('y', 'y = alpha*k');

% Without the flag, an unused symbol is rejected as before.
thrown = false;
try
    m.parameter('phi', 0.1);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:declare_symbol:unknownSymbol');
end
assert(thrown, 'Expected declare_symbol:unknownSymbol without the declared flag.');

% With the flag, the parameter lands in the table with its calibration.
m.parameter('phi', 0.1, 'declared', true);
assert(m.isparameter('phi'), 'phi should be a parameter.');
assert(isequal(m.params{strcmp(m.params(:,1), 'phi'), 2}, 0.1), 'phi should be calibrated to 0.1.');

% Metadata still goes through the usual attribute parser.
m.parameter('psi', NaN, 'declared', true, 'texname', '\psi', 'long_name', 'Inverse Frisch');
row = strcmp(m.params(:,1), 'psi');
assert(strcmp(m.params{row,3}, 'Inverse Frisch'), 'psi long_name not recorded.');
assert(strcmp(m.params{row,4}, '\psi'), 'psi texname not recorded.');
assert(isnan(m.params{row,2}), 'psi should be uncalibrated.');

% Exogenous variables take the flag too.
m.exogenous('u', 0, 'declared', true);
assert(m.isexogenous('u'), 'u should be exogenous.');

% The flag never allows converting an endogenous variable.
thrown = false;
try
    m.parameter('y', 1, 'declared', true);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:declare_symbol:typeConversion');
end
assert(thrown, 'Expected declare_symbol:typeConversion for an endogenous variable.');

% The flag must be a logical scalar. The symbol has to be one that already appears in
% the model, otherwise the appears-in-the-model check fires before the attribute
% parser is reached (see tests/errors/t34).
thrown = false;
try
    m.parameter('alpha', 1, 'declared', 'yes');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:set_optional_fields:badType');
end
assert(thrown, 'Expected set_optional_fields:badType for a non-logical declared value.');

% A malformed flag never widens the precondition either: an unknown symbol is still
% rejected before the attribute parser runs.
thrown = false;
try
    m.parameter('chi', 1, 'declared', 'yes');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:declare_symbol:unknownSymbol');
end
assert(thrown, 'Expected declare_symbol:unknownSymbol to keep firing first.');

% Implicit loops forward the flag to every expanded declaration.
m.parameter('gamma_$1', 0.5, 'declared', true, {1, 2, 3});
assert(m.isparameter('gamma_1') && m.isparameter('gamma_2') && m.isparameter('gamma_3'), 'Implicit loop did not forward the declared flag.');

% An unrecognised constructor argument list is now an error rather than a silently
% half-built object.
thrown = false;
try
    modBuilder(42);
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:modBuilder:badType');
end
assert(thrown, 'Expected modBuilder:modBuilder:badType.');

% A char argument is the path to a .mod file, so a missing one says so plainly rather
% than failing on an argument validator further down.
thrown = false;
try
    modBuilder('no-such-file.mod');
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:modBuilder:unknownFile');
end
assert(thrown, 'Expected modBuilder:modBuilder:unknownFile.');

fprintf('t00_declared.m: All tests passed\n');
