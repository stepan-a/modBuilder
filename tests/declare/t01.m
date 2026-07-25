% Declaring symbols that appear in no equation, setting the declaration order, and the
% constructor's badType guard.
%
% A .mod file may declare a parameter or an exogenous variable that no equation
% references: tests/load-mod-file/rbc1.true.mod declares phi, and examples/sw/sw.mod has
% several.

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

% --- reorder --------------------------------------------------------------------------
% add() declares the endogenous variables in equation order, but the var statement of a
% .mod file fixes that order independently; reassign() and flip() also produce models
% where the two differ, and write() prints the var list from the table.
r = modBuilder();
r.add('y', 'y = alpha*k');
r.add('k', 'k = (1-delta)*k(-1) + i');
r.parameter('alpha', 0.33);
r.parameter('delta', 0.025);
r.exogenous('i', 0);

assert(isequal(r.var(:,1)', {'y', 'k'}), 'add() declares in equation order.');
r.reorder('endogenous', {'k', 'y'});
assert(isequal(r.var(:,1)', {'k', 'y'}), 'reorder should set the declaration order.');
assert(isequal(r.equations(:,1)', {'y', 'k'}), 'The equations keep their own order.');

% The values and the attributes travel with their row.
r.endogenous('k', 3, 'texname', 'K');
r.reorder('endogenous', {'y', 'k'});
row = strcmp(r.var(:,1), 'k');
assert(r.var{row,2} == 3 && strcmp(r.var{row,4}, 'K'), 'A row keeps its value and attributes.');

r.reorder('parameters', {'delta', 'alpha'});
assert(isequal(r.params(:,1)', {'delta', 'alpha'}), 'Parameters can be reordered too.');

% Anything that is not a permutation is refused, so a typo cannot drop a symbol.
thrown = false;
try
    r.reorder('endogenous', {'y'});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:reorder:badPermutation');
end
assert(thrown, 'Expected reorder:badPermutation.');

thrown = false;
try
    r.reorder('endogenous', {'y', 'nope'});
catch ME
    thrown = strcmp(ME.identifier, 'modBuilder:reorder:badPermutation');
end
assert(thrown, 'Expected reorder:badPermutation for an unknown name.');

fprintf('declare/t01.m: All tests passed\n');
