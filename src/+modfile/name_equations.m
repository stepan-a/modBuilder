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
% - The remaining equations go through modBuilder.matchequations, the bipartite matcher
%   the Dynare-based constructor already uses, on the static residual of each equation.
%   Reusing it keeps the two entry points in agreement, including their diagnostics.
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
            eqasts{k} = ast(residual).staticise().simplify();
        catch err
            error('modfile:name_equations:unparsableEquation', '%s (line %u): cannot parse the equation "%s": %s', filename, eqs(i).line, eqs(i).expr, err.message)
        end
    end

    [eq2var, umeqs, umvars] = modBuilder.matchequations(eqasts, eqlhs, available);

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
