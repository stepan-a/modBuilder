function lines = translate(mod, options)
% Turn the description of a .mod file into a MATLAB script that builds the model.
%
% INPUTS:
% - mod        [struct]    description produced by modfile.read
%
% OPTIONAL NAME-VALUE ARGUMENTS:
% - Tag        [char]      equation tag carrying the equation/variable association
%                          (default 'name')
% - Object     [char]      name of the modBuilder variable in the script (default 'm')
%
% OUTPUTS:
% - lines      [cell]      k×1 array of row char arrays, the script, one line per entry
%
% EXAMPLES:
% lines = modfile.translate(modfile.read('rbc.mod'));
%
% REMARKS:
% - The script is the artifact: it is meant to be read, kept and edited, and running it
%   is what produces the object. Everything is emitted through the public modBuilder API
%   so that a user can carry on from the generated file by hand.
% - The whole logic of the .mod file is translated, not only the path its current macro
%   settings select. modfile.read supplies, in mod.branches, the same description read
%   again with each conditional forced onto the branches it did not take, and the calls
%   of every branch are emitted inside a MATLAB if/elseif/else. Changing a macro variable
%   at the top of the script therefore rebuilds the model the .mod file would have given
%   with that setting.
% - Emission order is load bearing. Equations come first because add() appends one row to
%   the endogenous table per call, and write() prints the var list in that order; the
%   exogenous variables and the parameters follow in declaration order, mirroring
%   M_.exo_names and M_.param_names on the Dynare-based path. A model read from a file
%   written by write() therefore round-trips byte for byte.
% - Calibration is emitted as MATLAB locals holding the source expressions, then handed
%   to parameter(). Keeping the source text rather than a re-formatted number preserves
%   both the arithmetic of a chain such as beta = 1/(1+r) and the exact decimals of the
%   file, which the round-trip depends on.
% - Declarations carry 'declared', true because a .mod file may declare a parameter or an
%   exogenous variable that no equation references, which parameter() otherwise rejects.
    arguments
        mod             struct
        options.Tag     (1,:) char = 'name'
        options.Object  (1,:) char = 'm'
    end

    obj = options.Object;
    primary = local_prepare(mod, options.Tag, obj);

    lines = {};
    lines{end+1} = sprintf('%% modBuilder script generated from %s.', mod.filename);
    lines{end+1} = '%';
    lines{end+1} = '% Edit freely: running this file rebuilds the model.';
    lines{end+1} = '';

    %
    % The @#define variables become MATLAB locals, so the settings the file was written
    % with stay visible and adjustable instead of disappearing into the expansion.
    %
    if ~isempty(mod.macro.defines)
        lines{end+1} = '% Macro variables';
        for i = 1:size(mod.macro.defines, 1)
            lines{end+1} = sprintf('%s = %s;', mod.macro.defines{i,1}, mod.macro.defines{i,2}); %#ok<AGROW>
        end
        lines{end+1} = '';
    end

    lines{end+1} = sprintf('%s = modBuilder();', obj);
    lines{end+1} = '';

    % Names the generated loops must not shadow.
    reserved = [mod.macro.defines(:,1)', mod.calib(:,1)'];

    % The same description read again with each conditional forced onto a branch it did
    % not take, so that every branch can be emitted.
    variants = local_prepare_branches(mod, options.Tag, obj);

    sections = { ...
        'equations', '% Equations'; ...
        'reorder',   ''; ...
        'tags',      '% Equation tags'; ...
        'exo',       '% Exogenous variables'; ...
        'calib',     '% Calibration'; ...
        'params',    '% Parameters'; ...
        'exovalues', '% Exogenous variables set by a top-level assignment'; ...
        'endometa',  '% Endogenous variable attributes'; ...
        'steady',    '% Analytical steady state'; ...
        'initval',   '% Initial guess for the steady state'};

    for s = 1:size(sections, 1)
        which = sections{s,1};

        if strcmp(which, 'reorder')
            % add() declares the endogenous variables in equation order. When the var
            % statement lists them differently, which reassign() and flip() both produce,
            % restore the declared order; write() prints the var list from the table.
            if ~isequal(primary.names(:)', mod.endo(:,1)') && ~local_conditional_declarations(mod)
                declaration = cellfun(@local_quote, mod.endo(:,1)', 'UniformOutput', false);
                lines{end+1} = '% Declaration order of the endogenous variables'; %#ok<AGROW>
                lines{end+1} = sprintf('%s.reorder(''endogenous'', {%s});', obj, strjoin(declaration, ', ')); %#ok<AGROW>
                lines{end+1} = ''; %#ok<AGROW>
            end
            continue
        end

        items = local_section_items(primary, which);
        blocks = local_section_blocks(mod, variants, which, options.Tag, obj);
        [items, blocks] = local_add_placeholders(items, blocks, mod);

        if isempty(items)
            continue
        end

        lines{end+1} = sections{s,2}; %#ok<AGROW>
        lines = [lines, modfile.emit_items(items, reserved, blocks)'];
        lines{end+1} = ''; %#ok<AGROW>
    end

    lines = lines(:);
end

function tf = local_conditional_declarations(mod)
% True when a @#if decides which endogenous variables are declared.
%
% reorder() takes the whole list and refuses anything that is not a permutation of it, so
% it cannot be emitted when the list depends on a macro flag: the call would fail as soon
% as the flag were changed, in a script whose whole point is that it can be. The
% declaration order then follows the equations, which differs from the .mod file in the
% var statement only.
    tf = false;
    for i = 1:size(mod.endo, 1)
        line = mod.endo{i,4};
        if line < 1 || line > numel(mod.macro.context)
            continue
        end
        ctx = mod.macro.context{line};
        if ~isempty(ctx) && any(strcmp({ctx.kind}, 'if'))
            tf = true;
            return
        end
    end
end

function prep = local_prepare(mod, tag, obj)
% Everything a description needs before its calls can be built.
%
% Model-local variables are inlined first: the equations that reference them must be
% complete before they are matched to endogenous variables and emitted.
    prep.mod = mod;
    prep.tag = tag;
    prep.obj = obj;
    prep.context = mod.macro.context;
    prep.equations = modfile.inline_model_local_variables(mod.equations, mod.locals, [mod.endo(:,1); mod.exo(:,1); mod.params(:,1)], mod.params(:,1)', mod.filename);
    prep.names = modfile.name_equations(prep.equations, mod.endo(:,1), tag, mod.filename);
end

function variants = local_prepare_branches(mod, tag, obj)
% Prepare the descriptions of the branches that were not taken.
    variants = struct('id', {}, 'line', {}, 'branch', {}, 'cond', {}, 'position', {}, 'prep', {}, 'refused', {});
    if ~isfield(mod, 'branches')
        return
    end
    for i = 1:numel(mod.branches)
        b = mod.branches(i);
        if ~isempty(b.refused)
            % A branch the file itself refuses with @#error. There is nothing to prepare;
            % the translator writes the error out in its place.
            variants(end+1) = struct('id', b.id, 'line', b.line, 'branch', b.branch, 'cond', b.cond, 'position', b.position, 'prep', [], 'refused', b.refused); %#ok<AGROW>
            continue
        end
        try
            prep = local_prepare(b.mod, tag, obj);
        catch
            % A branch whose equations cannot be matched on their own; the conditional
            % falls back to emitting only the branch that was taken.
            continue
        end
        variants(end+1) = struct('id', b.id, 'line', b.line, 'branch', b.branch, 'cond', b.cond, 'position', b.position, 'prep', prep, 'refused', ''); %#ok<AGROW>
    end
end

function blocks = local_section_blocks(mod, variants, which, tag, obj)
% The calls each conditional's branches contribute to one section.
    blocks = struct('id', {}, 'line', {}, 'nbranches', {}, 'conds', {}, 'taken', {}, 'position', {}, ...
                    'branches', {}, 'subblocks', {}, 'recovered', {});

    for i = 1:numel(mod.macro.conditionals)
        c = mod.macro.conditionals(i);
        entry = struct('id', c.id, 'line', c.line, 'nbranches', c.nbranches, 'conds', {c.conds}, ...
                       'taken', c.taken, 'position', c.position, ...
                       'branches', {cell(1, c.nbranches)}, ...
                       'subblocks', {cell(1, c.nbranches)}, ...
                       'recovered', false(1, c.nbranches));
        for b = 1:c.nbranches
            entry.branches{b} = local_empty_items();
            entry.subblocks{b} = local_empty_blocks();
        end
        entry.recovered(max(c.taken, 1)) = c.taken >= 1;

        for v = 1:numel(variants)
            if variants(v).id ~= c.id
                continue
            end
            b = variants(v).branch;
            if ~isempty(variants(v).refused)
                % The branch raises: write the error where its calls would have gone, once,
                % in the section the equations are emitted from.
                if strcmp(which, 'equations')
                    entry.branches{b} = local_error_item(variants(v).refused);
                end
                entry.recovered(b) = true;
                continue
            end
            all = local_section_items(variants(v).prep, which);
            % Only this conditional and the ancestors that had to be forced to reach it
            % are dropped: a conditional NESTED in the branch keeps its frame, so that it
            % can be emitted as an if of its own inside the branch.
            entry.branches{b} = local_under(all, [c.ancestors(:,1)', c.id]);
            inner = local_prepare_branches(variants(v).prep.mod, tag, obj);
            entry.subblocks{b} = local_section_blocks(variants(v).prep.mod, inner, which, tag, obj);
            entry.recovered(b) = true;
        end
        blocks(end+1) = entry; %#ok<AGROW>
    end
end

function items = local_under(items, ids)
% Keep only the calls a given conditional produced, and drop the frames of that
% conditional and of the ancestors forced to reach it, so that they can be emitted inside
% the branch being written. Deeper frames stay, so a @#for or a nested @#if in the branch
% is still emitted as such.
    keep = false(1, numel(items));
    target = ids(end);
    for i = 1:numel(items)
        if isempty(items(i).ctx)
            continue
        end
        isif = strcmp({items(i).ctx.kind}, 'if');
        if ~any(isif & [items(i).ctx.id] == target)
            continue
        end
        keep(i) = true;
        items(i).ctx(isif & ismember([items(i).ctx.id], ids)) = [];
    end
    items = items(keep);
end

function blocks = local_empty_blocks()
% An empty block array, with the fields modfile.emit_items expects.
    blocks = struct('id', {}, 'line', {}, 'nbranches', {}, 'conds', {}, 'taken', {}, 'position', {}, ...
                    'branches', {}, 'subblocks', {}, 'recovered', {});
end

function [items, blocks] = local_add_placeholders(items, blocks, mod)
% Give a conditional whose taken branch contributes nothing to this section a place to be
% emitted at, so that its other branches are not lost.
    for i = 1:numel(blocks)
        if isempty(blocks(i).branches)
            continue
        end
        if all(cellfun(@isempty, blocks(i).branches))
            continue
        end
        if any(arrayfun(@(it) any([it.ctx.id] == blocks(i).id), items))
            continue
        end
        phantom = local_empty_items();
        phantom(1) = struct('ctx', modfile.macro_frame('if', blocks(i).id, max(blocks(i).taken, 1), '', false, {}, {}, blocks(i).line), ...
                            'strings', {{}}, 'render', [], 'templatable', false, 'line', blocks(i).position);
        items = local_insert(items, phantom, blocks(i).position);
    end
end

function items = local_insert(items, phantom, position)
% Place a phantom among the calls, in the order the .mod file puts it.
    after = numel(items);
    for i = 1:numel(items)
        if local_line_of(items(i)) > position
            after = i - 1;
            break
        end
    end
    items = [items(1:after), phantom, items(after+1:end)];
end

function line = local_line_of(item)
% The output line a call came from, kept on the item for ordering.
    line = item.line;
end

function items = local_section_items(prep, which)
% Build the calls of one section from one description.
    mod = prep.mod;
    obj = prep.obj;
    context = prep.context;
    equations = prep.equations;
    names = prep.names;
    exonames = mod.exo(:,1);
    calibrated = mod.calib(:,1);

    items = local_empty_items();

    switch which
      case 'equations'
        for i = 1:numel(equations)
            items(end+1) = local_item(context, equations(i).line, {names{i}, equations(i).expr}, ...
                                      @(s, tail) sprintf('%s.add(%s, %s%s);', obj, local_quote(s{1}), local_quote(s{2}), tail)); %#ok<AGROW>
        end

      case 'tags'
        for i = 1:numel(equations)
            keys = setdiff(fieldnames(equations(i).tags), {prep.tag, 'name'});
            for j = 1:numel(keys)
                items(end+1) = local_item(context, equations(i).line, {names{i}, keys{j}, equations(i).tags.(keys{j})}, ...
                                          @(s, tail) sprintf('%s.tag(%s, %s, %s%s);', obj, local_quote(s{1}), local_quote(s{2}), local_quote(s{3}), tail)); %#ok<AGROW>
            end
        end

      case 'exo'
        for i = 1:size(mod.exo, 1)
            items(end+1) = local_item(context, mod.exo{i,4}, {mod.exo{i,1}, mod.exo{i,3}, mod.exo{i,2}}, ...
                                      @(s, tail) sprintf('%s.exogenous(%s, NaN%s, ''declared'', true%s);', obj, local_quote(s{1}), local_attributes(s), tail)); %#ok<AGROW>
        end

      case 'calib'
        for i = 1:size(mod.calib, 1)
            item = local_item(context, mod.calib{i,3}, {mod.calib{i,1}, mod.calib{i,2}}, ...
                              @(s, ~) sprintf('%s = %s;', s{1}, s{2}));
            item.templatable = false;
            items(end+1) = item; %#ok<AGROW>
        end

      case 'params'
        for i = 1:size(mod.params, 1)
            name = mod.params{i,1};
            if ismember(name, calibrated)
                value = name;
            else
                value = 'NaN';
            end
            items(end+1) = local_item(context, mod.params{i,4}, {name, mod.params{i,3}, mod.params{i,2}, value}, ...
                                      @(s, tail) sprintf('%s.parameter(%s, %s%s, ''declared'', true%s);', obj, local_quote(s{1}), s{4}, local_attributes(s), tail)); %#ok<AGROW>
        end

      case 'exovalues'
        for i = 1:size(mod.calib, 1)
            if ismember(mod.calib{i,1}, exonames)
                items(end+1) = local_item(context, mod.calib{i,3}, {mod.calib{i,1}}, ...
                                          @(s, tail) sprintf('%s.exogenous(%s, %s%s);', obj, local_quote(s{1}), s{1}, tail)); %#ok<AGROW>
            end
        end

      case 'endometa'
        for i = 1:size(mod.endo, 1)
            if isempty(mod.endo{i,2}) && isempty(mod.endo{i,3})
                continue
            end
            items(end+1) = local_item(context, mod.endo{i,4}, {mod.endo{i,1}, mod.endo{i,3}, mod.endo{i,2}}, ...
                                      @(s, tail) sprintf('%s.endogenous(%s, []%s%s);', obj, local_quote(s{1}), local_attributes(s), tail)); %#ok<AGROW>
        end

      case 'steady'
        declared = [mod.endo(:,1); mod.params(:,1)];
        known = [mod.endo(:,1); mod.exo(:,1); mod.params(:,1)];
        for i = 1:numel(mod.steady)
            target = mod.steady(i).names;
            expr = mod.steady(i).expr;
            if numel(target) > 1 || local_is_external_call(expr, known)
                % A call to a MATLAB routine, whatever its number of outputs. write()
                % renders a one-output call exactly like a plain assignment, so the two
                % are told apart here by the shape of the right-hand side.
                outputs = strjoin(cellfun(@local_quote, target, 'UniformOutput', false), ', ');
                item = local_item(context, mod.steady(i).line, {expr}, ...
                                  @(s, ~) sprintf('%s.steady_call({%s}, %s);', obj, outputs, local_quote(s{1})));
                % The output names sit outside the templated strings, so this call must
                % not be folded into a loop that would leave them unexpanded.
                item.templatable = false;
                items(end+1) = item; %#ok<AGROW>
            elseif ismember(target{1}, declared)
                items(end+1) = local_item(context, mod.steady(i).line, {target{1}, expr}, ...
                                          @(s, tail) sprintf('%s.steady(%s, %s%s);', obj, local_quote(s{1}), local_quote(s{2}), tail)); %#ok<AGROW>
            else
                items(end+1) = local_item(context, mod.steady(i).line, {target{1}, expr}, ...
                                          @(s, tail) sprintf('%s.steady_aux(%s, %s%s);', obj, local_quote(s{1}), local_quote(s{2}), tail)); %#ok<AGROW>
            end
        end

      case 'initval'
        for i = 1:size(mod.initval, 1)
            name = mod.initval{i,1};
            if ismember(name, exonames)
                method = 'exogenous';
            else
                method = 'endogenous';
            end
            items(end+1) = local_item(context, mod.initval{i,3}, {name, mod.initval{i,2}}, ...
                                      @(s, tail) sprintf('%s.%s(%s, %s%s);', obj, method, local_quote(s{1}), s{2}, tail)); %#ok<AGROW>
        end
    end
end

function tf = local_is_external_call(expr, known)
% True when expr is a single call to a routine that is neither a Dynare built-in nor a
% symbol of the model, i.e. a MATLAB function evaluated inside the steady_state_model
% block. modBuilder represents those with steady_call rather than steady.
    tf = false;
    token = regexp(strtrim(expr), '^([A-Za-z_]\w*)\s*\(', 'tokens', 'once');
    if isempty(token)
        return
    end
    name = token{1};
    if ismember(name, dynare_reserved_function_names()) || ismember(name, known)
        return
    end
    % The call must span the whole expression: 'f(a) + b' is an ordinary expression that
    % happens to start with a call, and cannot be handed to steady_call.
    s = strtrim(expr);
    open = find(s == '(', 1);
    depth = 0;
    for i = open:length(s)
        if s(i) == '('
            depth = depth + 1;
        elseif s(i) == ')'
            depth = depth - 1;
            if depth == 0
                tf = (i == length(s));
                return
            end
        end
    end
end

function s = local_attributes(strings)
% Render the long_name and texname key/value pairs of a declaration item.
%
% The item's strings are {name, long_name, texname, ...}: the attributes sit next to the
% name so that a loop templates over them too, which modBuilder requires when a long_name
% carries the same placeholders as the symbol.
    s = '';
    if numel(strings) >= 2 && ~isempty(strings{2})
        s = sprintf('%s, ''long_name'', %s', s, local_quote(strings{2}));
    end
    if numel(strings) >= 3 && ~isempty(strings{3})
        s = sprintf('%s, ''texname'', %s', s, local_quote(strings{3}));
    end
end

function items = local_error_item(message)
% The single call standing for a branch the file refuses with @#error.
    items = local_empty_items();
    items(1) = struct('ctx', modfile.macro_frame(), 'strings', {{message}}, ...
                      'render', @(s, ~) sprintf('error(''%s'');', strrep(s{1}, '''', '''''')), ...
                      'templatable', false, 'line', 0);
end

function items = local_empty_items()
% An empty item array, with the fields modfile.emit_items expects.
    items = struct('ctx', {}, 'strings', {}, 'render', {}, 'templatable', {}, 'line', {});
end

function item = local_item(context, line, strings, render)
% Build one emitted call, tagged with the directive frames its source line came from.
    if line >= 1 && line <= numel(context)
        ctx = context{line};
    else
        ctx = modfile.macro_frame();
    end
    item = struct('ctx', ctx, 'strings', {strings}, 'render', render, 'templatable', true, 'line', line);
end

function s = local_quote(str)
% Render a char array as a MATLAB single-quoted literal.
    s = sprintf('''%s''', strrep(str, '''', ''''''));
end
