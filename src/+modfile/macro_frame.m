function frame = macro_frame(kind, id, iter, cond, exclusive, values, names, line, sets, sizes)
% Build a directive frame, the unit of provenance carried by every expanded line.
%
% INPUTS:
% - kind        [char]      'if' or 'for'
% - id          [double]    key identifying the construct, see modfile.construct_id
% - iter        [double]    branch index for 'if', iteration index for 'for'
% - cond        [char]      MATLAB source of the condition, for 'if'; '' when the branch
%                           is an @#else, or when the condition does not render
% - exclusive   [logical]   for 'if', true when the construct has a single branch
% - values      [cell]      for 'for', the values bound to the indices in this iteration
% - names       [cell]      for 'for', the names of the loop indices
% - line        [double]    the source line of the directive, for diagnostics
% - sets        [cell]      for 'for', the MATLAB source of each index's set, so that the
%                           emitter can write it in place of the values the loop bound;
%                           '' when no faithful source exists (see local_index_sets in
%                           modfile.expand_macros)
% - sizes       [double]    for 'for', how many values each set holds; the emitter uses
%                           a source only when it observed that many
%
% OUTPUTS:
% - frame       [struct]    the frame, or an empty 0×1 frame array when called with no
%                           argument, which is the top-level context
%
% REMARKS:
% - A single constructor keeps the field order identical everywhere, which matters
%   because frames are concatenated into stacks and compared field by field.
% - The construct is identified by modfile.construct_id, built from the file and the
%   line, rather than by the line alone: an included file starts again at line 1, so two
%   constructs would otherwise share a key and be emitted as one.
    arguments
        kind      (1,:) char = ''
        id        (1,1) double = 0
        iter      (1,1) double = 0
        cond      (1,:) char = ''
        exclusive (1,1) logical = false
        values    (1,:) cell = {}
        names     (1,:) cell = {}
        line      (1,1) double = 0
        sets      (1,:) cell = {}
        sizes     (1,:) double = []
    end

    if isempty(kind)
        frame = struct('kind', {}, 'id', {}, 'iter', {}, 'cond', {}, 'exclusive', {}, 'values', {}, 'names', {}, 'line', {}, 'sets', {}, 'sizes', {});
        return
    end

    frame = struct('kind', kind, 'id', id, 'iter', iter, 'cond', cond, 'exclusive', exclusive, 'values', {values}, 'names', {names}, 'line', line, 'sets', {sets}, 'sizes', sizes);
end
