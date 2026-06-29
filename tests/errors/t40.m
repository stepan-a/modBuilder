% Test that add() rejects redefining an endogenous variable that already
% has an equation, with the documented identifier. This pins the guard that
% rbc/rbc6 exercises only indirectly (via should_fail, which cannot verify
% the reason). Use change() to replace an equation on purpose.

m = modBuilder();
m.add('a', 'a = rho*a(-1) + e');
m.add('b', 'b = tau*a(-1) + u');
m.parameter('rho', 0.95);
m.parameter('tau', 0.025);
m.exogenous('e', 0);
m.exogenous('u', 0);

% Re-adding 'a' must throw the duplicate-equation error.
assert_id(@() m.add('a', 'a = rho*a(-1) + e'), 'modBuilder:addeq:alreadyExists');

% The rejected add must leave the original equation untouched.
idx = strcmp('a', m.equations(:,1));
assert(sum(idx) == 1, 'expected exactly one equation keyed to "a"');
assert(strcmp(m.equations{idx,2}, 'a = rho*a(-1) + e'), ...
       'rejected add must not alter the existing equation, got: %s', m.equations{idx,2});

% change() is the sanctioned way to redefine it, and must succeed. The new
% equation keeps rho and e in use so nothing is orphaned.
m.change('a', 'a = rho*a(-1) + 0.5*e');
idx = strcmp('a', m.equations(:,1));
assert(strcmp(m.equations{idx,2}, 'a = rho*a(-1) + 0.5*e'), ...
       'change should redefine the equation for "a"');


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
