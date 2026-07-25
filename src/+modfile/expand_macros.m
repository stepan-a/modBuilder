function [text, info] = expand_macros(text, filename, options)
% Run the Dynare macro directives of a .mod file.
%
% INPUTS:
% - text        [char]      1×n array, the content of a .mod file, comments not yet stripped
% - filename    [char]      1×m array, name used in error messages and include resolution
%
% OPTIONAL NAME-VALUE ARGUMENTS:
% - Defines       [struct]  macro variables to seed the environment with, the equivalent
%                           of Dynare's -D command-line switch (default none)
% - IncludePaths  [cell]    directories searched by @#include (default none)
% - Force         [double]  k×2 [line branch], forcing the conditional opening at that
%                           line onto that branch whatever its condition evaluates to.
%                           This is how the reader reaches the branches a plain expansion
%                           never produces, so that the whole logic of the file, and not
%                           only the path taken today, reaches the generated script.
%
% OUTPUTS:
% - text        [char]      the file with every directive resolved
% - info        [struct]    what the directives were:
%                             .defines   [cell]    k×2, {name, MATLAB source} for the
%                                                  @#define variables that render, in order
%                             .used      [logical] scalar, the file contained directives
%                             .context   [cell]    1×L, one entry per output line: the
%                                                  stack of directive frames that line
%                                                  came from, outermost first
%                             .conditionals [struct] one entry per @#if construct, taken
%                                                  or not: .id (its source line),
%                                                  .nbranches, .conds (the MATLAB source
%                                                  of each branch's condition, '' for an
%                                                  @#else), .taken (the branch selected,
%                                                  0 when none was), .position (how many
%                                                  output lines preceded it) and
%                                                  .ancestors (the [line branch] the
%                                                  enclosing conditionals were on)
%
% REMARKS:
% - Macro values are compile-time constants, so the expansion is a plain text pass, as in
%   Dynare. What modfile.translate needs in order to emit MATLAB control flow rather than
%   flat text is reported alongside, as the provenance of each output line.
% - A frame is a struct with fields kind ('if' or 'for'), id (the source line of the
%   directive, which identifies the construct), iter (the branch or the iteration), cond
%   (the MATLAB source of the condition, for 'if'), exclusive (for 'if', true when the
%   construct has a single branch, so that emitting it as a MATLAB if loses nothing) and
%   values (for 'for', the values bound to the indices in this iteration).
% - Only the iterations a @#for actually ran are recorded, so a 'when' guard simply shows
%   up as a shorter list of values rather than as a special case.
% - Directives inside a branch that is not taken are tracked for nesting but their
%   expressions are not evaluated: such a branch may legitimately mention variables that
%   only the other branch defines.
    arguments
        text                  (1,:) char
        filename              (1,:) char = '<string>'
        options.Defines       struct = struct()
        options.IncludePaths  (1,:) cell = {}
        options.Force         double = zeros(0, 2)
    end

    info = struct('defines', {cell(0,2)}, 'used', false, 'context', {{}}, ...
                  'conditionals', {struct('id', {}, 'nbranches', {}, 'conds', {}, 'taken', {}, 'position', {}, 'ancestors', {})});

    if ~contains(text, '@#') && ~contains(text, '@{')
        info.context = repmat({modfile.macro_frame()}, 1, numel(strsplit(text, newline, 'CollapseDelimiters', false)));
        return
    end
    info.used = true;

    env = macro.environment(options.Defines);

    % The values seeded from outside are emitted as locals too. Without them a file that
    % guards its default with @#ifndef would leave the script referring to a variable it
    % never assigns, since the @#define is then skipped.
    seeded = fieldnames(options.Defines);
    for i = 1:numel(seeded)
        source = local_literal(macro.fromnative(options.Defines.(seeded{i})));
        if ~isempty(source)
            info.defines(end+1, :) = {seeded{i}, source};
        end
    end
    state = struct('filename', filename, 'includepaths', {options.IncludePaths}, 'stack', {{filename}}, 'ctx', {modfile.macro_frame()}, 'force', options.Force);

    lines = local_lines(text);
    [out, env, info] = local_run(lines, env, info, state);
    text = strjoin({out.text}, newline);
    info.context = {out.ctx};
