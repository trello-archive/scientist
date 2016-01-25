_ = require('underscore')
Promise = require('bluebird')

# Stringification is done with node's inspect with default recursion, and it
# is also smart enough to handle cyclical references, which JSON.stringify
# won't do.
inspect = require('util').inspect

Measurement = require('./measurement')

class Observation
  @withMeasurement: (measure, args...) ->
    mixin = _.create(@prototype, { measure })
    observation = _.create(mixin)
    @apply(observation, args)
    return observation

  constructor: (name, block, options={}) ->
    @name = name
    @_options = options

    # DEPRECATED: this property is not terribly useful and will be removed in
    # 2.x.
    @startTime = options.startTime ? new Date()

    @_time = @measure =>
      # Runs the block on construction
      try
        @value = block()
      catch error
        @error = error

    @duration = @_time.elapsed

    # Immutable
    Object.freeze(@)

  measure: Measurement.benchmark

  # The evaluation of the observation "replays" the effect of the block and
  # either returns the value or throws the error.
  evaluation: ->
    if @didReturn()
      return @value
    else
      throw @error

  # Settling the observation returns a promise of a new observation, but values
  # of resolved or rejected promises are settled to values or errors. The start
  # time is preserved so that the duration reflects the time spent running and
  # settling.
  settle: ->
    Promise.try(@evaluation.bind(@))
    .reflect()
    .then (inspection) =>
      if inspection.isFulfilled()
        -> return inspection.value()
      else
        -> throw inspection.reason()
    .then (block) =>
      Observation.withMeasurement(@_time.remeasure.bind(@_time), @name, block,
        _.defaults({ @startTime }, @_options))

  # Mapping an observation returns a new observation with the original value
  # fed through a mapping function. If the block was observed to have thrown,
  # the same observation is returned.
  map: (f) ->
    if @didReturn()
      block = _.constant(f(@value))
      Observation.withMeasurement(@_time.preserve.bind(@_time), @name, block,
        _.defaults({ @startTime }, @_options))
    else
      @

  # True if the block returned; false if it threw
  didReturn: -> !@error?

  # Returns true if the other observation is allowed to be compared to this
  # one using the ignorer options as a set of filters. If any return true, the
  # comparison is aborted.
  ignores: (other) ->
    if other !instanceof Observation
      return false

    if _.isEmpty(@_options.ignorers)
      return false

    _.any(@_options.ignorers, (predicate) => predicate(@, other))

  # Returns true if the other observation matches this one. In order for
  # observations to match, they most have both thrown or returned, and the
  # values or errors should match based on supplied or built-in criteria.
  matches: (other) ->
    if other !instanceof Observation
      return false

    # Both returned
    if @didReturn() && other.didReturn()
      return Boolean(@_options.comparator(@value, other.value))

    # Both threw
    if !@didReturn() && !other.didReturn()
      return @_compareErrors(@error, other.error)

    # Mixed returns and throws
    return false

  # Our built-in error comparator only checks the constructor and message, as
  # stack is unreliable and there is typically no more information.
  _compareErrors: (a, b) ->
    (a.constructor == b.constructor) && _.isEqual(a.message, b.message)

  # Returns a string for logging purposes. Uses the defined cleaner for
  # returned values.
  inspect: (depth, options) ->
    if @didReturn()
      "value: #{ inspect(@_options.cleaner(@value), options) }"
    else
      "error: [#{ @error.constructor?.name }] #{ inspect(@error.message, options) }"

module.exports = Observation
