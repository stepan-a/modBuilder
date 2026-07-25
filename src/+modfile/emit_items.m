function lines = emit_items(items, reserved, blocks)
% Emit a list of generated calls, restoring the macro control flow they came from.
%
% INPUTS:
% - items      [struct]   k×1 array, in emission order:
%                           .ctx      [struct] the directive frames the item came from,
%                                              outermost first, see modfile.macro_frame
%                           .strings  [cell]   the character arguments of the call, the
%                                              ones a loop templates over
%                           .render   [handle] render(strings, tail) -> the call, where
%                                              tail is the extra argument text a
%                                              modBuilder implicit loop needs
% - reserved   [cell]     names already used as locals in the script, which the loop
%                         variables must not shadow
% - blocks     [struct]   the branches of each conditional, keyed by the source line of
%                         its @#if: .conds (the MATLAB source per branch), .taken, and
%                         per branch .branches (its calls), .subblocks (the conditionals
%                         nested in it) and .recovered (whether it could be read at all)
%
% OUTPUTS:
% - lines      [cell]     n×1 array of row char arrays
%
% REMARKS:
% - A run of items sharing a @#for frame is emitted as one call when a $N template
%   reproduces every iteration exactly, and as a MATLAB for loop otherwise. The template
%   is guessed by replacing the values of the first iteration with placeholders and then
%   VERIFIED by expanding it again over all the iterations. Guessing wrongly is therefore
%   harmless: a template that does not reproduce the observed calls is discarded.
% - A run sharing a @#if frame becomes a MATLAB if/elseif/else carrying every branch. The
%   branches that were not taken come from blocks, which modfile.read fills by reading the
%   file again with the conditional forced onto each of them. Nested conditionals nest in
%   the same way, through the per-branch blocks each entry carries.
% - A conditional falls back to its flat calls when a branch could not be read on its own,
%   or when a condition has no MATLAB form. Writing an if would then give some branch an
%   empty body, which silently drops what it holds.
% - Anything that cannot be emitted as control flow falls back to the flat calls, which
%   are always correct.
    arguments
        items    struct
        reserved (1,:) cell = {}
        blocks   struct = struct('id', {}, 'line', {}, 'nbranches', {}, 'conds', {}, 'taken', {}, 'position', {}, 'branches', {}, 'subblocks', {}, 'recovered', {})
    end

    lines = local_emit(items, 0, '', reserved, blocks);
    lines = lines(:);
end

function lines = local_emit(items, depth, indent, reserved, blocks)
% Emit the items, opening a block whenever they share a frame deeper than depth.
    lines = {};
    i = 1;
    while i <= numel(items)
        ctx = items(i).ctx;
        if numel(ctx) <= depth
            if ~isempty(items(i).render)
                lines{end+1} = [indent items(i).render(items(i).strings, '')]; %#ok<AGROW>
            end
            i = i + 1;
            continue
        end

        frame = ctx(depth+1);
        j = i;
        while j < numel(items) && local_same_construct(items(j+1).ctx, depth, frame)
            j = j + 1;
        end
        run = items(i:j);

        switch frame.kind
          case 'for'
            lines = [lines, local_emit_loop(run, depth, indent, reserved, blocks)]; %#ok<AGROW>
          case 'if'
            lines = [lines, local_emit_if(run, frame, depth, indent, reserved, blocks)]; %#ok<AGROW>
          otherwise
            lines = [lines, local_emit(run, depth+1, indent, reserved, blocks)]; %#ok<AGROW>
        end
        i = j + 1;
    end
end

function tf = local_same_construct(ctx, depth, frame)
% True when a context belongs to the same construct as frame at the given depth.
    tf = numel(ctx) > depth && strcmp(ctx(depth+1).kind, frame.kind) && ctx(depth+1).id == frame.id;
end

