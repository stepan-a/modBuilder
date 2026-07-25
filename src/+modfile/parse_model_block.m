function [eqs, locals] = parse_model_block(body, filename, line0)
% Parse the content of a model block into equations, their tags, and model-local variables.
%
% INPUTS:
% - body       [char]     1×n array, the raw text between 'model;' and its 'end'
% - filename   [char]     1×m array, name used in error messages (default '<string>')
% - line0      [double]   scalar, line at which body starts in the file (default 1)
%
% OUTPUTS:
% - eqs        [struct]   k×1 array, one entry per equation:
%                           .expr  [char]    the equation verbatim, 'lhs = rhs' or a bare residual
%                           .lhs   [char]    left-hand side, empty for a bare residual
%                           .rhs   [char]    right-hand side, empty for a bare residual
%                           .tags  [struct]  tag name/value pairs, possibly empty
%                           .line  [double]  1-based line of the equation
% - locals     [struct]   p×1 array, one entry per '#name = expr;' definition:
%                           .name  [char]
%                           .expr  [char]
%                           .line  [double]
%
% REMARKS:
% - Equations are kept verbatim, apart from trimming and folding each line break
%   together with its surrounding blanks into a single space. They are NOT parsed and
%   re-rendered: ast.string() normalises spacing, and a write() of the resulting model
%   would then no longer match the source byte for byte.
% - A tag group is the bracketed list that precedes an equation, e.g.
%   [name = 'y', mcp = 'c > 0']. A tag given without a value, as in [static], records
%   the empty string, matching Dynare's flag tags.
% - The '=' that separates the two sides is the first one at bracket depth zero that is
%   not part of a comparison operator. An equation with more than one such '=' raises
%   modfile:parse_model_block:badEquation, as the JSON constructor path does.
    arguments
        body     (1,:) char
        filename (1,:) char = '<string>'
        line0    (1,1) double = 1
    end

    eqs    = struct('expr', {}, 'lhs', {}, 'rhs', {}, 'tags', {}, 'line', {});
    locals = struct('name', {}, 'expr', {}, 'line', {});

    chunks = modfile.split_semicolons(body, line0);

    for i = 1:numel(chunks)
        [tags, remainder] = local_take_tags(chunks(i).text, filename, chunks(i).line);
        s = local_flatten(remainder);
        if isempty(s)
            if ~isempty(fieldnames(tags))
                error('modfile:parse_model_block:danglingTag', '%s (line %u): a tag group is not followed by an equation.', filename, chunks(i).line)
            end
            continue
        end

        if s(1) == '#'
            if ~isempty(fieldnames(tags))
                error('modfile:parse_model_block:danglingTag', '%s (line %u): a tag group cannot precede a model-local variable.', filename, chunks(i).line)
            end
            pos = local_find_equal(s, filename, chunks(i).line);
            if isempty(pos)
                error('modfile:parse_model_block:badLocalVariable', '%s (line %u): model-local variable definition without "=": %s.', filename, chunks(i).line, s)
            end
            name = strtrim(s(2:pos-1));
            if isempty(regexp(name, '^[A-Za-z_]\w*$', 'once'))
                error('modfile:parse_model_block:badLocalVariable', '%s (line %u): "%s" is not a valid model-local variable name.', filename, chunks(i).line, name)
            end
            locals(end+1) = struct('name', name, 'expr', strtrim(s(pos+1:end)), 'line', chunks(i).line); %#ok<AGROW>
            continue
        end

        pos = local_find_equal(s, filename, chunks(i).line);
        if isempty(pos)
            eqs(end+1) = struct('expr', s, 'lhs', '', 'rhs', '', 'tags', tags, 'line', chunks(i).line); %#ok<AGROW>
        else
            lhs = strtrim(s(1:pos-1));
            rhs = strtrim(s(pos+1:end));
            if isempty(lhs) || isempty(rhs)
                error('modfile:parse_model_block:badEquation', '%s (line %u): equation with an empty side: %s.', filename, chunks(i).line, s)
            end
            eqs(end+1) = struct('expr', s, 'lhs', lhs, 'rhs', rhs, 'tags', tags, 'line', chunks(i).line); %#ok<AGROW>
        end
    end
end

function [tags, remainder] = local_take_tags(chunk, filename, line)
% Peel the leading bracketed tag groups off an equation chunk.
    tags = struct();
    s = strtrim(chunk);
    while ~isempty(s) && s(1) == '['
        stop = find(s == ']', 1);
        if isempty(stop)
            error('modfile:parse_model_block:unterminatedTag', '%s (line %u): tag group is not closed.', filename, line)
        end
        inner = s(2:stop-1);
        entries = regexp(inner, '[^,]+', 'match');
        for i = 1:numel(entries)
            entry = strtrim(entries{i});
            if isempty(entry)
                continue
            end
            token = regexp(entry, '^(\w+)\s*=\s*''(.*)''$', 'tokens', 'once');
            if isempty(token)
                if isempty(regexp(entry, '^\w+$', 'once'))
                    error('modfile:parse_model_block:badTag', '%s (line %u): cannot read the tag "%s".', filename, line, entry)
                end
                tags.(entry) = '';
            else
                tags.(token{1}) = token{2};
            end
        end
        s = strtrim(s(stop+1:end));
    end
    remainder = s;
end

function s = local_flatten(s)
% Trim, and fold every line break with its surrounding blanks into a single space.
    s = strtrim(regexprep(s, '\s*\n\s*', ' '));
end

function pos = local_find_equal(s, filename, line)
% Position of the '=' separating the two sides of an equation, empty when there is none.
    pos = [];
    depth = 0;
    state = 'normal';
    for i = 1:length(s)
        c = s(i);
        switch state
          case 'normal'
            switch c
              case ''''
                state = 'quote';
              case {'(', '['}
                depth = depth + 1;
              case {')', ']'}
                depth = max(depth-1, 0);
              case '='
                if depth == 0
                    % Skip the '=' of a comparison operator: ==, >=, <=, != and ~=.
                    before = '';
                    if i > 1
                        before = s(i-1);
                    end
                    after = '';
                    if i < length(s)
                        after = s(i+1);
                    end
                    if ismember(before, '<>=!~') || ismember(after, '=')
                        continue
                    end
                    if ~isempty(pos)
                        error('modfile:parse_model_block:badEquation', '%s (line %u): equation contains more than one "=": %s.', filename, line, s)
                    end
                    pos = i;
                end
            end
          case 'quote'
            if c == ''''
                state = 'normal';
            end
        end
    end
end
