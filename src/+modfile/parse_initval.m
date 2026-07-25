function rows = parse_initval(body, keyword, filename, line0)
% Parse the content of an initval block into name/expression pairs.
%
% INPUTS:
% - body       [char]     1×n array, the raw text between 'initval;' and its 'end'
% - keyword    [char]     1×m array, the block keyword, used in diagnostics (default 'initval')
% - filename   [char]     1×p array, name used in error messages (default '<string>')
% - line0      [double]   scalar, line at which body starts in the file (default 1)
%
% OUTPUTS:
% - rows       [cell]     k×3 array, {name, expression, line} in file order
%
% REMARKS:
% - The values are the initial guess Dynare hands to the steady-state solver. modBuilder
%   keeps them in the value column of its var and varexo tables, the same slot the
%   Dynare-based constructor fills from oo_.steady_state and oo_.exo_steady_state, and
%   write(initval=true) emits them back.
% - Right-hand sides may be expressions over the parameters, so they are returned as
%   text and evaluated by the caller once the calibration is known.
% - A repeated name is kept as a separate row: the caller applies them in order, so the
%   last assignment wins, as in Dynare.
    arguments
        body     (1,:) char
        keyword  (1,:) char = 'initval'
        filename (1,:) char = '<string>'
        line0    (1,1) double = 1
    end

    rows = cell(0, 3);
    chunks = modfile.split_semicolons(body, line0);

    for i = 1:numel(chunks)
        s = strtrim(regexprep(chunks(i).text, '\s*\n\s*', ' '));
        if isempty(s)
            continue
        end

        pos = find(s == '=', 1);
        if isempty(pos)
            error('modfile:parse_initval:badAssignment', '%s (line %u): %s entry without "=": %s.', filename, chunks(i).line, keyword, s)
        end

        name = strtrim(s(1:pos-1));
        expr = strtrim(s(pos+1:end));
        if isempty(regexp(name, '^[A-Za-z_]\w*$', 'once'))
            error('modfile:parse_initval:badAssignment', '%s (line %u): "%s" is not a valid %s target.', filename, chunks(i).line, name, keyword)
        end
        if isempty(expr)
            error('modfile:parse_initval:badAssignment', '%s (line %u): %s entry for "%s" has an empty right-hand side.', filename, chunks(i).line, keyword, name)
        end

        rows(end+1, :) = {name, expr, chunks(i).line}; %#ok<AGROW>
    end
end
