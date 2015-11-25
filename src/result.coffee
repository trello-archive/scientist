_ = require('underscore')

class Result
  constructor: (experiment, control, candidates) ->
    @experiment = experiment
    @context = experiment.context()
    @control = control
    @candidates = candidates

    # Calculate ignored, matching, and mismatching candidates
    @ignored = _.select candidates, (candidate) -> control.ignores(candidate)
    comparable = _.difference(candidates, @ignored)
    @matched = _.select comparable, (candidate) -> control.matches(candidate)
    @mismatched = _.difference(comparable, @matched)

    # Immutable
    Object.freeze(@)

module.exports = Result
