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
      skipper: _.constant(false)
      mapper: _.identity
      ignorers: []
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

    # Experiments will not be run if any of the following are true:
    # 1. You did not define more than the control
    hasNoBehaviors = _.size(@_behaviors) < 2
    # 2. The sampler function did not return truthy
    shouldNotSample = @_try "Sampler", => !sampler(@name)
    # 3. The skipper function did return truthy
    shouldSkip = @_try "Skipper", => @_options.skipper()

    skipReason = switch
      when hasNoBehaviors then "No behaviors defined"
      when shouldNotSample then "Sampler returned false"
      when shouldSkip then "Skipper returned true"

    # In the case of a skipped experiment, just evaluate the control.
    if skipReason
      @_try "Skip handler", =>
        @emit('skip', @, skipReason)
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
      _.invoke(observations, 'map', @_mapper.bind(@))

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
  # Sets the skipper function (default: const false)
  skipWhen: expects 'function', (skipper) -> @_options.skipper = skipper
  # Set the mapper function (default: identity function)
  map: expects 'function', (mapper) -> @_options.mapper = mapper
  # Adds an ignorer function (default: none)
  ignore: expects 'function', (ignorer) -> @_options.ignorers.push(ignorer)
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

  # Wraps the options mapper to force the value to be a promise both before and
  # after the mapping if async is toggled on
  _mapper: (val) ->
    if @_options.async
      result = @_options.mapper(Promise.resolve(val))
      if !_.isFunction(result?.then)
        throw Error("Result of async mapping must be a thenable, got #{ result }")
      return result
    else
      @_options.mapper(val)

  # Mutate the error by prepending the message with a prefix and adding some
  # contextual information. This is done so that the stack trace is left
  # unaltered.
  _decorateError: (err, prefix) ->
    err.message = "#{ prefix }: #{ err.message }"
    err.experiment = @
    err.context = @context()
    return err

module.exports = Experiment
