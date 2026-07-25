function [keyword, options, rest] = parse_head(chunk)
% Split a .mod statement into its leading keyword, its option group and the remainder.
%
% INPUTS:
% - chunk     [char]   1×n array, one ';'-terminated statement, without the ';'
%
% OUTPUTS:
% - keyword   [char]   1×p array, the leading identifier, empty when the chunk does
%                      not start with one
% - options   [char]   1×q array, the text inside the parenthesis group that follows
%                      the keyword immediately, empty when there is none
% - rest      [char]   1×r array, everything after the keyword and its option group, with
%                      the blanks that separate it from the keyword left in place
%
% EXAMPLES:
% [k, o, r] = modfile.parse_head('model(linear, bytecode)')   % 'model', 'linear, bytecode', ''
% [k, o, r] = modfile.parse_head('var a b c')                 % 'var', '', 'a b c'
% [k, o, r] = modfile.parse_head('alpha = 0.36')              % 'alpha', '', '= 0.36'
%
% REMARKS:
% - The option group is only recognised when the '(' follows the keyword with nothing
%   but blanks in between. That distinguishes the declaration 'var(log) x' from an
%   assignment such as 'beta = 1/(1+r)', whose parenthesis belongs to the expression.
% - Nested parentheses inside the option group are matched, so
%   'var(deflator = exp(a))' yields the whole 'deflator = exp(a)'.
    arguments
        chunk (1,:) char
    end

    keyword = '';
    options = '';
    rest    = '';

    s = strtrim(chunk);
    if isempty(s)
        return
    end

    tok = regexp(s, '^[A-Za-z_]\w*', 'match', 'once');
    if isempty(tok)
        rest = s;
        return
    end
    keyword = tok;

    raw = s(length(tok)+1:end);
    lead = find(~isspace(raw), 1);
    if isempty(lead)
        return
    end
    tail = raw(lead:end);

    if tail(1) == '('
        stop = local_match_paren(tail);
        if isempty(stop)
            % Unbalanced here means the '(' belongs to something the caller will
            % report on; hand the text back untouched rather than guessing.
            rest = tail;
            return
        end
        options = strtrim(tail(2:stop-1));
        rest    = deblank(tail(stop+1:end));
    else
        % The blanks between the keyword and what follows are kept, so that a caller
        % counting newlines to place each symbol on its source line stays in step. A
        % declaration list may span a macro loop, and those lines are what tie its
        % symbols back to it.
        rest = deblank(raw);
    end
end

function stop = local_match_paren(s)
% Index of the ')' matching the '(' at s(1), or empty when there is none.
    depth = 0;
    state = 'normal';
    for i = 1:length(s)
        c = s(i);
        switch state
          case 'normal'
            switch c
              case ''''
                state = 'quote';
              case '$'
                state = 'tex';
              case '('
                depth = depth + 1;
              case ')'
                depth = depth - 1;
                if depth == 0
                    stop = i;
                    return
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
    stop = [];
end
