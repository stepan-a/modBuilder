function eqs = inline_model_local_variables(eqs, locals, declared, paramnames, filename)
% Substitute the model-local variables of a model block into the equations that use them.
%
% INPUTS:
% - eqs         [struct]   k×1 array of equations, see modfile.parse_model_block
% - locals      [struct]   p×1 array of '#name = expr;' definitions, same source
% - declared    [cell]     names of the declared symbols, for the collision check
% - paramnames  [cell]     names of the parameters, handed to ast.substitute so that a
%                          parameter inside a definition is not shifted in time
% - filename    [char]     name used in error messages (default '<string>')
%
% OUTPUTS:
% - eqs         [struct]   the same array with every local reference replaced
%
% REMARKS:
% - Model-local variables are pure syntactic sugar: Dynare substitutes them at the
%   expression level and they never reach M_. modBuilder has no representation for
%   them, so they are inlined here rather than rejected, since real .mod files use
%   them heavily.
% - The substitution goes through the tree, not through the text. Two reasons, both of
%   which a strrep would get wrong:
%     * precedence, '#z = a+b;' used in 'x*z' must become 'x*(a+b)', not 'x*a+b';
%     * lags, '#z = a*b;' used as 'z(-1)' must become 'a(-1)*b(-1)', with parameters
%       left alone. ast.substitute is lag-aware and takes the parameter names for
%       exactly that purpose.
% - Equations that reference no local are left byte for byte untouched, so a file
%   without '#' definitions still round-trips exactly. Equations that were rewritten are
%   re-rendered by ast.string() and their spacing changes.
% - Definitions are resolved among themselves first, in dependency order, so that a
%   local defined in terms of another does not leak into the equations.
    arguments
        eqs        struct
        locals     struct
        declared   cell
        paramnames cell
        filename   (1,:) char = '<string>'
    end

    if isempty(locals)
        return
    end

    names = {locals.name};

    duplicated = unique(names(cellfun(@(x) sum(strcmp(x, names)) > 1, names)));
    if ~isempty(duplicated)
        error('modfile:inline_model_local_variables:duplicateModelLocalVariable', '%s: model-local variable(s) defined more than once: %s. Dynare gives a redefinition a position-dependent scope, which is not supported.', filename, strjoin(duplicated, ', '))
    end

    clashing = intersect(names, declared);
    if ~isempty(clashing)
        error('modfile:inline_model_local_variables:conflict', '%s: model-local variable(s) %s collide with a declared symbol.', filename, strjoin(clashing, ', '))
    end

    % Resolve the definitions among themselves, in dependency order.
    order = local_topological_order(locals, names, filename);
    resolved = cell(numel(locals), 1);
    for k = 1:numel(order)
        i = order(k);
        expr = locals(i).expr;
        for j = 1:k-1
            other = order(j);
            if local_mentions(expr, names{other})
                expr = local_substitute(expr, names{other}, resolved{other}, paramnames, filename, locals(i).line);
            end
        end
        resolved{i} = expr;
    end

    % Substitute into the equations.
    for i = 1:numel(eqs)
        used = find(cellfun(@(name) local_mentions(eqs(i).expr, name), names));
        if isempty(used)
            continue
        end
        if isempty(eqs(i).lhs)
            expr = eqs(i).expr;
            for u = used
                expr = local_substitute(expr, names{u}, resolved{u}, paramnames, filename, eqs(i).line);
            end
            eqs(i).expr = expr;
        else
            lhs = eqs(i).lhs;
            rhs = eqs(i).rhs;
            for u = used
                lhs = local_substitute(lhs, names{u}, resolved{u}, paramnames, filename, eqs(i).line);
                rhs = local_substitute(rhs, names{u}, resolved{u}, paramnames, filename, eqs(i).line);
            end
            eqs(i).lhs = lhs;
            eqs(i).rhs = rhs;
            eqs(i).expr = sprintf('%s = %s', lhs, rhs);
        end
    end
end

function tf = local_mentions(expr, name)
% Cheap test for a whole-word occurrence, used to leave untouched equations alone.
    tf = ~isempty(regexp(expr, ['\<' regexptranslate('escape', name) '\>'], 'once'));
end

function out = local_substitute(expr, name, replacement, paramnames, filename, line)
% Replace one model-local variable in one expression, working on the tree.
    try
        out = ast(expr).substitute(name, replacement, paramnames).string();
    catch err
        error('modfile:inline_model_local_variables:unparsableEquation', '%s (line %u): cannot substitute the model-local variable "%s" into "%s": %s', filename, line, name, expr, err.message)
    end
end

function order = local_topological_order(locals, names, filename)
% Order the definitions so that each comes after the ones it references. Ties are broken
% by position in the file, the same rule checksteady uses.
    n = numel(locals);
    deps = false(n);
    for i = 1:n
        for j = 1:n
            if i ~= j && local_mentions(locals(i).expr, names{j})
                deps(i, j) = true;
            end
        end
    end

    order = zeros(1, n);
    done = false(1, n);
    for k = 1:n
        candidate = find(~done & ~any(deps & ~repmat(done, n, 1), 2)', 1);
        if isempty(candidate)
            stuck = names(~done);
            error('modfile:inline_model_local_variables:circularModelLocalVariable', '%s: the model-local variables %s depend on each other in a cycle.', filename, strjoin(stuck, ', '))
        end
        order(k) = candidate;
        done(candidate) = true;
    end
end
