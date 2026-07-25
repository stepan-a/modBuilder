function rows = parse_steady_state_model(body, filename, line0)
% Parse the content of a steady_state_model block.
%
% INPUTS:
% - body       [char]     1×n array, the raw text between 'steady_state_model;' and its 'end'
% - filename   [char]     1×m array, name used in error messages (default '<string>')
% - line0      [double]   scalar, line at which body starts in the file (default 1)
%
% OUTPUTS:
% - rows       [struct]   k×1 array, in file order:
%                           .names  [cell]     assigned names; one element for a scalar
%                                              assignment, several for a multi-output call
%                           .expr   [char]     right-hand side, verbatim
%                           .line   [double]   1-based line of the assignment
%
% REMARKS:
% - Two forms occur: 'x = expr;' and the multi-output '[a, b] = f(args);' that Dynare
%   accepts for a MATLAB function returning several outputs. modBuilder represents the
%   first with steady() or steady_aux() depending on whether the name is a declared
%   symbol, and the second with steady_call(); that dispatch needs the symbol tables and
%   therefore happens in the caller, not here.
% - Row order is file order. write() re-sorts the block through checksteady(), whose
%   topological sort with a smallest-index tie-break returns the input order unchanged
%   when that order is already valid, which it must be for Dynare to have run the file.
    arguments
        body     (1,:) char
        filename (1,:) char = '<string>'
        line0    (1,1) double = 1
    end

    rows = struct('names', {}, 'expr', {}, 'line', {});
    chunks = modfile.split_semicolons(body, line0);

    for i = 1:numel(chunks)
        s = strtrim(regexprep(chunks(i).text, '\s*\n\s*', ' '));
        if isempty(s)
            continue
        end

        pos = local_find_equal(s);
        if isempty(pos)
            error('modfile:parse_steady_state_model:badAssignment', '%s (line %u): steady_state_model entry without "=": %s.', filename, chunks(i).line, s)
        end

        lhs = strtrim(s(1:pos-1));
        rhs = strtrim(s(pos+1:end));
        if isempty(rhs)
            error('modfile:parse_steady_state_model:badAssignment', '%s (line %u): steady_state_model entry with an empty right-hand side: %s.', filename, chunks(i).line, s)
        end

        if ~isempty(lhs) && lhs(1) == '['
            if lhs(end) ~= ']'
                error('modfile:parse_steady_state_model:badAssignment', '%s (line %u): output list "%s" is not closed.', filename, chunks(i).line, lhs)
            end
            names = strtrim(strsplit(lhs(2:end-1), ','));
            names = names(~cellfun(@isempty, names));
        else
            names = {lhs};
        end

        for j = 1:numel(names)
            if isempty(regexp(names{j}, '^[A-Za-z_]\w*$', 'once'))
                error('modfile:parse_steady_state_model:badAssignment', '%s (line %u): "%s" is not a valid assignment target.', filename, chunks(i).line, names{j})
            end
        end

        rows(end+1) = struct('names', {names}, 'expr', rhs, 'line', chunks(i).line); %#ok<AGROW>
    end
end

function pos = local_find_equal(s)
% Position of the top-level '=' of an assignment, empty when there is none.
    pos = [];
    depth = 0;
    inquote = false;
    for i = 1:length(s)
        c = s(i);
        if inquote
            if c == ''''
                inquote = false;
            end
            continue
        end
        switch c
          case ''''
            inquote = true;
          case {'(', '['}
            depth = depth + 1;
          case {')', ']'}
            depth = max(depth-1, 0);
          case '='
            if depth == 0
                pos = i;
                return
            end
        end
    end
end
