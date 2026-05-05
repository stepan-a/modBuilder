% print_steady_plan smoke test: must not error and must produce non-empty output.

m = modBuilder();
m.add('y', 'y = exp(a)*k^alpha');
m.add('a', 'a = rho*a(-1) + e');
m.parameter('alpha', 0.36);
m.parameter('rho', 0.95);
m.exogenous('e', 0);
m.exogenous('k', 1);

% Capture stdout; a successful run prints multiple lines.
out = evalc('m.print_steady_plan()');

if isempty(out), error('print_steady_plan produced no output.'), end
if isempty(strfind(out, 'Block 1'))
    error('Expected "Block 1" in output, got:\n%s', out)
end
if isempty(strfind(out, 'Steady-state plan'))
    error('Expected header "Steady-state plan" in output.')
end

fprintf('t07.m: print_steady_plan smoke OK\n');
