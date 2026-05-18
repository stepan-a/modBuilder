% Test that error IDs follow the modBuilder:method:reason convention.
% This pins the IDs for the major method families so future edits can
% catch accidental drift. Messages themselves are pinned by t01..t28.

% ---- validate_equation_syntax ----
m = modBuilder();
assert_id(@() m.add('y','y = a*(x'),     'modBuilder:validate_equation_syntax:unbalancedParens');
assert_id(@() m.add('y','y == x'),       'modBuilder:validate_equation_syntax:multipleEquals');
assert_id(@() m.add('y','y = x./z'),     'modBuilder:validate_equation_syntax:invalidOp');

% ---- declare_symbol (parameter/exogenous/endogenous via the helper) ----
m = modBuilder();
m.add('y', 'y = alpha*x');
assert_id(@() m.parameter('not_a_symbol', 0.5), 'modBuilder:declare_symbol:unknownSymbol');
assert_id(@() m.parameter('y',           0.5), 'modBuilder:declare_symbol:typeConversion');
assert_id(@() m.exogenous('y',           0.5), 'modBuilder:declare_symbol:typeConversion');
assert_id(@() m.endogenous('not_a_var',  0.5), 'modBuilder:declare_symbol:notEndogenous');

% ---- change ----
m = modBuilder();
m.add('y', 'y = a*x');
assert_id(@() m.change('z', 'z = b'),                'modBuilder:change:unknownSymbol');
assert_id(@() m.change('y', 'b = a*x'),              'modBuilder:change:notInEquation');

% ---- remove ----
m = modBuilder();
assert_id(@() m.remove('nope'), 'modBuilder:remove:unknownSymbol');

% ---- solve ----
m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1.0);
m.endogenous('y', 0.5);
assert_id(@() m.solve('y','nonexistent_symbol',1.0), 'modBuilder:solve:unknownSymbol');

% ---- solve_system ----
m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1.0);
m.endogenous('y', 0.5);
assert_id(@() m.solve_system({'y','y'},{'alpha'}),   'modBuilder:solve_system:nonSquare');
assert_id(@() m.solve_system({'y'},{'undeclared'}),  'modBuilder:solve_system:unknownSymbol');

% ---- flip ----
m = modBuilder();
m.add('y', 'y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1.0);
m.endogenous('y', 0.5);
assert_id(@() m.flip('not_endo','x'),                'modBuilder:flip:notEndogenous');
assert_id(@() m.flip('y','not_exo'),                 'modBuilder:flip:notExogenous');

% ---- subsasgn dot-assignment to an unknown symbol ----
m = modBuilder();
m.add('y','y = alpha*x');
m.parameter('alpha', 0.5);
m.exogenous('x', 1.0);
m.endogenous('y', 1.0);
assert_id(@() set_unknown_dot(m),                    'modBuilder:subsasgn:unknownSymbol');

% ---- set_optional_fields (the former assert) ----
% Odd-count optional args: 'long_name' key without value.
assert_id(@() m.parameter('alpha', 0.5, 'long_name'),'modBuilder:set_optional_fields:badPair');


function assert_id(thunk, expected)
    threw = false;
    try
        thunk();
    catch e
        threw = true;
        assert(strcmp(e.identifier, expected), ...
               'Expected id "%s", got "%s" (msg: %s)', expected, e.identifier, e.message);
    end
    assert(threw, 'Expected error with id "%s" but no error was thrown.', expected);
end

function set_unknown_dot(m)
    m.no_such_symbol = 1.0;
end