function lines = local_emit_if(run, frame, depth, indent, reserved, blocks)
% Emit a conditional as a MATLAB if, with every one of its branches.
%
% The branches that were not taken come from blocks: modfile.read has read the file again
% with the conditional forced onto each of them, so their calls are available even though
% a plain expansion never produces them. The branch that was taken is the run itself.
    block = local_block(blocks, frame.id);

    if isempty(block) || ~local_renderable(block)
        % No branch could be recovered, or some condition has no MATLAB form. Emitting an
        % if would then look re-runnable while quietly dropping a branch.
        lines = {sprintf('%s%% from the conditional at line %u of the .mod file%s', indent, frame.line, local_because(block))};
        lines = [lines, local_emit(run, depth+1, indent, reserved, blocks)];
        return
    end

    inner = [indent '    '];
    lines = {};
    for b = 1:block.nbranches
        if b == 1
            lines{end+1} = sprintf('%sif %s', indent, block.conds{b}); %#ok<AGROW>
        elseif isempty(block.conds{b})
            lines{end+1} = sprintf('%selse', indent); %#ok<AGROW>
        else
            lines{end+1} = sprintf('%selseif %s', indent, block.conds{b}); %#ok<AGROW>
        end

        if b == block.taken
            lines = [lines, local_emit(run, depth+1, inner, reserved, blocks)]; %#ok<AGROW>
        else
            % The calls of a branch read separately: their conditional frames were removed
            % when they were harvested, so they are emitted from the top.
            lines = [lines, local_emit(block.branches{b}, 0, inner, reserved, block.subblocks{b})]; %#ok<AGROW>
        end
    end
    lines{end+1} = sprintf('%send', indent);
end

function block = local_block(blocks, id)
% The recorded branches of the conditional at a given line.
    block = [];
    for i = 1:numel(blocks)
        if blocks(i).id == id
            block = blocks(i);
            return
        end
    end
end

function tf = local_renderable(block)
% True when every branch of a conditional can be written as MATLAB.
%
% The first branch always needs a condition, and so does any @#elseif; only a trailing
% @#else may have none. A condition the macro engine cannot render leaves nothing to put
% after the if, so the whole construct falls back to its flat calls.
    tf = false;
    if block.nbranches < 1
        return
    end
    % taken may be 0: a @#if with no @#else whose condition was false took no branch at
    % all. Its branch was still read separately, so it can be emitted; there is simply
    % nothing coming from the run.
    if ~all(block.recovered)
        % A branch that could not be read on its own. Writing an if would give it an empty
        % body, which silently drops whatever it holds.
        return
    end
    for b = 1:block.nbranches
        if isempty(block.conds{b}) && b < block.nbranches
            return
        end
    end
    if isempty(block.conds{1})
        return
    end
    tf = true;
end

function why = local_because(block)
% Say why a conditional could not become a MATLAB if.
%
% The reasons are checked in the order local_renderable rejects them, so that the comment
% names the one that actually applied. A branch that could not be read is the common case
% and used to be reported as a condition that does not render, which sends the reader
% looking for the wrong thing.
    if isempty(block)
        why = ' (it was not recorded)';
        return
    end
    if ~all(block.recovered)
        missing = find(~block.recovered);
        why = sprintf(' (branch %u could not be read on its own)', missing(1));
        return
    end
    if isempty(block.conds{1})
        why = ' (its condition has no MATLAB equivalent)';
        return
    end
    why = ' (one of its conditions has no MATLAB equivalent)';
end

