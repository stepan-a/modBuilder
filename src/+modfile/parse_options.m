function opts = parse_options(text)
% Turn the option group of a Dynare command into the cell array write() expects.
%
% INPUTS:
% - text   [char]   1×n array, the text inside the parentheses, e.g. 'maxit=100, nocheck'
%
% OUTPUTS:
% - opts   [cell]   1×m array of key/value pairs and standalone flags, e.g.
%                   {'maxit', 100, 'nocheck'}
%
% EXAMPLES:
% modfile.parse_options('maxit=100, nocheck')   % {'maxit', 100, 'nocheck'}
%
% REMARKS:
% - This is the inverse of the private modBuilder.format_dynare_options, so that the
%   steady command of a file read back in is written out unchanged.
% - A value that parses as a number is stored as a double, otherwise as text. That
%   matches format_dynare_options, which renders both without quotes.
    arguments
        text (1,:) char
    end

    opts = {};
    if isempty(strtrim(text))
        return
    end

    entries = strtrim(strsplit(text, ','));
    for i = 1:numel(entries)
        entry = entries{i};
        if isempty(entry)
            continue
        end
        pos = find(entry == '=', 1);
        if isempty(pos)
            opts{end+1} = entry; %#ok<AGROW>
        else
            name  = strtrim(entry(1:pos-1));
            value = strtrim(entry(pos+1:end));
            number = str2double(value);
            if ~isnan(number)
                opts{end+1} = name; %#ok<AGROW>
                opts{end+1} = number; %#ok<AGROW>
            else
                opts{end+1} = name; %#ok<AGROW>
                opts{end+1} = value; %#ok<AGROW>
            end
        end
    end
end
