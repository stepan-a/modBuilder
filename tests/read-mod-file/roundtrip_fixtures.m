% Read every committed .mod fixture back and check that write() reproduces it byte for byte.
%
% This is the acceptance test of the reader: the fixtures were all produced by write(),
% so reading one and writing it again must be the identity. The list is explicit rather
% than a dir() glob, because a glob would silently absorb any fixture a later commit
% writes with different options and quietly weaken the check.
%
% The precision column is the write() precision the fixture was produced with. Only the
% precision/ fixtures use a non-default value; inferring it from the text would be magic
% that could mask a genuine mismatch.

addpath ../utils

fixtures = {
    '../rbc/rbc1.true.mod',                             0
    '../rbc/rbc2.true.mod',                             0
    '../rbc/rbc3.true.mod',                             0
    '../rbc/rbc4.true.mod',                             0
    '../rbc/rbc5.true.mod',                             0
    '../rbc/rbc8.true.mod',                             0
    '../rbc/rbc11.true.mod',                            0
    '../rbc/rbc15a.true.mod',                           0
    '../rbc/rbc15b.true.mod',                           0
    '../tag/t01.true.mod',                              0
    '../tag/rbc2.true.mod',                             0
    '../load-mod-file/rbc1.true.mod',                   0
    '../load-mod-file/rbc2.true.mod',                   0
    '../load-mod-file/rbc1auto.true.mod',               0
    '../reassign/t01_swap.true.mod',                    0
    '../reassign/t01_cycle.true.mod',                   0
    '../steady-state-model/t01.true.mod',               0
    '../steady-state-model/t02.true.mod',               0
    '../steady-state-model/t03.true.mod',               0
    '../steady-state-model/t04.true.mod',               0
    '../steady-state-model/t05.true.mod',               0
    '../steady-state-model/t15.true.mod',               0
    '../steady-options/t01_steady_opts.true.mod',       0
    '../steady-options/t01_steady_opts_flag.true.mod',  0
    '../write/t01_steady.true.mod',                     0
    '../write/t01_steady_check.true.mod',               0
    '../precision/precision_default.true.mod',          0
    '../precision/precision_high.true.mod',            15
    '../precision/precision_initval.true.mod',         10
    '../../examples/two-country/twocountry.mod',        0
    '../../examples/two-country/twocountry_phase.mod',  0
    '../../examples/sw/sw.mod',                         0
};

% Auto-matching is expected on the fixtures whose tags were stripped on purpose.
ws = warning('off', 'modfile:name_equations:autoMatch');
restore = onCleanup(@() warning(ws));

failures = {};

for i = 1:size(fixtures, 1)
    source = fixtures{i,1};
    precision = fixtures{i,2};

    mod = modfile.read(source);
    m = modfile.load(source);

    tmp = [tempname '.mod'];
    m.write(tmp, ...
            initval = mod.has_initval, ...
            steady = mod.steady_cmd, ...
            steady_state_model = mod.has_steady_state_model, ...
            steady_options = modfile.parse_options(mod.steady_options), ...
            check = mod.check_cmd, ...
            precision = precision);

    [identical, differences] = modiff(tmp, source);
    delete(tmp);

    if identical
        fprintf('  ok   %s\n', source);
    else
        fprintf('  FAIL %s (%u differing line(s))\n', source, numel(differences));
        failures{end+1} = source; %#ok<AGROW>
    end
end

if ~isempty(failures)
    error('modBuilder:roundtrip:mismatch', 'Round-trip differs for %u fixture(s):\n  %s', numel(failures), strjoin(failures, sprintf('\n  ')));
end

fprintf('roundtrip_fixtures.m: All tests passed\n');