function lines = local_emit_loop(run, depth, indent, reserved, blocks)
% Emit a loop's items as one templated call, as a MATLAB for loop, or plainly.
    run = local_merge_nested(run, depth);
    iterations = local_group_iterations(run, depth);

    template = local_template(iterations, depth);
    if isempty(template)
        lines = local_emit_flat_iterations(iterations, depth, indent, reserved, blocks);
        return
    end

    frame = run(1).ctx(depth+1);
    values = local_values(iterations, depth);

    % A modBuilder implicit loop runs one call over every index value, so a body with
    % several calls would come out grouped by call rather than by iteration: y_US, y_EA,
    % k_US, k_EA where the macro produced y_US, k_US, y_EA, k_EA. That is the order the
    % endogenous variables are declared in, so the compact form is only used when each
    % iteration contributes a single call; otherwise the MATLAB for loop below keeps the
    % original order.
    [sets, cartesian] = local_cartesian(values);
    if cartesian && isscalar(template) && local_placeholders_ok(template, size(values, 2))
        tail = sprintf(', %s', strjoin(cellfun(@local_render_set, sets, 'UniformOutput', false), ', '));
        lines = cell(1, numel(template));
        for k = 1:numel(template)
            lines{k} = [indent template(k).render(template(k).strings, tail)];
        end
        return
    end

    lines = local_emit_matlab_for(template, values, frame, indent, reserved);
end

function run = local_merge_nested(run, depth)
% Fold a loop nested immediately inside another into a single multi-index loop.
%
% Two nested @#for produce items whose context is [outer, inner, ...]. Their iterations
% run over the Cartesian product of the two index sets, in the order a multi-index
% implicit loop expands, so the pair can be treated as one loop with both indices. This
% is applied repeatedly, so a stack of loops folds into one.
%
% The fold is refused as soon as one item of the run sits directly in the outer loop, or
% the inner constructs are not all the same loop: the run is then genuinely irregular and
% each outer iteration is emitted on its own.
    while true
        if any(arrayfun(@(it) numel(it.ctx) <= depth+1, run))
            return
        end
        inner = arrayfun(@(it) it.ctx(depth+2), run);
        if ~all(strcmp({inner.kind}, 'for')) || numel(unique([inner.id])) ~= 1
            return
        end

        counter = 0;
        previous = [NaN NaN];
        for i = 1:numel(run)
            outer = run(i).ctx(depth+1);
            this = [outer.iter, run(i).ctx(depth+2).iter];
            if ~isequal(this, previous)
                counter = counter + 1;
                previous = this;
            end
            merged = modfile.macro_frame('for', outer.id, counter, '', false, ...
                                         [outer.values, run(i).ctx(depth+2).values], ...
                                         [outer.names, run(i).ctx(depth+2).names]);
            run(i).ctx = [run(i).ctx(1:depth), merged, run(i).ctx(depth+3:end)];
        end
    end
end

function iterations = local_group_iterations(run, depth)
% Split a loop's items into one list per iteration.
    iterations = {};
    current = [run(1).ctx(depth+1).iter];
    start = 1;
    for i = 2:numel(run)
        if run(i).ctx(depth+1).iter ~= current
            iterations{end+1} = run(start:i-1); %#ok<AGROW>
            current = run(i).ctx(depth+1).iter;
            start = i;
        end
    end
    iterations{end+1} = run(start:end);
end

function values = local_values(iterations, depth)
% The index values of every iteration, as a K×n cell array.
    n = numel(iterations{1}(1).ctx(depth+1).values);
    values = cell(numel(iterations), n);
    for k = 1:numel(iterations)
        values(k,:) = iterations{k}(1).ctx(depth+1).values;
    end
end

