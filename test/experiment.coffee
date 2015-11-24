_ = require('underscore')
Promise = require('bluebird')
sinon = require('sinon')

Experiment = require('../src/experiment')
Result = require('../src/result')

eventToPromise = (emitter, event) ->
  new Promise (resolve, reject) ->
    emitter.once event, (args...) ->
      resolve(args)

describe "Experiment", ->
  beforeEach ->
    @experiment = new Experiment("test")
    @true = _.constant(true)
    @false = _.constant(false)

  describe "constructor", ->
    it "takes and exposes a name", ->
      @experiment.should.have.property('name', "test")

  describe "::use()", ->
    it "calls try with the special name 'control'", ->
      block = (->)
      @experiment.use(block)
      @experiment._behaviors.should.have.property('control', block)

  describe "::try()", ->
    it "takes an optional name and block", ->
      block1 = (->)
      block2 = (->)
      @experiment.try(block1)
      @experiment.try("test", block2)

      @experiment._behaviors.should.have.properties
        candidate: block1
        test: block2

    it "throws if you do not provide a block", ->
      (=> @experiment.try(null)).should.throw(/Invalid block/)

    it "throws if the name is not unique", ->
      @experiment.try(_.noop)
      (=> @experiment.try(_.noop)).should.throw(/Duplicate behavior/)

  describe "::run()", ->
    beforeEach ->
      @control = sinon.stub()
      @candidate = sinon.stub()
      @experiment.use(@control)
      @experiment.try(@candidate)

    it "requires a 'control' behavior", ->
      experiment = new Experiment("test")
      (-> experiment.run(@true)).should.throw(/Expected control behavior/)

    it "passes the name to the sampler", ->
      sampler = sinon.spy()
      @experiment.run(sampler)
      sampler.should.be.calledWith("test")

    describe "when the experiment is skipped", ->
      it "does not run the candidates", ->
        @experiment.run(@false)

        @candidate.should.not.be.called()

      it "returns or throws the control result", ->
        value = {}
        @control.returns(value)
        @experiment.run(@false).should.equal(value)

        error = Error()
        @control.throws(error)
        (=> @experiment.run(@false)).should.throw(error)

    it "runs all the behaviors", ->
      @experiment.run(@true)

      @control.should.be.calledOnce()
      @candidate.should.be.calledOnce()

    it "randomizes the order of the behaviors", ->
      results = []
      # They say you never shuffle the same deck twice...
      _.times 52, (i) =>
        @experiment.try i, -> results.push(i)

      @experiment.run(@true)
      results.should.not.eql([0..51])

    it "returns the exact result returned by the control", ->
      value = {}
      @control.returns(value)

      @experiment.run(@true).should.equal(value)

    it "throws any errors thrown by the control", ->
      error = Error()
      @control.throws(error)

      (=> @experiment.run(@true)).should.throw(error)

  describe "event: skip", ->
    it "is emitted if there are no candidates defined", ->
      capture = eventToPromise(@experiment, 'skip')
      @experiment.use -> return 1

      @experiment.run(@true)

      capture.should.eventually.eql([@experiment, "No behaviors defined"])

    it "is emitted if the sampler returns falsy", ->
      capture = eventToPromise(@experiment, 'skip')
      @experiment.use -> return 1
      @experiment.try -> return 1

      @experiment.run(@false)

      capture.should.eventually.eql([@experiment, "Sampler returned false"])

    it "is emitted if the skipper returns truthy", ->
      capture = eventToPromise(@experiment, 'skip')
      @experiment.use -> return 1
      @experiment.try -> return 1
      @experiment.skipWhen -> true

      @experiment.run(@true)

      capture.should.eventually.eql([@experiment, "Skipper returned true"])

  describe "event: result", ->
    it "is emitted with a result after a successful run", ->
      @experiment.use -> return 1
      @experiment.try -> return 1
      @experiment.run(@true)

      eventToPromise(@experiment, 'result')
      .spread (result) =>
        result.should.be.instanceOf(Result)
        result.experiment.should.equal(@experiment)

    it "is emitted with a result even if the block throws", ->
      @experiment.use -> throw Error()
      @experiment.try -> throw Error()
      # This is going to throw to reproduce the effect of the use
      try @experiment.run(@true)

      eventToPromise(@experiment, 'result').should.be.fulfilled()

    it "emits settled observations for the results if async option was enabled", ->
      value = {}
      @experiment.async(true)
      @experiment.use -> Promise.resolve(value)
      @experiment.try -> Promise.reject(value)
      @experiment.run(@true)

      eventToPromise(@experiment, 'result')
      .spread (result) =>
        result.control.value.should.equal(value)
        result.candidates[0].error.should.equal(value)

    it "emits observations with transformed values using the mapper option", ->
      @experiment.use -> 1
      @experiment.try -> throw 1
      @experiment.map (val) -> [val]
      @experiment.run(@true)

      eventToPromise(@experiment, 'result')
      .spread (result) =>
        result.control.value.should.eql([1])
        result.candidates[0].error.should.eql(1)

  describe "event: error", ->
    beforeEach ->
      @experiment.use -> return 1
      @experiment.try -> return 2

    it "is emitted if the sampler fails", ->
      capture = eventToPromise(@experiment, 'error')

      @experiment.run -> throw Error("forced")

      capture.spread (error) =>
        error.message.should.match(/^Sampler failed: forced/)
        error.experiment.should.equal(@experiment)

    it "is emitted if the skipper fails", ->
      capture = eventToPromise(@experiment, 'error')

      @experiment.skipWhen -> throw Error("forced")
      @experiment.run(@true)

      capture.spread (error) =>
        error.message.should.match(/^Skipper failed: forced/)
        error.experiment.should.equal(@experiment)

    it "is emitted if the skip event handler fails", ->
      capture = eventToPromise(@experiment, 'error')

      @experiment.on 'skip', -> throw Error("forced")
      @experiment.run(@false)

      capture.spread (error) =>
        error.message.should.match(/^Skip handler failed: forced/)
        error.experiment.should.equal(@experiment)

    it "is emitted if the map fails", ->
      capture = eventToPromise(@experiment, 'error')

      @experiment.map -> throw Error("forced")
      @experiment.run(@true)

      capture.spread (error) =>
        error.message.should.match(/^Map failed: forced/)
        error.experiment.should.equal(@experiment)

    it "is emitted if the comparison fails", ->
      capture = eventToPromise(@experiment, 'error')

      @experiment.compare -> throw Error("forced")
      @experiment.run(@true)

      capture.spread (error) =>
        error.message.should.match(/^Comparison failed: forced/)
        error.experiment.should.equal(@experiment)

    it "is emitted if the result event handler fails", ->
      capture = eventToPromise(@experiment, 'error')

      @experiment.on 'result', -> throw Error("forced")
      @experiment.run(@true)

      capture.spread (error) =>
        error.message.should.match(/^Result handler failed: forced/)
        error.experiment.should.equal(@experiment)

  describe "::context()", ->
    it "merges an object into the current context", ->
      @experiment.context({ a: 1 })
      @experiment._options.context.should.eql({ a: 1 })
      @experiment.context({ b: 2 })
      @experiment._options.context.should.eql({ a: 1, b: 2 })

    it "makes no changes for an undefined value", ->
      @experiment.context({ a: 1 })
      @experiment._options.context.should.eql({ a: 1 })
      @experiment.context()
      @experiment._options.context.should.eql({ a: 1 })

    it "returns the new context", ->
      @experiment.context({ a: 1 }).should.eql({ a: 1 })
      @experiment.context().should.eql({ a: 1 })

  describe "::async()", ->
    it "requires a boolean", ->
      (=> @experiment.async(1)).should.throw(/Expected boolean, got 1/)

    it "sets the internal async flag", ->
      @experiment.async(true)
      @experiment._options.async.should.be.true()

  describe "::skipWhen()", ->
    it "requires a function", ->
      (=> @experiment.skipWhen(1)).should.throw(/Expected function, got 1/)

    it "sets the internal skipper function", ->
      skipper = (->)
      @experiment.skipWhen(skipper)
      @experiment._options.skipper.should.equal(skipper)

  describe "::map()", ->
    it "requires a function", ->
      (=> @experiment.map(1)).should.throw(/Expected function, got 1/)

    it "sets the internal mapper function", ->
      mapper = (->)
      @experiment.map(mapper)
      @experiment._options.mapper.should.equal(mapper)

  describe "::ignore()", ->
    it "requires a function", ->
      (=> @experiment.ignore(1)).should.throw(/Expected function, got 1/)

    it "adds an internal ignorer function", ->
      ignorer = (->)
      @experiment.ignore(ignorer)
      @experiment.ignore(ignorer)
      @experiment._options.ignorers.should.eql([ignorer, ignorer])

  describe "::compare()", ->
    it "requires a function", ->
      (=> @experiment.compare(1)).should.throw(/Expected function, got 1/)

    it "sets the internal comparator function", ->
      comparator = (->)
      @experiment.compare(comparator)
      @experiment._options.comparator.should.equal(comparator)

  describe "::clean()", ->
    it "requires a function", ->
      (=> @experiment.clean(1)).should.throw(/Expected function, got 1/)

    it "sets the internal cleaner function", ->
      cleaner = (->)
      @experiment.clean(cleaner)
      @experiment._options.cleaner.should.equal(cleaner)

  describe "mapping", ->
    beforeEach ->
      @result = Promise.race [
        eventToPromise(@experiment, 'result')
        eventToPromise(@experiment, 'error').spread (err) -> throw err
      ]
      return

    it "always provides a promise argument if async is set to true", ->
      @experiment.async(true)
      @experiment.use -> 1
      @experiment.try -> 2
      mapper = sinon.spy (val) ->
        val.should.be.instanceOf(Promise)
        return val
      @experiment.map(mapper)

      @experiment.run(@true)

      @result.should.be.fulfilled()
      .then -> mapper.should.be.calledTwice()

    it "always expects a promise return value if async is set to true", ->
      @experiment.async(true)
      @experiment.use -> Promise.resolve({ a: 1 })
      @experiment.try -> Promise.resolve({ a: 2 })
      # A common mistake: val is a promise, not a value
      @experiment.map (val) -> val.a

      @experiment.run(@true)

      @result.should.be.rejectedWith(/Result of async mapping must be a thenable/)
