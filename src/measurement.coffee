class Stopwatch
  constructor: -> @reset()

  reset: ->
    @_start = process.hrtime()

  time: ->
    @_hrToMs(process.hrtime(@_start))

  _hrToMs: ([seconds, nanoseconds]) ->
    Math.round(seconds * 1e3 + nanoseconds / 1e6)

class Measurement
  constructor: (stopwatch) ->
    @_stopwatch = stopwatch
    @elapsed = stopwatch.time()

    # Immutable
    Object.freeze(@)

  # A new measurement from no point in time
  @benchmark: (block) ->
    stopwatch = new Stopwatch()
    block()
    new Measurement(stopwatch)

  # Extend an old measurement through the execution of the new block
  remeasure: (block) ->
    block()
    new Measurement(@_stopwatch)

  # Run the new block and return the same measurement
  preserve: (block) ->
    block()
    return @

module.exports = Measurement