function template = local_template(iterations, depth)
% Guess a $N template from the first iteration, then verify it reproduces every one.
%
% Returns the templated items, or empty when no template reproduces the observed calls.
    template = [];

    if numel(iterations) < 2
        % One iteration gives nothing to generalise from; the flat call is honest.
        return
    end

    for k = 1:numel(iterations)
        if numel(iterations{k}) ~= numel(iterations{1})
            return
        end
        for i = 1:numel(iterations{k})
            if numel(iterations{k}(i).ctx) > depth + 1
                % A nested construct inside the loop; the items are emitted through it.
                return
            end
            if numel(iterations{k}(i).strings) ~= numel(iterations{1}(i).strings)
                return
            end
            if isfield(iterations{k}(i), 'templatable') && ~iterations{k}(i).templatable
                % A call whose shape a loop cannot carry, such as a plain assignment,
                % whose left-hand side a loop cannot build.
                return
            end
        end
    end

    values = local_values(iterations, depth);
    if any(cellfun(@isempty, values(:)))
        return
    end

    candidate = iterations{1};
    for i = 1:numel(candidate)
        for s = 1:numel(candidate(i).strings)
            variants = cellfun(@(it) it(i).strings{s}, iterations, 'UniformOutput', false);
            [candidate(i).strings{s}, ok] = local_template_string(variants, values);
            if ~ok
                template = [];
                return
            end
        end
    end

    % Verify the whole thing once more, so that whatever way the template was arrived at,
    % what is emitted provably reproduces the calls it replaces.
    for k = 1:numel(iterations)
        for i = 1:numel(candidate)
            for s = 1:numel(candidate(i).strings)
                if ~local_same(local_fill(candidate(i).strings{s}, values(k,:)), iterations{k}(i).strings{s})
                    template = [];
                    return
                end
            end
        end
    end

    template = candidate;
end

function [tmpl, ok] = local_template_string(variants, values)
% Build the $N template of one string from the way it varies across the iterations.
%
% Only the part that actually differs between iterations is turned into placeholders.
% Substituting blindly over the whole string would corrupt it whenever an index value
% happens to occur inside a name that does not vary: with an index 'a', the 'a's of
% "alpha" would be replaced too, and no template would survive verification.
    tmpl = '';
    ok = false;

    prefix = local_common_prefix(variants);
    suffix = local_common_suffix(variants, numel(prefix));

    middles = cellfun(@(v) v(numel(prefix)+1:end-numel(suffix)), variants, 'UniformOutput', false);

    middle = local_placehold(middles{1}, values(1,:));
    for k = 1:numel(middles)
        if ~local_same(local_fill(middle, values(k,:)), middles{k})
            return
        end
    end

    tmpl = local_row([prefix middle suffix]);
    ok = true;
end

function tf = local_same(a, b)
% Compare two strings, treating every empty char array as the same one.
%
% strcmp distinguishes a 0-by-0 char from a 1-by-0 one, and both turn up here: an absent
% attribute is '' while a substitution that consumed the whole string leaves a 1-by-0.
% Without this, a symbol with no long_name would never match itself and no loop would
% ever be recognised.
    tf = strcmp(local_row(a), local_row(b));
end

function s = local_row(s)
% Normalise a char array to a 1-by-n row.
    s = reshape(char(s), 1, []);
end

function p = local_common_prefix(variants)
% Longest character prefix shared by every variant.
    p = variants{1};
    for k = 2:numel(variants)
        n = min(numel(p), numel(variants{k}));
        j = find(p(1:n) ~= variants{k}(1:n), 1);
        if isempty(j)
            p = p(1:n);
        else
            p = p(1:j-1);
        end
    end
end

function s = local_common_suffix(variants, used)
% Longest character suffix shared by every variant, without eating into the prefix.
    room = min(cellfun(@numel, variants)) - used;
    s = '';
    for n = 1:room
        c = variants{1}(end-n+1);
        if ~all(cellfun(@(v) v(end-n+1) == c, variants))
            break
        end
        s = [c s]; %#ok<AGROW>
    end
end

