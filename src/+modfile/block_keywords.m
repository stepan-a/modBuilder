function names = block_keywords()
% Dynare keywords that open a block terminated by 'end;'.
%
% OUTPUTS:
% - names   [cell]   1×n array of row char arrays, lower-case block keywords
%
% REMARKS:
% - Only 'model', 'steady_state_model' and 'initval' carry information the reader
%   imports. The rest are listed so that split_statements folds them into a single
%   entry and their contents are never mistaken for top-level statements; what
%   happens to them afterwards is decided by the scope policy in modfile.read.
% - 'model_replace' and 'occbin_constraints' are recent additions to the Dynare
%   grammar; they are listed for the same skipping purpose.
    names = {'model', 'steady_state_model', 'initval', 'endval', 'histval', 'shocks', 'mshocks', 'estimated_params', 'estimated_params_init', 'estimated_params_bounds', 'observation_trends', 'optim_weights', 'osr_params_bounds', 'ramsey_constraints', 'verbatim', 'epilogue', 'homotopy_setup', 'conditional_forecast_paths', 'svar_identification', 'moment_calibration', 'irf_calibration', 'matched_moments', 'occbin_constraints', 'model_replace', 'shock_groups', 'init2shocks', 'filter_initial_state', 'generate_irfs', 'shock_decomposition_options'};
end
