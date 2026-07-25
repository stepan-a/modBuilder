function mod = read(filename, options)
% Read a .mod file into the neutral description modfile.translate turns into a script.
%
% INPUTS:
% - filename   [char]      1×n array, path to a .mod file
%
% OPTIONAL NAME-VALUE ARGUMENTS:
% - Strict       [logical]   scalar, turn the warnings about skipped statements into
%                            errors (default false)
% - Macro        [logical]   scalar, run the macro directives (default true)
% - Defines      [struct]    macro variables to seed, the equivalent of Dynare's -D
% - IncludePaths [cell]      directories searched by @#include
%
% OUTPUTS:
% - mod        [struct]    description of the file:
%                            .filename   [char]     the path that was read
%                            .endo       [cell]     n×4, {name, tex, long_name, line} in
%                                                   declaration order
%                            .exo        [cell]     n×4, idem
%                            .params     [cell]     n×4, idem
%                            .calib      [cell]     k×3, {name, expression, line} in file order
%                            .equations  [struct]   see modfile.parse_model_block
%                            .locals     [struct]   model-local variables, see modfile.parse_model_block
%                            .steady     [struct]   see modfile.parse_steady_state_model
%                            .initval    [cell]     k×3, see modfile.parse_initval
%                            .has_model  [logical]  scalar
%                            .has_steady_state_model [logical] scalar
%                            .has_initval            [logical] scalar
%                            .steady_cmd [logical]  scalar, the file runs the steady command
%                            .steady_options [char] the option group of that command
%                            .check_cmd  [logical]  scalar, the file runs the check command
%                            .skipped    [cell]     1×p, keywords that were skipped
%                            .macro      [struct]   what the macro pass found, see
%                                                   modfile.expand_macros
%
% EXAMPLES:
% mod = modfile.read('rbc.mod');
%
% REMARKS:
% - This function does no naming and no evaluation: it reports what the file says.
%   Associating equations with endogenous variables, evaluating the calibration and
%   emitting MATLAB is modfile.translate's job.
% - Statements that would change the model if dropped raise
%   modfile:read:unsupportedStatement; see modfile.statement_policy. Everything else
%   outside the imported subset is skipped with a modfile:read:ignoredStatement
%   warning, which Strict promotes to an error.
    arguments
        filename              (1,:) char {mustBeFile}
        options.Strict        (1,1) logical = false
        options.Macro         (1,1) logical = true
        options.Defines       struct = struct()
        options.IncludePaths  (1,:) cell = {}
        options.Force         double = zeros(0, 2)
        options.Branches      (1,1) logical = true
        options.Depth         (1,1) double {mustBeNonnegative, mustBeInteger} = 3
    end

    txt = fileread(filename);

    macroinfo = struct('defines', {cell(0,2)}, 'used', false, 'context', {{}}, ...
                       'conditionals', {struct('id', {}, 'nbranches', {}, 'conds', {}, 'taken', {}, 'position', {}, 'ancestors', {})});
    if options.Macro
        % The macro pass runs before the comments are stripped, as in Dynare: a directive
        % may sit inside a region a later stage would blank, and an included file brings
        % its own comments with it.
        [txt, macroinfo] = modfile.expand_macros(txt, filename, Defines=options.Defines, IncludePaths=options.IncludePaths, Force=options.Force);
    elseif contains(txt, '@#') || contains(txt, '@{')
        error('modfile:read:macroDisabled', '%s uses the macro language but Macro=false was given.', filename)
    else
        macroinfo.context = repmat({modfile.macro_frame()}, 1, numel(strsplit(txt, newline, 'CollapseDelimiters', false)));
    end

    txt = modfile.strip_comments(txt, filename);
    stmts = modfile.split_statements(txt, filename);

    mod = struct('filename', filename, ...
                 'endo', {cell(0,4)}, 'exo', {cell(0,4)}, 'params', {cell(0,4)}, ...
                 'calib', {cell(0,3)}, ...
                 'equations', {struct('expr', {}, 'lhs', {}, 'rhs', {}, 'tags', {}, 'line', {})}, ...
                 'locals', {struct('name', {}, 'expr', {}, 'line', {})}, ...
                 'steady', {struct('names', {}, 'expr', {}, 'line', {})}, ...
                 'initval', {cell(0,3)}, ...
                 'has_model', false, 'has_steady_state_model', false, 'has_initval', false, ...
                 'steady_cmd', false, 'steady_options', '', 'check_cmd', false, ...
                 'skipped', {{}}, 'macro', macroinfo);

    for i = 1:numel(stmts)
        s = stmts(i);
        key = lower(s.keyword);

        switch key
          case {'var', 'varexo', 'parameters'}
            if ~isempty(s.options)
                error('modfile:read:unsupportedStatement', '%s (line %u): the option group "(%s)" on a %s declaration is not supported: it rewrites the equations of the model.', filename, s.line, s.options, key)
            end
            rows = modfile.parse_declaration(s.rest, key, filename, s.line);
            switch key
              case 'var'
                mod.endo = [mod.endo; rows];
              case 'varexo'
                mod.exo = [mod.exo; rows];
              case 'parameters'
                mod.params = [mod.params; rows];
            end

          case 'model'
            if mod.has_model
                error('modfile:read:unsupportedStatement', '%s (line %u): a second model block is not supported.', filename, s.line)
            end
            if ~isempty(s.options)
                local_report(options.Strict, filename, s.line, 'modfile:read:ignoredStatement', 'the model options "(%s)" are solver hints and are ignored', s.options);
            end
            [mod.equations, mod.locals] = modfile.parse_model_block(s.body, filename, s.line);
            mod.has_model = true;

          case 'steady_state_model'
            mod.steady = modfile.parse_steady_state_model(s.body, filename, s.line);
            mod.has_steady_state_model = true;

          case 'initval'
            mod.initval = modfile.parse_initval(s.body, 'initval', filename, s.line);
            mod.has_initval = true;

          case 'steady'
            mod.steady_cmd = true;
            mod.steady_options = s.options;

          case 'check'
            mod.check_cmd = true;

          otherwise
            assignment = strtrim(s.rest);
            if strcmp(s.kind, 'statement') && ~isempty(regexp(assignment, '^=[^=]', 'once'))
                % A top-level assignment: the calibration of a parameter, or the value
                % of an exogenous variable used as a constant.
                mod.calib(end+1, :) = {s.keyword, strtrim(regexprep(strtrim(assignment(2:end)), '\s*\n\s*', ' ')), s.line}; %#ok<AGROW>
            else
                [policy, reason] = modfile.statement_policy(s.keyword);
                if strcmp(policy, 'error')
                    error('modfile:read:unsupportedStatement', '%s (line %u): "%s" is not supported because %s.', filename, s.line, s.keyword, reason)
                end
                mod.skipped{end+1} = s.keyword; %#ok<AGROW>
                local_report(options.Strict, filename, s.line, 'modfile:read:ignoredStatement', '"%s" is not needed to build the model and is ignored', s.keyword);
            end
        end
    end

    if ~mod.has_model
        error('modfile:read:missingModel', '%s: no model block found.', filename)
    end

    mod.branches = local_read_branches(filename, mod, options);
