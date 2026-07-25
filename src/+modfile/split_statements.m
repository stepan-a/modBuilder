function stmts = split_statements(txt, filename)
% Split a comment-free .mod file into top-level statements and blocks.
%
% INPUTS:
% - txt        [char]     1×n array, content of a .mod file, already passed through
%                         modfile.strip_comments
% - filename   [char]     1×m array, name used in error messages (default '<string>')
%
% OUTPUTS:
% - stmts      [struct]   k×1 array, one entry per top-level statement or block:
%                           .kind      [char]  'statement' or 'block'
%                           .keyword   [char]  leading identifier, e.g. 'var', 'model'
%                           .options   [char]  text inside the option group that
%                                              immediately follows the keyword, e.g.
%                                              'linear, bytecode' for model(linear, bytecode);
%                                              empty when there is none
%                           .rest      [char]  for a statement, everything after the
%                                              keyword and its option group
%                           .body      [char]  for a block, the raw text between the
%                                              opening ';' and the matching 'end'
%                           .line      [double] 1-based line where the statement starts
%
% REMARKS:
% - Splitting happens at every ';' that sits outside quotes, TeX names, parentheses
%   and brackets. The bracket test matters inside the model block, where the equation
%   tag group [name = 'x', mcp = 'y > 0'] must not be cut.
% - Blocks are recognised by their keyword and closed by a chunk that is exactly 'end'.
%   Their body is returned uncut, because each block has its own sub-scanner: the
%   model block, for instance, keeps equations verbatim.
% - A 'verbatim' block holds arbitrary MATLAB code whose own 'end' keywords are not
%   always followed by ';'. Such a block terminates at the first ';'-terminated 'end',
%   which is what Dynare's lexer does as well; the statement is warned about and
%   skipped anyway, so the imprecision does not reach the model.
% - Anything after the last ';' that is not blank raises
%   modfile:split_statements:trailingText, and an unclosed block raises
%   modfile:split_statements:unterminatedBlock.
    arguments
        txt      (1,:) char
        filename (1,:) char = '<string>'
    end

    BLOCK_KEYWORDS = modfile.block_keywords();

    n = length(txt);
    % Line of every character, so a chunk's start offset maps straight to a line.
    linum = cumsum(txt == newline) + 1;

    % First pass: cut at the top-level semicolons.
    chunks = struct('text', {}, 'first', {}, 'last', {}, 'line', {});
    state = 'normal';
    depth = 0;
    first = 1;
    for i = 1:n
        c = txt(i);
        switch state
          case 'normal'
            switch c
              case ''''
                state = 'quote';
              case '$'
                state = 'tex';
              case {'(', '['}
                depth = depth + 1;
              case {')', ']'}
                depth = max(depth-1, 0);
              case ';'
                if depth == 0
                    chunks(end+1) = local_chunk(txt, first, i, linum); %#ok<AGROW>
                    first = i + 1;
                end
            end
          case 'quote'
            if c == ''''
                state = 'normal';
            end
          case 'tex'
            if c == '$'
                state = 'normal';
            end
        end
    end

    if first <= n && ~isempty(strtrim(txt(first:n)))
        error('modfile:split_statements:trailingText', '%s: text after the last '';'' at line %u: "%s".', filename, linum(first), strtrim(txt(first:n)))
    end

    % Second pass: fold the chunks that open a block, together with everything up to
    % their matching 'end', into a single entry.
    stmts = struct('kind', {}, 'keyword', {}, 'options', {}, 'rest', {}, 'body', {}, 'line', {});
    k = 1;
    while k <= numel(chunks)
        [keyword, options, rest] = modfile.parse_head(chunks(k).text);
        if ismember(lower(keyword), BLOCK_KEYWORDS)
            j = k + 1;
            depth = 1;
            while j <= numel(chunks)
                [inner, ~, innerrest] = modfile.parse_head(chunks(j).text);
                if strcmp(lower(inner), 'end') && isempty(strtrim(innerrest))
                    depth = depth - 1;
                    if depth == 0
                        break
                    end
                elseif ismember(lower(inner), BLOCK_KEYWORDS)
                    depth = depth + 1;
                end
                j = j + 1;
            end
            if j > numel(chunks)
                error('modfile:split_statements:unterminatedBlock', '%s: block "%s" opened at line %u is never closed by "end;".', filename, keyword, chunks(k).line)
            end
            stmts(end+1) = struct('kind', 'block', 'keyword', keyword, 'options', options, 'rest', rest, 'body', txt(chunks(k).last+1:chunks(j).first-1), 'line', chunks(k).line); %#ok<AGROW>
            k = j + 1;
        else
            if ~isempty(keyword) || ~isempty(strtrim(rest))
                stmts(end+1) = struct('kind', 'statement', 'keyword', keyword, 'options', options, 'rest', rest, 'body', '', 'line', chunks(k).line); %#ok<AGROW>
            end
            k = k + 1;
        end
    end
end

function c = local_chunk(txt, first, last, linum)
% Package the characters of one ';'-terminated chunk together with its position.
%
% The reported line is that of the first non-blank character, so a statement preceded
% by blank lines is not attributed to the blank run above it.
    body = txt(first:last-1);
    offset = find(~isspace(body), 1);
    if isempty(offset)
        offset = 1;
    end
    c = struct('text', body, 'first', first, 'last', last, 'line', linum(min(first+offset-1, numel(linum))));
end
