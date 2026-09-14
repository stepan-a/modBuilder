function names = name_equations(eqs, endonames, tagname, filename)
% Associate every equation of a model block with a distinct endogenous variable.
%
% INPUTS:
% - eqs         [struct]   k×1 array of equations, see modfile.parse_model_block
% - endonames   [cell]     1×n or n×1 array of declared endogenous variable names
% - tagname     [char]     1×m array, equation tag carrying the association (default 'name')
% - filename    [char]     1×p array, name used in error messages (default '<string>')
%
% OUTPUTS:
% - names       [cell]     k×1 array, the variable each equation is keyed to
%
% REMARKS:
% - An equation carrying tagname is keyed to that tag when its value is a declared
%   endogenous variable. The tag is the association, not a claim about the left-hand
%   side: tests/load-mod-file/rbc1.true.mod tags 'k = exp(b)*(y-c)+...' with name='c'.
% - The remaining equations are paired with the variables by a minimum-cost bipartite
%   matching, as in modBuilder.matchequations, the matcher of the steady-state plan.
%   That one admits an edge only when the static residual pins the variable, see
%   modBuilder.pins: c^(-sigma)*(1 - beta*R) pins R and leaves c free, 0.1*junk fixes
%   junk at zero. The question here is which variable an equation is FOR, which has an
%   answer for the Euler equation or for Y/Y(-1) = g as well. So every variable of the
%   dynamic equation is admitted, at a cost that prefers one the static residual pins
%   over one it leaves free. The matching is maximal first, so the cheap edges give way
%   where a perfect pairing needs them to. No calibration is consulted: which variable
%   an equation is for does not depend on a coincidence of the parameter values.
% - Within a tier the costs are those of matchequations: a bonus for the left-hand side,
%   a penalty for a candidate many equations could take, and a stable tie-break.
% - ast.symbol_names is used where the constructor uses the private modBuilder.getsymbols;
%   it is the structural equivalent, and it already excludes the reserved function names.
    arguments
        eqs      struct
        endonames cell
        tagname  (1,:) char = 'name'
        filename (1,:) char = '<string>'
    end

    n = numel(eqs);
    names = repmat({''}, n, 1);
    hastag = false(n, 1);
    endonames = endonames(:)';

    for i = 1:n
        if isfield(eqs(i).tags, tagname)
            candidate = eqs(i).tags.(tagname);
            if ischar(candidate) && ismember(candidate, endonames)
                names{i} = candidate;
                hastag(i) = true;
            end
        end
    end

    if all(hastag)
        return
    end

    untagged = find(~hastag);
    available = setdiff(endonames, names(hastag), 'stable');

    nu = numel(untagged);
    eqasts = cell(nu, 1);
    eqlhs  = cell(nu, 1);
    dynamic = cell(nu, 1);
    for k = 1:nu
        i = untagged(k);
        if isempty(eqs(i).lhs)
            residual = eqs(i).expr;
            eqlhs{k} = {};
        else
            residual = sprintf('(%s) - (%s)', eqs(i).lhs, eqs(i).rhs);
            eqlhs{k} = ast(eqs(i).lhs).symbol_names();
        end
        try
            tree = ast(residual);
            dynamic{k} = tree.symbol_names();
            eqasts{k} = tree.staticise().simplify();
        catch err
            error('modfile:name_equations:unparsableEquation', '%s (line %u): cannot parse the equation "%s": %s', filename, eqs(i).line, eqs(i).expr, err.message)
        end
    end

    [eq2var, umeqs, umvars] = local_match(eqasts, dynamic, eqlhs, available);

    if ~isempty(umeqs) || ~isempty(umvars)
        bullets = {};
        for k = 1:numel(umeqs)
            i = untagged(umeqs(k));
            bullets{end+1} = sprintf('  line %u: %s', eqs(i).line, eqs(i).expr); %#ok<AGROW>
        end
        if ~isempty(umvars)
            bullets{end+1} = sprintf('  unmatched endogenous variables: %s', strjoin(umvars, ', ')); %#ok<AGROW>
        end
        error('modfile:name_equations:ambiguousEquation', '%s: unable to associate every equation with a unique endogenous variable. Add a "%s" tag to these:\n%s', filename, tagname, strjoin(bullets, sprintf('\n')))
    end

    for k = 1:nu
        names{untagged(k)} = eq2var{k};
    end

    modfile.warn('modfile:name_equations:autoMatch', '%s: %u equation(s) without a "%s" tag were matched automatically to endogenous variables.', filename, nu, tagname);
end

function [eq2var, umeqs, umvars] = local_match(statics, dynamic, lhs, candidates)
% Pair the equations with the variables, see the REMARKS of name_equations. The cost of
% a pair is its tier, 1 when the static residual pins the variable and 2 when the
% variable is free at the steady state, less a bonus for the left-hand side, plus a
% penalty for a candidate many equations could take, and a stable tie-break.
    n = numel(statics);
    m = numel(candidates);
    eq2var = repmat({''}, n, 1);
    forbid = 1e6;      % the private MATCH_FORBID and MATCH_UNMATCHED of modBuilder
    unmatched = 1e3;
    C = forbid * ones(n, m);
    tier = zeros(n, m);
    for i = 1:n
        for j = 1:m
            v = candidates{j};
            if ~any(strcmp(v, dynamic{i}))
                continue
            end
            if modBuilder.pins(statics{i}, v, candidates)
                tier(i, j) = 1;
            else
                tier(i, j) = 2;
            end
        end
    end
    degree = sum(tier > 0, 1);
    for i = 1:n
        for j = 1:m
            if tier(i, j) > 0
                C(i, j) = tier(i, j) - 0.5 * any(strcmp(candidates{j}, lhs{i})) + 0.1 * degree(j) / (m + 1) + 1e-6 * (i * (m + 1) + j);
            end
        end
    end
    M = matchpairs(C, unmatched);
    rows = false(n, 1);
    cols = false(m, 1);
    for k = 1:size(M, 1)
        eq2var{M(k, 1)} = candidates{M(k, 2)};
        rows(M(k, 1)) = true;
        cols(M(k, 2)) = true;
    end
    umeqs = find(~rows);
    umvars = candidates(~cols);
end