end

function branches = local_read_branches(filename, mod, options)
% Read the file again, once per branch no conditional took, so that the whole logic of
% the file reaches the translator and not only the path today's settings select.
%
% A branch that was not taken produces no text, so its statements are invisible to a
% single pass. Forcing the conditional onto that branch and reading again is what makes
% them available; the model itself still comes from the unforced read, so nothing here
% can change what was built.
%
% The cost is one extra read per branch, not one per combination: every other conditional
% keeps the selection it already had, and the ancestors are forced only as far as needed
% to reach the branch in question.
    branches = struct('id', {}, 'branch', {}, 'cond', {}, 'position', {}, 'mod', {});

    if ~options.Branches || ~options.Macro || options.Depth < 1
        return
    end

    for i = 1:numel(mod.macro.conditionals)
        c = mod.macro.conditionals(i);
        for b = 1:c.nbranches
            if b == c.taken
                continue
            end
            % Every conditional written with the same condition is forced together. A
            % flag usually guards several places at once, a declaration and the equation
            % that goes with it, and flipping only one of them would leave a model that
            % does not stand up. This mirrors what happens in the generated script, where
            % one MATLAB variable drives every if written from that condition.
            force = [c.ancestors; c.id, b];
            for j = 1:numel(mod.macro.conditionals)
                other = mod.macro.conditionals(j);
                if other.id ~= c.id && isequal(other.conds, c.conds) && other.nbranches >= b
                    force(end+1, :) = [other.id, b]; %#ok<AGROW>
                end
            end
            try
                % The variant explores its own conditionals too, so that a conditional
                % nested inside a branch that was not taken keeps its branches. Depth
                % bounds that recursion; each level costs one read per branch.
                variant = modfile.read(filename, Strict=false, Macro=true, ...
                                       Defines=options.Defines, IncludePaths=options.IncludePaths, ...
                                       Force=force, Branches=true, Depth=options.Depth-1);
            catch
                % A branch that does not stand on its own, typically because it declares a
                % variable whose equation lives elsewhere. The translator falls back to
                % emitting the branch that was taken, and says so.
                continue
            end
            branches(end+1) = struct('id', c.id, 'branch', b, 'cond', c.conds{b}, 'position', c.position, 'mod', variant); %#ok<AGROW>
        end
    end
end

function local_report(strict, filename, line, id, fmt, varargin)
% Warn about a skipped construct, or raise when the caller asked for Strict.
    msg = sprintf(fmt, varargin{:});
    if strict
        error(id, '%s (line %u): %s.', filename, line, msg)
    end
    modfile.warn(id, '%s (line %u): %s.', filename, line, msg);
end
