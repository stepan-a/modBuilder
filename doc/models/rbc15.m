% Derive the steady state of the small RBC model instead of writing it.
rbc14                                    % the model, without steady state

model.steady('a', '0');                  % the only level known a priori
model.calibrate('h', 1/3, 'theta');      % fix hours, free theta

b = model.steady_plan(Match=true, PropagateKnown=true);
model.print_steady_plan(b, Match=true, PropagateKnown=true);

model = model.apply_steady_plan(b);
model.write('rbc15', steady_state_model=true);
