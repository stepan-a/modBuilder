function [policy, reason] = statement_policy(keyword)
% Decide what the reader does with a .mod statement it does not import.
%
% INPUTS:
% - keyword   [char]   1×n array, the leading keyword of the statement
%
% OUTPUTS:
% - policy    [char]   'error' or 'ignore'
% - reason    [char]   for 'error', why the statement cannot be skipped; empty otherwise
%
% REMARKS:
% - Statements that change what the model IS cannot be dropped: skipping them would
%   build a different model and report success, which is worse than refusing to read
%   the file. Those return 'error'.
% - Everything else is computational or informational for the object modBuilder
%   builds, and is skipped. Real .mod files almost always end in a stoch_simul or an
%   estimation block, so refusing them would make the reader useless on the very
%   files it exists for. The caller decides whether to warn, and modfile.read's Strict
%   option turns those warnings into errors.
    arguments
        keyword (1,:) char
    end

    switch lower(keyword)
      case 'predetermined_variables'
        policy = 'error';
        reason = 'it reindexes the lags of every listed variable';
      case 'varexo_det'
        policy = 'error';
        reason = 'modBuilder has no deterministic-exogenous symbol class';
      case {'trend_var', 'log_trend_var'}
        policy = 'error';
        reason = 'trend variables rewrite the equations of the model';
      case 'heterogeneity_dimension'
        policy = 'error';
        reason = 'modBuilder has no heterogeneity dimension';
      case 'external_function'
        policy = 'error';
        reason = 'a user function call cannot be told apart from a lead or a lag when parsing an equation';
      case {'ramsey_model', 'ramsey_policy', 'discretionary_policy', 'planner_objective', 'ramsey_constraints'}
        policy = 'error';
        reason = 'optimal-policy statements augment the model with first-order conditions';
      case 'model_local_variable'
        policy = 'error';
        reason = 'declaring a model-local variable outside the model block is not supported; define it with # inside the block';
      otherwise
        policy = 'ignore';
        reason = '';
    end
end
