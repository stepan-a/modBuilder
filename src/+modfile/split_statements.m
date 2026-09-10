function stmts = split_statements(txt, filename)
% Split a comment-free .mod file into top-level statements, blocks and native lines.
%
% INPUTS:
% - txt        [char]     1×n array, content of a .mod file, already passed through
%                         modfile.strip_comments
% - filename   [char]     1×m array, name used in error messages (default '<string>')
%
% OUTPUTS:
% - stmts      [struct]   k×1 array, one entry per top-level statement, block or
%                         native MATLAB statement:
%                           .kind      [char]  'statement', 'block' or 'native'
%                           .keyword   [char]  leading identifier, e.g. 'var', 'model';
%                                              for a native line its first token, or
%                                              empty when it starts with none
%                           .options   [char]  text inside the option group that
%                                              immediately follows the keyword, e.g.
%                                              'linear, bytecode' for model(linear, bytecode);
%                                              empty when there is none
%                           .rest      [char]  for a statement, everything after the
%                                              keyword and its option group; for a
%                                              native line, the line itself
%                           .body      [char]  for a block, the raw text between the
%                                              opening ';' and the matching 'end'
%                           .line      [double] 1-based line where the statement starts
%
% REMARKS:
% - What opens a statement is decided the way Dynare's lexer decides it (the <INITIAL>
%   rules of DynareFlex.ll): a first token that is a Dynare keyword or a declared
%   symbol opens a Dynare statement, which runs to the next ';' outside quotes, TeX
%   names, parentheses and brackets. Anything else opens a native MATLAB statement,
%   which runs to the end of the line, and on to the next line while the line ends
%   with '...'. A native line is reported as such and never parsed: the model has no
%   use for it, and it may hold anything.
% - The bracket test matters inside the model block, where the equation tag group
%   [name = 'x', mcp = 'y > 0'] must not be cut.
% - Blocks are recognised by their keyword and closed by a chunk that is exactly 'end'.
%   Their body is returned uncut, because each block has its own sub-scanner: the
%   model block, for instance, keeps equations verbatim. Inside a block nothing is
%   native: a 'var y; stderr 0.01;' of a shocks block starts with no keyword.
% - A 'verbatim' block holds arbitrary MATLAB code, whose quotes are transposes and
%   whose 'end' keywords close ifs and loops. Its body is not scanned: the block ends
%   at the first line that is exactly 'end;', which is what Dynare's lexer does as
%   well, and the statement is skipped whole.
% - The declared symbols are collected from the declarations as they are met, which
%   is also how Dynare knows them: a declaration precedes every use of its symbols.
% - A Dynare statement that no ';' closes raises
%   modfile:split_statements:trailingText, an unclosed block raises
%   modfile:split_statements:unterminatedBlock, and a quote a Dynare statement leaves
%   open at the end of its line raises modfile:split_statements:unterminatedString: a
%   quoted value does not span lines, so what follows would be read as one long string.
%   A native line is free to hold a transpose, which is why the check sits here and
%   not in modfile.strip_comments.
    arguments
        txt      (1,:) char
        filename (1,:) char = '<string>'
    end

    BLOCK_KEYWORDS = modfile.block_keywords();
    KEYWORDS = [modfile.statement_keywords(), BLOCK_KEYWORDS];
    DECLARATIONS = {'var', 'varexo', 'varexo_det', 'parameters', 'trend_var', 'log_trend_var', 'model_local_variable'};

    n = length(txt);
    % Line of every character, so a chunk's start offset maps straight to a line.
    linum = cumsum(txt == newline) + 1;

    stmts = struct('kind', {}, 'keyword', {}, 'options', {}, 'rest', {}, 'body', {}, 'line', {});
    declared = {};
    i = local_skip_blanks(txt, 1);
    while i <= n
        if local_is_native(txt, i, KEYWORDS, declared)
            [text, next] = local_native_line(txt, i);
            stmts(end+1) = struct('kind', 'native', 'keyword', local_first_token(text), 'options', '', 'rest', strtrim(text), 'body', '', 'line', linum(i)); %#ok<AGROW>
            i = local_skip_blanks(txt, next);
            continue
        end

        chunk = local_chunk(txt, i, filename, linum);
        if isempty(chunk)
            error('modfile:split_statements:trailingText', '%s: text after the last '';'' at line %u: "%s".', filename, linum(i), strtrim(txt(i:n)))
        end
        [keyword, options, rest] = modfile.parse_head(chunk.text);
        if ismember(lower(keyword), DECLARATIONS)
            declared = [declared, regexp(chunk.text, '[A-Za-z_]\w*', 'match')]; %#ok<AGROW>
        end

        if strcmp(lower(keyword), 'verbatim')
            [start, stop] = regexp(txt(chunk.last+1:end), '^[ \t]*end[ \t]*;[ \t]*$', 'once', 'start', 'end', 'lineanchors');
            if isempty(start)
                error('modfile:split_statements:unterminatedBlock', '%s: block "%s" opened at line %u is never closed by "end;".', filename, keyword, linum(i))
            end
            stmts(end+1) = struct('kind', 'block', 'keyword', keyword, 'options', options, 'rest', rest, 'body', txt(chunk.last+1:chunk.last+start-1), 'line', linum(i)); %#ok<AGROW>
            i = local_skip_blanks(txt, chunk.last + stop + 1);
        elseif ismember(lower(keyword), BLOCK_KEYWORDS)
            % Gather the chunks up to the matching 'end', nested blocks included.
            depth = 1;
            j = local_skip_blanks(txt, chunk.last + 1);
            while true
                inner = local_chunk(txt, j, filename, linum);
                if isempty(inner)
                    error('modfile:split_statements:unterminatedBlock', '%s: block "%s" opened at line %u is never closed by "end;".', filename, keyword, linum(i))
                end
                [innerkey, ~, innerrest] = modfile.parse_head(inner.text);
                if strcmp(lower(innerkey), 'end') && isempty(strtrim(innerrest))
                    depth = depth - 1;
                    if depth == 0
                        break
                    end
                elseif ismember(lower(innerkey), BLOCK_KEYWORDS)
                    depth = depth + 1;
                end
                j = local_skip_blanks(txt, inner.last + 1);
            end
            stmts(end+1) = struct('kind', 'block', 'keyword', keyword, 'options', options, 'rest', rest, 'body', txt(chunk.last+1:inner.first-1), 'line', linum(i)); %#ok<AGROW>
            i = local_skip_blanks(txt, inner.last + 1);
        else
            if ~isempty(keyword) || ~isempty(strtrim(rest))
                stmts(end+1) = struct('kind', 'statement', 'keyword', keyword, 'options', options, 'rest', rest, 'body', '', 'line', linum(i)); %#ok<AGROW>
            end
            i = local_skip_blanks(txt, chunk.last + 1);
        end
    end
