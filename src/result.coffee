_ = require('underscore')

class Result
  constructor: (experiment, control, candidates) ->
    @experiment = experiment
    @context = experiment.context()
    @control = control
    @candidates = candidates

    # Calculate matching and mismatching candidates
    @matched = _.filter @candidates, (candidate) =>
      @control.matches(candidate)
    @mismatched = _.difference(candidates, @matched)

    # Immutable
    Object.freeze(@)

module.exports = Result