function str = local_placehold(str, values)
% Replace the index values of one iteration by their $N placeholders.
%
% This is a single left-to-right scan rather than one strrep per index, because the
% placeholders it writes contain digits that a later index could match: substituting 'US'
% then 1 in "y_US_1" would turn the "1" of the "$1" just written into "$2" as well. At
% each position the longest matching value wins, so an index whose text is a prefix of
% another's cannot shadow it.
    texts = cellfun(@local_text, values, 'UniformOutput', false);
    [~, order] = sort(cellfun(@numel, texts), 'descend');

    out = '';
    i = 1;
    while i <= numel(str)
        matched = false;
        for n = order
            t = texts{n};
            if ~isempty(t) && i + numel(t) - 1 <= numel(str) && strcmp(str(i:i+numel(t)-1), t)
                out = [out sprintf('$%u', n)]; %#ok<AGROW>
                i = i + numel(t);
                matched = true;
                break
            end
        end
        if ~matched
            out = [out str(i)]; %#ok<AGROW>
            i = i + 1;
        end
    end
    str = out;
end

function str = local_fill(str, values)
% Substitute index values for the placeholders, exactly as modBuilder's implicit loops do.
    for n = numel(values):-1:1
        str = strrep(str, sprintf('$%u', n), local_text(values{n}));
    end
end

function s = local_text(value)
% The text an index value contributes to a symbol name.
    if ischar(value)
        s = value;
    else
        s = num2str(value);
    end
end

function tf = local_placeholders_ok(template, n)
% True when every templated string carries exactly the placeholders $1..$n.
%
% modBuilder requires the name and the equation of an implicit loop to use the same
% placeholder set, and as many index arrays as placeholders. A template that does not
% satisfy that has to go through a MATLAB for loop instead.
    tf = true;
    expected = arrayfun(@(k) sprintf('$%u', k), 1:n, 'UniformOutput', false);
    for i = 1:numel(template)
        for s = 1:numel(template(i).strings)
            if isempty(template(i).strings{s})
                continue
            end
            found = unique(regexp(template(i).strings{s}, '\$\d+', 'match'));
            if ~isempty(setxor(found, expected))
                tf = false;
                return
            end
        end
    end
end

function [sets, cartesian] = local_cartesian(values)
% Distinct values per index, and whether the iterations are exactly their full product.
%
% The product is generated with the last index varying fastest, which is the order both
% MATLAB's combinations() and a nest of @#for loops produce.
    n = size(values, 2);
    sets = cell(1, n);
    for j = 1:n
        sets{j} = local_unique(values(:,j));
    end

    counts = cellfun(@numel, sets);
    cartesian = prod(counts) == size(values, 1);
    if ~cartesian
        return
    end

    row = 1;
    digits = ones(1, n);
    while row <= size(values, 1)
        for j = 1:n
            if ~isequal(sets{j}{digits(j)}, values{row, j})
                cartesian = false;
                return
            end
        end
        row = row + 1;
        for j = n:-1:1
            digits(j) = digits(j) + 1;
            if digits(j) <= counts(j)
                break
            end
            digits(j) = 1;
        end
    end
end

function u = local_unique(column)
% Distinct values of one index, in order of first appearance.
    u = {};
    for i = 1:numel(column)
        if ~any(cellfun(@(x) isequal(x, column{i}), u))
            u{end+1} = column{i}; %#ok<AGROW>
        end
    end
end

function str = local_render_set(set)
% Render one index set as the cell array a modBuilder implicit loop takes.
    parts = cellfun(@local_render_value, set, 'UniformOutput', false);
    str = sprintf('{%s}', strjoin(parts, ', '));
end

