function rows = parse_declaration(body, keyword, filename, line)
% Parse the symbol list of a var, varexo or parameters declaration.
%
% INPUTS:
% - body       [char]   1×n array, the text following the keyword, without the ';'
% - keyword    [char]   1×m array, the declaring keyword, used in diagnostics
% - filename   [char]   1×p array, name used in error messages (default '<string>')
% - line       [double] scalar, line of the declaration, used in error messages (default 0)
%
% OUTPUTS:
% - rows       [cell]   k×4 array, {name, tex_name, long_name, line} per declared symbol,
%                       with '' for an attribute the declaration does not give
%
%                       The line is that of the symbol itself, not of the keyword: a
%                       declaration list may span a macro loop, and the translator groups
%                       the symbols back into it by line.
%
% EXAMPLES:
% modfile.parse_declaration('a b c', 'var')
% modfile.parse_declaration('alpha $\alpha$ (long_name=''Capital share'')', 'parameters')
%
% REMARKS:
% - The grammar mirrors symbol_list_with_tex_and_partition in Dynare's DynareBison.yy:
%   commas are optional and may appear before or after any element, a TeX name is
%   delimited by '$', and a parenthesised partition carries key='value' pairs.
% - An empty body yields zero rows. That case is reached in practice: modBuilder's
%   write() emits 'varexo ;' for a model with no exogenous variable, and such files
%   are committed as test fixtures.
% - Only the 'long_name' partition key has a slot in modBuilder. Any other key is
%   dropped with a modfile:parse_declaration:ignoredPartition warning rather than an
%   error, since it carries no model semantics.
    arguments
        body     (1,:) char
        keyword  (1,:) char
        filename (1,:) char = '<string>'
        line     (1,1) double = 0
    end

    rows = cell(0, 4);

    s = body;
    n = length(s);
    i = 1;
    % Line of every character of the body, so each symbol keeps its own.
    linum = cumsum(s == newline) + line;

    while i <= n
        c = s(i);

        if isspace(c) || c == ','
            i = i + 1;
            continue
        end

        if ~(isletter(c) || c == '_')
            error('modfile:parse_declaration:badSymbol', '%s (line %u): unexpected character "%c" in the %s declaration.', filename, line, c, keyword)
        end

        j = i;
        while j <= n && (isletter(s(j)) || (s(j) >= '0' && s(j) <= '9') || s(j) == '_')
            j = j + 1;
        end
        name = s(i:j-1);
        nameline = linum(i);
        i = j;

        tex       = '';
        long_name = '';

        % A TeX name and a partition may follow, in that order, separated by blanks.
        % Commas are not skipped here: a comma ends the current symbol's attributes.
        k = i;
        while k <= n && isspace(s(k))
            k = k + 1;
        end
        if k <= n && s(k) == '$'
            stop = find(s(k+1:end) == '$', 1);
            if isempty(stop)
                error('modfile:parse_declaration:unterminatedTexName', '%s (line %u): TeX name of "%s" is not closed.', filename, line, name)
            end
            tex = s(k+1:k+stop-1);
            i = k + stop + 1;
            k = i;
            while k <= n && isspace(s(k))
                k = k + 1;
            end
        end
        if k <= n && s(k) == '('
            stop = local_match_paren(s(k:end));
            if isempty(stop)
                error('modfile:parse_declaration:unterminatedPartition', '%s (line %u): partition of "%s" is not closed.', filename, line, name)
            end
            long_name = local_partition_long_name(s(k+1:k+stop-2), name, keyword, filename, line);
            i = k + stop;
        end

        rows(end+1, :) = {name, tex, long_name, nameline}; %#ok<AGROW>
    end
end

function long_name = local_partition_long_name(inner, name, keyword, filename, line)
% Extract the long_name entry of a partition group, warning about the other keys.
    long_name = '';
    pairs = regexp(inner, '(\w+)\s*=\s*''([^'']*)''', 'tokens');
    for i = 1:numel(pairs)
        key   = pairs{i}{1};
        value = pairs{i}{2};
        if strcmp(key, 'long_name')
            long_name = value;
        else
            modfile.warn('modfile:parse_declaration:ignoredPartition', '%s (line %u): partition key "%s" of %s "%s" has no counterpart in modBuilder and is ignored.', filename, line, key, keyword, name);
        end
    end
end

function stop = local_match_paren(s)
% Index of the ')' matching the '(' at s(1), or empty when there is none.
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
          case '('
            depth = depth + 1;
          case ')'
            depth = depth - 1;
            if depth == 0
                stop = i;
                return
            end
        end
    end
    stop = [];
end
