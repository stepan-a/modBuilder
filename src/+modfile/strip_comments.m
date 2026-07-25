function txt = strip_comments(txt, filename)
% Blank out the comments of a .mod file, preserving every line and column position.
%
% INPUTS:
% - txt        [char]   1×n array, the raw content of a .mod file
% - filename   [char]   1×m array, name used in error messages (default '<string>')
%
% OUTPUTS:
% - txt        [char]   1×n array, same length as the input, with comment characters
%                       replaced by spaces
%
% REMARKS:
% - Comments are replaced by spaces rather than removed so that the offsets of
%   everything else are unchanged: line and column numbers reported by the later
%   parsing stages then refer to positions in the original file.
% - Dynare accepts three comment forms: '%' and '//' to the end of the line, and
%   '/* ... */' spanning lines. Block comments do not nest, as in Dynare.
% - The scan is a state machine rather than a regular expression because two .mod
%   constructs contain characters that would otherwise be read as comment markers:
%     * quoted attribute values, e.g. (long_name='Output share (%)'),
%     * TeX names delimited by '$', e.g. $\delta'$ and $S'$ in examples/sw/sw.mod,
%       which contain an apostrophe. Tracking only quotes, and not TeX names, makes
%       that apostrophe open a string and corrupts the remainder of the file.
% - A TeX name may not span lines: an unterminated '$' raises
%   modfile:strip_comments:unterminatedTexName rather than silently swallowing the
%   rest of the file. Unterminated quotes and block comments raise likewise.
    arguments
        txt      (1,:) char
        filename (1,:) char = '<string>'
    end

    n = length(txt);
    i = 1;
    line = 1;
    % State of the scanner: 'normal', 'quote' (inside '...'), 'tex' (inside $...$)
    % or 'block' (inside a /* ... */ comment).
    state = 'normal';
    opened = 1;

    while i <= n
        c = txt(i);

        if c == newline
            line = line + 1;
            if strcmp(state, 'tex')
                error('modfile:strip_comments:unterminatedTexName', '%s: TeX name opened at line %u is not closed before the end of the line.', filename, opened)
            end
            if strcmp(state, 'quote')
                error('modfile:strip_comments:unterminatedString', '%s: quoted value opened at line %u is not closed before the end of the line.', filename, opened)
            end
            i = i + 1;
            continue
        end

        switch state
          case 'normal'
            if c == ''''
                state = 'quote';
                opened = line;
                i = i + 1;
            elseif c == '$'
                state = 'tex';
                opened = line;
                i = i + 1;
            elseif c == '%' || (c == '/' && i < n && txt(i+1) == '/')
                % Line comment: blank out to the end of the line, leaving the
                % newline itself in place.
                j = i;
                while j <= n && txt(j) ~= newline
                    txt(j) = ' ';
                    j = j + 1;
                end
                i = j;
            elseif c == '/' && i < n && txt(i+1) == '*'
                state = 'block';
                opened = line;
                txt(i:i+1) = '  ';
                i = i + 2;
            else
                i = i + 1;
            end

          case 'quote'
            if c == ''''
                state = 'normal';
            end
            i = i + 1;

          case 'tex'
            if c == '$'
                state = 'normal';
            end
            i = i + 1;

          case 'block'
            if c == '*' && i < n && txt(i+1) == '/'
                txt(i:i+1) = '  ';
                state = 'normal';
                i = i + 2;
            else
                txt(i) = ' ';
                i = i + 1;
            end
        end
    end

    switch state
      case 'block'
        error('modfile:strip_comments:unterminatedComment', '%s: block comment opened at line %u is not closed.', filename, opened)
      case 'tex'
        error('modfile:strip_comments:unterminatedTexName', '%s: TeX name opened at line %u is not closed.', filename, opened)
      case 'quote'
        error('modfile:strip_comments:unterminatedString', '%s: quoted value opened at line %u is not closed.', filename, opened)
    end
end
