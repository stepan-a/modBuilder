function chunks = split_semicolons(body, line0)
% Cut a block body at every ';' that sits outside quotes, TeX names, parentheses and brackets.
%
% INPUTS:
% - body     [char]     1×n array, the raw text of a block, comments already blanked
% - line0    [double]   scalar, line at which body starts in the file (default 1)
%
% OUTPUTS:
% - chunks   [struct]   k×1 array, one entry per non-blank chunk:
%                         .text  [char]     the chunk, without its ';'
%                         .line  [double]   1-based line of its first non-blank character
%
% REMARKS:
% - The bracket test matters inside the model block, where an equation tag group such
%   as [name = 'y', mcp = 'c > 0'] must not be cut at a ';' it could contain.
% - Blank chunks are dropped, so a trailing ';' or a run of blank lines produces
%   nothing rather than an empty statement.
% - Non-blank text after the last ';' is returned as a final chunk. In a well-formed
%   block there is none; when there is, it is a tag group with no equation under it or a
%   statement missing its terminator, and the caller reports it.
    arguments
        body  (1,:) char
        line0 (1,1) double = 1
    end

    n = length(body);
    linum = cumsum(body == newline) + line0;
    chunks = struct('text', {}, 'line', {});
    state = 'normal';
    depth = 0;
    first = 1;

    for i = 1:n
        c = body(i);
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
                    piece  = body(first:i-1);
                    offset = find(~isspace(piece), 1);
                    if ~isempty(offset)
                        chunks(end+1) = struct('text', piece, 'line', linum(first+offset-1)); %#ok<AGROW>
                    end
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

    % Anything left after the last ';' is emitted as a final chunk rather than dropped:
    % a tag group with no equation under it, or a statement missing its terminator, must
    % reach the caller so it can be reported instead of silently vanishing.
    if first <= n
        piece  = body(first:n);
        offset = find(~isspace(piece), 1);
        if ~isempty(offset)
            chunks(end+1) = struct('text', piece, 'line', linum(first+offset-1));
        end
    end
end