end

function i = local_skip_blanks(txt, i)
% Position of the first non-blank character at or after i.
    n = length(txt);
    while i <= n && isspace(txt(i))
        i = i + 1;
    end
end

function tf = local_is_native(txt, i, keywords, declared)
% True when what starts at i is a native MATLAB statement for Dynare's lexer: its
% first token is neither a Dynare keyword nor a declared symbol, or it is no token at
% all, such as the '[' of a MATLAB multiple assignment.
    token = local_first_token(txt(i:min(length(txt), i+255)));
    tf = isempty(token) || (~ismember(lower(token), keywords) && ~ismember(token, declared));
end

function token = local_first_token(text)
% The identifier a text starts with, or empty.
    token = regexp(text, '^\s*([A-Za-z_]\w*)', 'tokens', 'once');
    if isempty(token)
        token = '';
    else
        token = token{1};
    end
end

function [text, next] = local_native_line(txt, i)
% The native statement starting at i: its line, and the following lines while the line
% ends with '...'. next is the position after the newline that ends it.
    n = length(txt);
    stop = i;
    while true
        j = stop;
        while j <= n && txt(j) ~= newline
            j = j + 1;
        end
        line = txt(stop:j-1);
        stop = j + 1;
        if stop > n || ~endsWith(strtrim(line), '...')
            break
        end
    end
    text = txt(i:min(j-1, n));
    next = min(stop, n + 1);
end

function c = local_chunk(txt, first, filename, linum)
% The Dynare statement starting at first, up to the next ';' outside quotes, TeX names,
% parentheses and brackets. Empty when no such ';' exists.
    n = length(txt);
    state = 'normal';
    depth = 0;
    for i = first:n
        ch = txt(i);
        if ch == newline && strcmp(state, 'quote')
            error('modfile:split_statements:unterminatedString', '%s: quoted value opened at line %u is not closed before the end of the line.', filename, linum(opened))
        end
        switch state
          case 'normal'
            switch ch
              case ''''
                state = 'quote';
                opened = i;
              case '$'
                state = 'tex';
              case {'(', '['}
                depth = depth + 1;
              case {')', ']'}
                depth = max(depth-1, 0);
              case ';'
                if depth == 0
                    c = struct('text', txt(first:i-1), 'first', first, 'last', i);
                    return
                end
            end
          case 'quote'
            if ch == ''''
                state = 'normal';
            end
          case 'tex'
            if ch == '$'
                state = 'normal';
            end
        end
    end
    c = [];
end
