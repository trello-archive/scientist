_ = require('underscore')
EventEmitter = require('events').EventEmitter

Experiment = require('./experiment')

class Scientist extends EventEmitter
  constructor: ->
    @_sampler = _.constant(true)

  sample: (sampler) -> @_sampler = sampler

  science: (name, setup) ->
    experiment = new Experiment(name)
    setup(experiment)

    @emit('experiment', experiment)

    # Proxy events from experiments
    experiment.on('skip', EventEmitter::emit.bind(@, 'skip'))
    experiment.on('result', EventEmitter::emit.bind(@, 'result'))
    experiment.on('error', EventEmitter::emit.bind(@, 'error'))
    return experiment.run(@_sampler)

module.exports = Scientist
