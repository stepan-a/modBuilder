function frame = macro_frame(kind, id, iter, cond, exclusive, values, names)
% Build a directive frame, the unit of provenance carried by every expanded line.
%
% INPUTS:
% - kind        [char]      'if' or 'for'
% - id          [double]    source line of the directive, identifying the construct
% - iter        [double]    branch index for 'if', iteration index for 'for'
% - cond        [char]      MATLAB source of the condition, for 'if'; '' when the branch
%                           is an @#else, or when the condition does not render
% - exclusive   [logical]   for 'if', true when the construct has a single branch
% - values      [cell]      for 'for', the values bound to the indices in this iteration
% - names       [cell]      for 'for', the names of the loop indices
%
% OUTPUTS:
% - frame       [struct]    the frame, or an empty 0×1 frame array when called with no
%                           argument, which is the top-level context
%
% REMARKS:
% - A single constructor keeps the field order identical everywhere, which matters
%   because frames are concatenated into stacks and compared field by field.
% - The construct is identified by the source line of its directive rather than by a
%   counter, so that the same @#for reached twice through different paths is still
%   recognised as one construct.
    arguments
        kind      (1,:) char = ''
        id        (1,1) double = 0
        iter      (1,1) double = 0
        cond      (1,:) char = ''
        exclusive (1,1) logical = false
        values    (1,:) cell = {}
        names     (1,:) cell = {}
    end

    if isempty(kind)
        frame = struct('kind', {}, 'id', {}, 'iter', {}, 'cond', {}, 'exclusive', {}, 'values', {}, 'names', {});
        return
    end

    frame = struct('kind', kind, 'id', id, 'iter', iter, 'cond', cond, 'exclusive', exclusive, 'values', {values}, 'names', {names});
end
