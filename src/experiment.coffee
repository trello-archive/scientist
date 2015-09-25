_ = require('underscore')
EventEmitter = require('events').EventEmitter
Promise = require('bluebird')

Observation = require('./observation')
Result = require('./result')

expects = (type, wrapped) -> (arg) ->
  if typeof arg != type
    throw TypeError("Expected #{ type }, got #{ arg }")
  wrapped.call(@, arg)

class Experiment extends EventEmitter
  constructor: (name) ->
    super()
    @name = name
    @_behaviors = {}

    @_options =
      context: {}
      async: false
      mapper: _.identity
      comparator: _.isEqual
      cleaner: _.identity

  # Defines the control block
  use: (block) ->
    @try('control', block)

  # Defines a candidate block
  try: ([name]..., block) ->
    name ?= 'candidate'

    if name of @_behaviors
      throw Error("Duplicate behavior: " + name)

    if !_.isFunction(block)
      throw TypeError("Invalid block: expected function, got #{ block }")

    @_behaviors[name] = block

  # Runs the experiment based on a sampler function
  run: (sampler) ->
    # You always must at least provide a control
    if 'control' !of @_behaviors
      throw Error("Expected control behavior to be defined")

    # Experiments will not be run if either you did not define more than the
    # control or if the sampler function did not return true.
    shouldRun = @_try "Sampler", =>
      _.size(@_behaviors) > 1 && sampler(@name)

    # In the case of a skipped experiment, just evaluate the control.
    if !shouldRun
      @_try "Skip handler", =>
        @emit('skip', @)
      return @_behaviors.control()

    # Otherwise, shuffle the order and execute each one at a time.
    observations = _(@_behaviors)
    .chain()
    .keys()
    .shuffle()
    .map (key) => new Observation(key, @_behaviors[key], @_options)
    .value()

    # We separate the control from the candidates.
    control = _.find(observations, name: 'control')
    candidates = _.without(observations, control)

    # Results are compiled and emitted asynchronously.
    @_sendResults([control].concat(candidates))

    # Throws or returns the resulting value of the control
    return control.evaluation()

  # A completely asynchronous function that takes observations in the form of
  # [control] + [candidates...], uses the internal mapper to transform them,
  # tries to construct a result, and sends the result out. Handles all errors
  # in user-defined functions via the error event.
  _sendResults: (observations) ->
    mapped = @_try "Map", =>
      _.invoke(observations, 'map', @_options.mapper)

    return unless mapped

    Promise.map(mapped, @_settle.bind(@))
    .spread (control, candidates...) =>
      result = @_try "Comparison", =>
        new Result(@, control, candidates)

      return unless result

      @_try "Result handler", =>
        @emit('result', result)
    .done()

  # Update and return the context (default: empty object)
  context: (context) -> _.extend(@_options.context, context)
  # Set the async flag (default: false)
  async: expects 'boolean', (async) -> @_options.async = async
  # Set the mapper function (default: identity function)
  map: expects 'function', (mapper) -> @_options.mapper = mapper
  # Set the comparator function (default: deep equality)
  compare: expects 'function', (comparator) -> @_options.comparator = comparator
  # Set the cleaner function (default: identity function)
  clean: expects 'function', (cleaner) -> @_options.cleaner = cleaner

  # A try/catch with a built-in error handler
  _try: (operation, block) ->
    try
      return block()
    catch err
      @emit('error', @_decorateError(err, operation + " failed"))
      return null

  # Takes an observation and returns a settled one based on the async argument
  _settle: (observation) ->
    if @_options.async
      observation.settle()
    else
      observation

  # Mutate the error by prepending the message with a prefix and adding some
  # contextual information. This is done so that the stack trace is left
  # unaltered.
  _decorateError: (err, prefix) ->
    err.message = "#{ prefix }: #{ err.message }"
    err.experiment = @
    err.context = @context()
    return err

module.exports = Experiment
