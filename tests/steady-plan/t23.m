% Regression: calibration_swaps must survive a save/load round-trip.
%
% Background: saveobj/loadobj used to omit the calibration_swaps property,
% so any swap registered via m.calibrate(...) was silently dropped on
% reload and any subsequent steady_plan ran on the wrong unknown set.

m = modBuilder();
m.add('y', 'y = alpha*x + beta*c');
m.add('c', 'c = rho*c(-1) + e');
m.parameter('alpha', 0.5);
m.parameter('beta', 0.5);
m.parameter('rho', 0.9);
m.exogenous('x', 1);
m.exogenous('e', 0);

m.calibrate('y', 1, 'alpha');
m.calibrate('c', 2, 'rho');

before = m.calibration_swaps;
if size(before, 1) ~= 2
    error('Setup error: expected 2 swaps before save, got %d.', size(before, 1))
end

matfile = [tempname(), '.mat'];
cleaner = onCleanup(@() delete(matfile));
save(matfile, 'm');
clear m
loaded = load(matfile);
m = loaded.m;

after = m.calibration_swaps;
if size(after, 1) ~= size(before, 1)
    error('calibration_swaps lost on round-trip: %d rows before, %d after.', ...
          size(before, 1), size(after, 1))
end
if ~isequal(before, after)
    error('calibration_swaps content changed across save/load.')
end

% Backward compatibility: a struct that pre-dates the saveobj fix (no
% calibration_swaps field) must still load, with the property left at
% its default empty value.
s = struct();
s.params = m.params;
s.varexo = m.varexo;
s.var = m.var;
s.tags = m.tags;
s.symbols = m.symbols;
s.equations = m.equations;
s.steady_state = m.steady_state;
s.T = m.T;
s.date = m.date;
m_legacy = modBuilder.loadobj(s);
if ~isempty(m_legacy.calibration_swaps)
    error('Legacy struct without calibration_swaps must load with an empty default.')
end

fprintf('t23.m: calibration_swaps round-trips through save/load\n');