function str = local_render_value(value)
% Render one index value as MATLAB.
    if ischar(value)
        str = sprintf('''%s''', strrep(value, '''', ''''''));
    else
        str = num2str(value);
    end
end

function lines = local_emit_matlab_for(template, values, frame, indent, reserved)
% Emit a loop modBuilder's implicit loops cannot express, as a MATLAB for loop.
    n = size(values, 2);
    names = local_loop_names(frame, n, reserved);

    lines = {};
    for j = 1:n
        lines{end+1} = sprintf('%s%s = %s;', indent, names{j}, local_render_set(values(:,j)')); %#ok<AGROW>
    end

    counter = local_unique_name('it', [reserved, names]);
    lines{end+1} = sprintf('%sfor %s = 1:%u', indent, counter, size(values, 1));

    body = [indent '    '];
    for i = 1:numel(template)
        % The renderers quote whatever they are handed, because they normally receive
        % literals. Inside a loop the arguments are expressions instead, so each one is
        % rendered as a marker and swapped in afterwards: once for the slots the renderer
        % quoted, once for the slots it left bare.
        markers = arrayfun(@(s) local_marker(s), 1:numel(template(i).strings), 'UniformOutput', false);
        line = template(i).render(markers, '');
        for s = 1:numel(template(i).strings)
            [quoted, bare] = local_argument(template(i).strings{s}, names, counter, values(1,:));
            line = strrep(line, ['''' markers{s} ''''], quoted);
            line = strrep(line, markers{s}, bare);
        end
        lines{end+1} = [body line]; %#ok<AGROW>
    end

    lines{end+1} = sprintf('%send', indent);
end

function marker = local_marker(s)
% A stand-in for one argument, chosen so that no real string can contain it.
    marker = sprintf('%c%u%c', char(1), s, char(1));
end

function [quoted, bare] = local_argument(str, names, counter, kinds)
% The two forms one templated argument takes inside a MATLAB for loop.
%
% quoted replaces a slot the renderer wrapped in quotes, bare a slot it left alone, such
% as the value of a parameter.
    if isempty(regexp(str, '\$\d+', 'once'))
        quoted = sprintf('''%s''', strrep(str, '''', ''''''));
        bare = str;
        return
    end
    quoted = local_sprintf(str, names, counter, kinds);
    bare = quoted;
end

function names = local_loop_names(frame, n, reserved)
% Name the per-index value lists after the macro indices, avoiding the script's locals.
    names = cell(1, n);
    taken = reserved;
    for j = 1:n
        if numel(frame.names) >= j && ~isempty(frame.names{j})
            base = [frame.names{j} '_values'];
        else
            base = sprintf('index%u_values', j);
        end
        names{j} = local_unique_name(base, taken);
        taken{end+1} = names{j}; %#ok<AGROW>
    end
end

function name = local_unique_name(base, taken)
% A name close to base that no local in the script uses.
    name = base;
    while ismember(name, taken)
        name = [name '_'];
    end
end

function expr = local_sprintf(str, names, counter, kinds)
% Turn a $N template into the sprintf call that rebuilds it inside a MATLAB for loop.
%
% The result is a MATLAB expression producing the same text the placeholders stood for.
% Each placeholder takes the conversion its index needs: %d for a numeric index, %s for a
% name. Formatting a number with %s would emit the character of that code point instead
% of its digits, which is silently wrong rather than an error.
    if isempty(str)
        expr = '''''';
        return
    end

    pieces = regexp(strrep(str, '%', '%%'), '\$\d+', 'split');
    tokens = regexp(str, '\$(\d+)', 'tokens');
    if isempty(tokens)
        expr = sprintf('''%s''', strrep(str, '''', ''''''));
        return
    end

    order = cellfun(@(t) str2double(t{1}), tokens);
    literal = pieces{1};
    args = cell(1, numel(order));
    for k = 1:numel(order)
        if ischar(kinds{order(k)})
            literal = [literal '%s' pieces{k+1}]; %#ok<AGROW>
        else
            literal = [literal '%d' pieces{k+1}]; %#ok<AGROW>
        end
        args{k} = sprintf('%s{%s}', names{order(k)}, counter);
    end
    expr = sprintf('sprintf(''%s'', %s)', strrep(literal, '''', ''''''), strjoin(args, ', '));
end

function lines = local_emit_flat_iterations(iterations, depth, indent, reserved, blocks)
% Emit every iteration's items on their own, one iteration after the other.
    lines = {};
    for k = 1:numel(iterations)
        lines = [lines, local_emit(iterations{k}, depth+1, indent, reserved, blocks)]; %#ok<AGROW>
    end
end