end

function lines = local_lines(text)
% Split into lines, keeping their number, and carrying the source line of each.
    raw = strsplit(text, newline, 'CollapseDelimiters', false);
    lines = struct('text', raw(:)', 'line', num2cell(1:numel(raw)));
end

function [out, env, info] = local_run(lines, env, info, state)
% Scan a run of lines, resolving every directive it contains.
%
% Conditionals are handled with an explicit stack of frames rather than by recursion over
% a parsed directive tree, which keeps the whole scanner in one place and makes skipping
% an inactive branch cheap.
    out = struct('text', {}, 'ctx', {});
    frames = struct('taken', {}, 'active', {}, 'line', {}, 'branch', {}, 'nbranches', {}, 'cond', {}, 'conds', {}, 'takenbranch', {}, 'position', {}, 'ancestors', {}, 'reached', {}, 'forced', {});
    i = 1;

    while i <= numel(lines)
        line = lines(i);
        directive = regexp(line.text, '^\s*@#\s*(\w+)\s*(.*)$', 'tokens', 'once');

        if isempty(directive)
            if local_active(frames)
                out(end+1) = struct('text', local_substitute(line.text, env, state.filename, line.line), 'ctx', {local_context(state, frames)}); %#ok<AGROW>
            end
            i = i + 1;
            continue
        end

        keyword = directive{1};
        rest = strtrim(directive{2});

        switch keyword
          case {'if', 'ifdef', 'ifndef'}
            forced = local_forced(state.force, line.line);
            outer = local_active(frames);
            if ~isempty(forced)
                taken = forced == 1;
            elseif outer
                taken = local_condition(keyword, rest, env, state.filename, line.line);
            else
                taken = false;
            end
            frames(end+1) = struct('taken', taken, 'active', taken && outer, 'line', line.line, ...
                                   'branch', 1, 'nbranches', local_count_branches(lines, i), ...
                                   'cond', local_condition_source(keyword, rest, env), ...
                                   'conds', {{local_condition_source(keyword, rest, env)}}, ...
                                   'takenbranch', local_ternary(taken, 1, 0), ...
                                   'position', numel(out), ...
                                   'ancestors', {local_selection(frames)}, ...
                                   'reached', outer, ...
                                   'forced', local_ternary(isempty(forced), 0, forced)); %#ok<AGROW>
            i = i + 1;

          case 'elseif'
            local_require_frame(frames, keyword, state.filename, line.line);
            outer = local_active(frames(1:end-1));
            frames(end).branch = frames(end).branch + 1;
            frames(end).cond = local_condition_source('if', rest, env);
            frames(end).conds{end+1} = frames(end).cond;
            if frames(end).forced > 0
                taken = frames(end).forced == frames(end).branch;
                frames(end).active = taken && outer;
                if taken
                    frames(end).takenbranch = frames(end).branch;
                end
                frames(end).taken = frames(end).taken || taken;
            elseif frames(end).taken || ~outer
                frames(end).active = false;
            else
                taken = local_condition('if', rest, env, state.filename, line.line);
                frames(end).taken = taken;
                frames(end).active = taken;
                if taken
                    frames(end).takenbranch = frames(end).branch;
                end
            end
            i = i + 1;

          case 'else'
            local_require_frame(frames, keyword, state.filename, line.line);
            outer = local_active(frames(1:end-1));
            frames(end).branch = frames(end).branch + 1;
            frames(end).cond = '';
            frames(end).conds{end+1} = '';
            if frames(end).forced > 0
                frames(end).active = (frames(end).forced == frames(end).branch) && outer;
                if frames(end).forced == frames(end).branch
                    frames(end).takenbranch = frames(end).branch;
                end
            else
                frames(end).active = ~frames(end).taken && outer;
                if ~frames(end).taken
                    frames(end).takenbranch = frames(end).branch;
                end
            end
            frames(end).taken = true;
            i = i + 1;

          case 'endif'
            local_require_frame(frames, keyword, state.filename, line.line);
            % A conditional is recorded whether or not it produced anything, so that the
            % reader can go back and expand the branches it did not take. It is recorded
            % only if it was REACHED, though: one sitting inside a branch that was not
            % taken is not a construct of this reading at all. Treating it as one would
            % emit its calls a second time, next to the branch that already carries them.
            if frames(end).reached
                info.conditionals(end+1) = struct('id', frames(end).line, ...
                                                  'nbranches', frames(end).nbranches, ...
                                                  'conds', {frames(end).conds}, ...
                                                  'taken', frames(end).takenbranch, ...
                                                  'position', frames(end).position, ...
                                                  'ancestors', {frames(end).ancestors});
            end
            frames(end) = [];
            i = i + 1;

          case 'define'
            if local_active(frames)
                [env, info] = local_define(rest, env, info, state.filename, line.line);
            end
            i = i + 1;

          case 'for'
            [body, next] = local_body(lines, i, 'for', 'endfor', state.filename);
            if local_active(frames)
                inner = state;
                inner.ctx = local_context(state, frames);
                [chunk, env, info] = local_for(rest, body, env, info, inner, lines(i).line);
                out = [out, chunk]; %#ok<AGROW>
            end
            i = next;

          case 'endfor'
            error('modfile:expand_macros:unexpectedDirective', '%s (line %u): @#endfor without a matching @#for.', state.filename, line.line)

          case {'include', 'includepath'}
            if local_active(frames)
                inner = state;
                inner.ctx = local_context(state, frames);
                [chunk, env, info, state] = local_include(keyword, rest, env, info, inner, state, line.line);
                out = [out, chunk]; %#ok<AGROW>
            end
            i = i + 1;

          case 'echo'
            if local_active(frames)
                fprintf('%s\n', macro.tostring(macro(rest).eval(env)));
            end
            i = i + 1;

          case 'error'
            if local_active(frames)
                error('modfile:expand_macros:userError', '%s (line %u): %s', state.filename, line.line, macro.tostring(macro(rest).eval(env)))
            end
            i = i + 1;

          case 'echomacrovars'
            modfile.warn('modfile:expand_macros:ignoredDirective', '%s (line %u): @#echomacrovars is a debugging aid and produces no output here.', state.filename, line.line);
            i = i + 1;

          case 'line'
            % Only produced by Dynare's savemacro output; provenance is tracked separately.
            i = i + 1;

          otherwise
            error('modfile:expand_macros:unsupportedDirective', '%s (line %u): "@#%s" is not supported.', state.filename, line.line, keyword)
        end
    end

    if ~isempty(frames)
        error('modfile:expand_macros:unterminatedDirective', '%s: the conditional opened at line %u is never closed by @#endif.', state.filename, frames(end).line)
    end
end

function tf = local_active(frames)
% True when every enclosing conditional frame is on the branch being taken.
    tf = all([frames.active]);
end

function branch = local_forced(force, id)
% The branch a caller asked for on the conditional at this line, empty when it is free.
    branch = [];
    if isempty(force)
        return
    end
    row = find(force(:,1) == id, 1);
    if ~isempty(row)
        branch = force(row, 2);
    end
end

function selection = local_selection(frames)
% The branch each enclosing conditional is on, as the k×2 [line branch] a Force takes.
    selection = zeros(0, 2);
    for i = 1:numel(frames)
        selection(end+1, :) = [frames(i).line, frames(i).branch]; %#ok<AGROW>
    end
end

function v = local_ternary(condition, yes, no)
% Pick between two values, keeping the frame construction to one expression.
    if condition
        v = yes;
    else
        v = no;
    end
end

function ctx = local_context(state, frames)
% Provenance of a line: the enclosing loops and includes, then the open conditionals.
    ctx = state.ctx;
    for i = 1:numel(frames)
        ctx(end+1) = modfile.macro_frame('if', frames(i).line, frames(i).branch, frames(i).cond, frames(i).nbranches == 1); %#ok<AGROW>
    end
end

function n = local_count_branches(lines, i)
% Number of branches of the conditional opening at line i, counting the @#if itself.
%
% Known before the branches are scanned, because a conditional with a single branch can
% be emitted as a MATLAB if without losing anything, while one with an @#else cannot: the
% branch that is not taken never reaches the expanded text.
    n = 1;
    depth = 1;
    j = i + 1;
    while j <= numel(lines)
        token = regexp(lines(j).text, '^\s*@#\s*(\w+)', 'tokens', 'once');
        if ~isempty(token)
            switch token{1}
              case {'if', 'ifdef', 'ifndef'}
                depth = depth + 1;
              case {'elseif', 'else'}
                if depth == 1
                    n = n + 1;
                end
              case 'endif'
                depth = depth - 1;
                if depth == 0
                    return
                end
            end
        end
        j = j + 1;
    end
end

function src = local_condition_source(keyword, rest, env)
% MATLAB source of a condition, empty when it has no faithful rendering.
    switch keyword
      case 'ifdef'
        src = sprintf('exist(''%s'', ''var'')', strtrim(rest));
      case 'ifndef'
        src = sprintf('~exist(''%s'', ''var'')', strtrim(rest));
      otherwise
        try
            [src, ok] = macro(rest).to_matlab(env);
        catch
            ok = false;
        end
        if ~ok
            src = '';
        end
    end
end

function local_require_frame(frames, keyword, filename, line)
% Reject an else/elseif/endif with no conditional open.
    if isempty(frames)
        error('modfile:expand_macros:unexpectedDirective', '%s (line %u): @#%s without a matching @#if.', filename, line, keyword)
    end
end

function taken = local_condition(keyword, rest, env, filename, line)
% Evaluate the condition of an if, ifdef or ifndef.
    try
        switch keyword
          case 'ifdef'
            taken = isKey(env.vars, string(strtrim(rest)));
          case 'ifndef'
            taken = ~isKey(env.vars, string(strtrim(rest)));
          otherwise
            taken = macro.truth(macro(rest).eval(env));
        end
    catch err
        error('modfile:expand_macros:badCondition', '%s (line %u): cannot evaluate the condition "%s": %s', filename, line, rest, err.message)
    end
end

function [env, info] = local_define(rest, env, info, filename, line)
% Handle @#define, in its variable and function forms.
    token = regexp(rest, '^([A-Za-z_]\w*)\s*\(([^)]*)\)\s*=\s*(.*)$', 'tokens', 'once');
    if ~isempty(token)
        args = strtrim(strsplit(token{2}, ','));
        env.funcs(string(token{1})) = struct('args', {args(~cellfun(@isempty, args))}, 'body', macro(token{3}));
        return
    end

    token = regexp(rest, '^([A-Za-z_]\w*)\s*=\s*(.*)$', 'tokens', 'once');
    if isempty(token)
        name = strtrim(rest);
        if isempty(regexp(name, '^[A-Za-z_]\w*$', 'once'))
            error('modfile:expand_macros:badDefine', '%s (line %u): cannot read the @#define "%s".', filename, line, rest)
        end
        env.vars(string(name)) = macro.mkbool(true);
        info.defines(end+1, :) = {name, 'true'};
        return
    end

    name = token{1};
    tree = macro(token{2});
    try
        value = tree.eval(env);
    catch err
        error('modfile:expand_macros:badDefine', '%s (line %u): cannot evaluate "%s": %s', filename, line, rest, err.message)
    end

    % Render the definition for the generated script. When the expression has no faithful
    % MATLAB form, fall back to the value it evaluated to, which is always renderable.
    [source, ok] = tree.to_matlab(env);
    if ~ok
        source = local_literal(value);
    end

    env.vars(string(name)) = value;
    if ~isempty(source)
        info.defines(end+1, :) = {name, source};
    end
end

function str = local_literal(v)
% Render a macro value as a MATLAB literal, or empty when it has no counterpart.
    switch v.kind
      case 'real'
        str = macro.tostring(v);
      case 'bool'
        str = macro.tostring(v);
      case 'string'
        str = sprintf('''%s''', strrep(v.data, '''', ''''''));
      case {'array', 'tuple'}
        % Both go through the class that carries their kind, so that a script can still
        % tell an array from a tuple and either from a scalar.
        parts = cellfun(@local_literal, v.data, 'UniformOutput', false);
        if any(cellfun(@isempty, parts))
            str = '';
        elseif strcmp(v.kind, 'tuple')
            str = sprintf('macrotuple(%s)', strjoin(parts, ', '));
        else
            str = sprintf('macroarray(%s)', strjoin(parts, ', '));
        end
      otherwise
        str = '';
    end
end

function [body, next] = local_body(lines, i, opening, closing, filename)
% Collect the lines of a block directive, up to its matching closing directive.
    depth = 1;
    j = i + 1;
    while j <= numel(lines)
        token = regexp(lines(j).text, '^\s*@#\s*(\w+)', 'tokens', 'once');
        if ~isempty(token)
            switch token{1}
              case opening
                depth = depth + 1;
              case closing
                depth = depth - 1;
                if depth == 0
                    body = lines(i+1:j-1);
                    next = j + 1;
                    return
                end
            end
        end
        j = j + 1;
    end
    error('modfile:expand_macros:unterminatedDirective', '%s: the @#%s opened at line %u is never closed by @#%s.', filename, opening, lines(i).line, closing)
end

function [out, env, info] = local_for(header, body, env, info, state, line)
% Run a @#for, recording it as an implicit loop when its body allows it.
    token = regexp(header, '^(.*?)\s+in\s+(.*)$', 'tokens', 'once');
    if isempty(token)
        error('modfile:expand_macros:badLoop', '%s (line %u): cannot read the @#for header "%s".', state.filename, line, header)
    end

    [indexnames, guard, setexpr] = local_loop_header(token, state.filename, line);

    try
        values = macro(setexpr).eval(env);
    catch err
        error('modfile:expand_macros:badLoop', '%s (line %u): cannot evaluate the index set "%s": %s', state.filename, line, setexpr, err.message)
    end
    if ~strcmp(values.kind, 'array')
        error('modfile:expand_macros:badLoop', '%s (line %u): the index set of a @#for must be an array, not a %s.', state.filename, line, values.kind)
    end

    % The loop is expanded here, since the expansion is what the rest of the reader
    % consumes. Each iteration tags its lines with the values it bound, and only the
    % iterations that actually ran are recorded: a 'when' guard then shows up as a shorter
    % list of values rather than as a case of its own.
    out = struct('text', {}, 'ctx', {});
    iteration = 0;
    for k = 1:numel(values.data)
        env = local_bind(env, indexnames, values.data{k}, state.filename, line);
        if ~isempty(guard) && ~macro.truth(macro(guard).eval(env))
            continue
        end
        iteration = iteration + 1;
        inner = state;
        inner.ctx(end+1) = modfile.macro_frame('for', line, iteration, '', false, local_bound(indexnames, values.data{k}), indexnames);
        [chunk, env, info] = local_run(body, env, info, inner);
        out = [out, chunk]; %#ok<AGROW>
    end
end

function bound = local_bound(indexnames, value)
% The values bound to the loop indices in one iteration, as MATLAB natives.
    if isscalar(indexnames)
        components = {value};
    else
        components = value.data;
    end
    bound = cell(1, numel(components));
    for i = 1:numel(components)
        switch components{i}.kind
          case 'string'
            bound{i} = components{i}.data;
          case 'real'
            bound{i} = components{i}.data;
          otherwise
            % A value that cannot name a symbol; the translator will not template on it.
            bound{i} = [];
        end
    end
end

function [indexnames, guard, setexpr] = local_loop_header(token, filename, line)
% Split a @#for header into its index names, its index set and its optional when-guard.
    lhs = strtrim(token{1});
    rhs = strtrim(token{2});

    guard = '';
    position = regexp(rhs, '\s+when\s+', 'once');
    if ~isempty(position)
        parts = regexp(rhs, '\s+when\s+', 'split', 'once');
        rhs = strtrim(parts{1});
        guard = strtrim(parts{2});
    end
    setexpr = rhs;

    if lhs(1) == '(' && lhs(end) == ')'
        indexnames = strtrim(strsplit(lhs(2:end-1), ','));
    else
        indexnames = {lhs};
    end
    for i = 1:numel(indexnames)
        if isempty(regexp(indexnames{i}, '^[A-Za-z_]\w*$', 'once'))
            error('modfile:expand_macros:badLoop', '%s (line %u): "%s" is not a valid loop index.', filename, line, indexnames{i})
        end
    end
end

function env = local_bind(env, indexnames, value, filename, line)
% Bind the loop indices for one iteration, destructuring a tuple when there are several.
%
% Dynare binds in the current environment, with no scope pushed, and the index keeps its
% last value after @#endfor. This matches that.
    if isscalar(indexnames)
        env.vars(string(indexnames{1})) = value;
        return
    end
    if ~strcmp(value.kind, 'tuple') || numel(value.data) ~= numel(indexnames)
        error('modfile:expand_macros:badLoop', '%s (line %u): the loop expects tuples of %u element(s).', filename, line, numel(indexnames))
    end
    for i = 1:numel(indexnames)
        env.vars(string(indexnames{i})) = value.data{i};
    end
end

function [chunk, env, info, state] = local_include(keyword, rest, env, info, inner, state, line)
% Handle @#include and @#includepath.
%
% inner carries the provenance the included lines inherit; state is threaded back so that
% an @#includepath extends the search list of everything that follows.
    try
        target = macro.tostring(macro(rest).eval(env));
    catch err
        error('modfile:expand_macros:badInclude', '%s (line %u): cannot evaluate "%s": %s', state.filename, line, rest, err.message)
    end

    if strcmp(keyword, 'includepath')
        state.includepaths{end+1} = target;
        chunk = struct('text', {}, 'ctx', {});
        return
    end

    path = modfile.resolve_include(target, state.filename, state.includepaths);
    if ismember(path, state.stack)
        error('modfile:expand_macros:circularInclude', '%s (line %u): "%s" is already being included.', state.filename, line, path)
    end
    if numel(state.stack) > 32
        error('modfile:expand_macros:includeTooDeep', '%s (line %u): includes are nested more than 32 deep.', state.filename, line)
    end

    inner = state;
    inner.filename = path;
    inner.stack = [state.stack, {path}];

    lines = local_lines(fileread(path));
    [chunk, env, info] = local_run(lines, env, info, inner);
end

function out = local_substitute(text, env, filename, line)
% Replace every @{...} in a text line by the value of the expression it holds.
    out = '';
    i = 1;
    n = length(text);
    while i <= n
        start = strfind(text(i:end), '@{');
        if isempty(start)
            out = [out text(i:end)];
            return
        end
        start = i + start(1) - 1;
        stop = local_match_brace(text, start+1);
        if isempty(stop)
            error('modfile:expand_macros:unterminatedEval', '%s (line %u): "@{" is not closed.', filename, line)
        end
        expression = text(start+2:stop-1);
        try
            value = macro(expression).eval(env);
        catch err
            error('modfile:expand_macros:badEval', '%s (line %u): cannot evaluate "@{%s}": %s', filename, line, expression, err.message)
        end
        out = [out text(i:start-1) macro.tostring(value)];
        i = stop + 1;
    end
end

function stop = local_match_brace(text, start)
% Index of the '}' matching the '{' at position start.
    depth = 0;
    for i = start:length(text)
        switch text(i)
          case '{'
            depth = depth + 1;
          case '}'
            depth = depth - 1;
            if depth == 0
                stop = i;
                return
            end
        end
    end
    stop = [];
end
