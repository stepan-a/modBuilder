addpath ../utils

% Test rm method: basic removal of multiple equations

% Build a simple model
m = modBuilder();
m.add('c', 'c = w*h');
m.add('y', 'y = c + i + g');
m.add('i', 'i = r*k');
m.add('k', 'k = delta*k(-1) + i');
m.parameter('w', 1.5);
m.parameter('r', 0.05);
m.parameter('delta', 0.95);
m.exogenous('h', NaN);
m.exogenous('g', NaN);

% Tag equations to verify tag cleanup on removal
m.tag('c', 'block', 'consumption');
m.tag('i', 'block', 'investment');
m.tag('y', 'block', 'output');

% Verify initial state
if m.size('endogenous') ~= 4
    error('Initial model should have 4 endogenous variables')
end

if ~all(isfield(m.tags, {'c', 'i', 'y', 'k'}))
    error('Tag entries for every equation should exist before removal')
end

% Remove multiple equations at once
m.rm('c', 'i');

% Verify equations were removed
if m.size('endogenous') ~= 2
    error('Model should have 2 endogenous variables after removing c and i')
end

if any(strcmp(m.equations(:,1), 'c'))
    error('Equation c should be removed')
end

if any(strcmp(m.equations(:,1), 'i'))
    error('Equation i should be removed')
end

if ~any(strcmp(m.equations(:,1), 'y'))
    error('Equation y should still exist')
end

if ~any(strcmp(m.equations(:,1), 'k'))
    error('Equation k should still exist')
end

% Check that removed variables became exogenous if still used
if ~m.isexogenous('c')
    error('Variable c should be exogenous after equation removal (still used in y)')
end

if ~m.isexogenous('i')
    error('Variable i should be exogenous after equation removal (still used in y and k)')
end

% Tag entries of removed equations must be cleaned up; entries of surviving ones must remain
if isfield(m.tags, 'c')
    error('Tag entry for removed equation c should be cleaned up')
end

if isfield(m.tags, 'i')
    error('Tag entry for removed equation i should be cleaned up')
end

if ~isfield(m.tags, 'y') || ~strcmp(m.tags.y.block, 'output')
    error('Tag entry for surviving equation y should be preserved with custom field intact')
end

if ~isfield(m.tags, 'k')
    error('Tag entry for surviving equation k should still exist')
end

fprintf('t01.m: All tests passed\n');
