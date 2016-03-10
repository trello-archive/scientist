_ = require('underscore')
Promise = require('bluebird')
sinon = require('sinon')
inspect = require('util').inspect

Observation = require('../src/observation')

time = require('./helpers/time')

describe "Observation", ->
  beforeEach ->
    @name = "test"
    @options =
      mapper: _.identity
      ignorers: []
      comparator: _.isEqual
      cleaner: _.identity

    # Two types of blocks
    @returning = (v) -> (-> return v)
    @throwing = (e) -> (-> throw e)

    # Some fixtures and corresponding convenience functions
    @value = {}
    @return = @returning(@value)

    @error = Error()
    @throw = @throwing(@error)

  describe "constructor", ->
    it "takes a behavior name, block, and options", ->
      observation = new Observation(@name, @return)

      observation.should.have.property('name', @name)

    it "exposes the start time", ->
      # Just freeze time
      time =>
        observation = new Observation(@name, @return)
        observation.should.have.property('startTime', new Date())

    it "exposes the duration", ->
      time (tick) =>
        observation = new Observation @name, -> tick(10)
        observation.should.have.property('duration', 0)

    describe "running the block", ->
      it "exposes returned results", ->
        observation = new Observation(@name, @return)

        observation.should.have.property('value').equal(@value)
        observation.should.not.have.property('error')

      it "exposes thrown errors", ->
        observation = new Observation(@name, @throw)

        observation.should.have.property('error').equal(@error)
        observation.should.not.have.property('value')

      it "only executes it once", ->
        block = sinon.spy()
        new Observation(@name, block)

        block.should.be.calledOnce()

  describe "::evaluation()", ->
    it "returns the value if one was returned from the block", ->
      observation = new Observation(@name, @return)
      evaluation = observation.evaluation()

      evaluation.should.equal(@value)

    it "throws the error if one was thrown from the block", ->
      (-> new Observation(@name, @throw).evaluation())
      .should.throw(@error)

    it "returns promises returned from the block without settling them", ->
      value = Promise.resolve()

      observation = new Observation(@name, _.constant(value))
      evaluation = observation.evaluation()

      # We should be receiving the exact promise itself
      evaluation.should.equal(value)

  describe "::settle()", ->
    it "returns a promise that resolves into an observation", ->
      observation = new Observation(@name, @return, @options)
      settled = observation.settle()

      settled.should.be.instanceOf(Promise)
      settled.should.eventually.be.instanceOf(Observation)
      settled.should.eventually.have.properties
        name: @name

    it "preserves synchronous return values", ->
      observation = new Observation(@name, @return, @options)
      settled = observation.settle()

      settled.should.eventually.have.property('value').equal(@value)

    it "preserves synchronous thrown errors", ->
      observation = new Observation(@name, @throw, @options)
      settled = observation.settle()

      settled.should.eventually.have.property('error').equal(@error)

    it "exposes asynchronous resolved values", ->
      observation = new Observation(@name, Promise.method(@return), @options)
      settled = observation.settle()

      settled.should.eventually.have.property('value').equal(@value)

    it "exposes asynchronous rejected errors", ->
      observation = new Observation(@name, Promise.method(@throw), @options)
      settled = observation.settle()

      settled.should.eventually.have.property('error').equal(@error)

    it "preserves start time", ->
      time (tick) =>
        observation = new Observation(@name, @return, @options)
        tick(10)
        settled = observation.settle()

        settled.should.eventually.have
        .property('startTime', observation.startTime)

    it "preserves start tuple", ->
      time (tick) =>
        observation = new Observation(@name, @return, @options)
        tick(10)
        settled = observation.settle()

        settled.should.eventually.have
        .property('_startTuple', observation._startTuple)

    it "computes total duration", ->
      time (tick) =>
        observation = new Observation(@name, (-> tick(10)), @options)
        tick(10)
        settled = observation.settle()

        # aboveOrEqual is here because the execution time varies
        settled.should.eventually.have
        .property('duration')
        .which.is.aboveOrEqual(0)

     it "does not call the block again", ->
       block = sinon.spy()
       observation = new Observation(@name, block, @options)

       observation.settle().then ->
         block.should.be.calledOnce()

  describe "::map()", ->
    it "takes a function and returns a new observation with a mapped value", ->
      observation = new Observation(@name, @return, @options)

      mapped = observation.map (value) =>
        value.should.equal(@value)
        return [@value]

      mapped.should.not.equal(observation)
      mapped.value.should.eql([@value])

    it "returns the same observation if the observation was an error", ->
      observation = new Observation(@name, @throw, @options)

      mapped = observation.map (value) -> [value]

      mapped.should.equal(observation)
      mapped.error.should.equal(@error)

    it "bubbles thrown errors in the mapping function", ->
      observation = new Observation(@name, @return, @options)

      (=> observation.map(@throw)).should.throw(@error)

  describe "::didReturn()", ->
    it "returns true if the block returned", ->
      observation = new Observation(@name, @return)
      observation.didReturn().should.be.true()

    it "returns false if the block threw", ->
      observation = new Observation(@name, @throw)
      observation.didReturn().should.be.false()

  describe "::ignores()", ->
    it "returns false for non-observations", ->
      a = new Observation(@name, @return, @options)

      a.ignores({ @value }).should.be.false()

    it "returns false if there are no ignorers", ->
      a = new Observation(@name, @return, @options)
      b = new Observation(@name, @return, @options)

      a.ignores(b).should.be.false()

    it "returns true if any ignorer predicates return true", ->
      a = new Observation(@name, @return, @options)
      b = new Observation(@name, @return, @options)

      @options.ignorers.push(_.constant(false), _.constant(false))
      a.ignores(b).should.be.false()

      @options.ignorers.push(_.constant(true))
      a.ignores(b).should.be.true()

    it "passes the two observations to each ignorer", ->
      spy = sinon.spy()
      a = new Observation(@name, @return, @options)
      b = new Observation(@name, @return, @options)

      @options.ignorers.push(spy)
      a.ignores(b)

      spy.should.be.calledWith(a, b)

  describe "::matches()", ->
    it "returns false for non-observations", ->
      a = new Observation(@name, @return, @options)

      a.matches({ @value }).should.be.false()

    it "returns false if both did not return or both did not fail", ->
      a = new Observation(@name, @return, @options)
      b = new Observation(@name, @throw, @options)

      a.matches(b).should.be.false()
      b.matches(a).should.be.false()

    it "uses the comparator for return values", ->
      a = new Observation(@name, @returning({ a: 1, b: 2 }), @options)
      b = new Observation(@name, @returning({ a: 1, b: 2 }), @options)
      c = new Observation(@name, @returning({ a: 1 }), @options)

      # strict
      @options.comparator = (a, b) -> a == b
      a.matches(b).should.be.false()
      a.matches(c).should.be.false()

      # fuzzy
      @options.comparator = _.isEqual
      a.matches(b).should.be.true()
      a.matches(c).should.be.false()

    it "compares names and messages for thrown errors", ->
      a = new Observation(@name, @throwing(Error("fail")), @options)
      b = new Observation(@name, @throwing(Error("fail")), @options)
      c = new Observation(@name, @throwing(Error("failed")), @options)
      d = new Observation(@name, @throwing(TypeError("fail")), @options)

      # Assert comparator is never called
      @options.comparator = ->
        throw Error("Comparator used; expected error comparison")

      a.matches(b).should.be.true()
      a.matches(c).should.be.false()
      a.matches(d).should.be.false()

  describe "::inspect()", ->
    it "stringifies error constructor and message", ->
      observation = new Observation(@name, @throwing(TypeError("fail")), @options)

      observation.inspect().should.equal """
        error: [TypeError] 'fail'
      """

    it "stringifies values using inspect", ->
      observation = new Observation(@name, @returning({ a: 1, b: "c" }), @options)

      observation.inspect().should.equal """
        value: { a: 1, b: 'c' }
      """

    it "forwards inspect options", ->
      observation = new Observation(@name, @returning({ a: 1, b: "c" }), @options)

      inspect(observation, depth: -1).should.equal """
        value: [Object]
      """

    it "cleans the value using the experiment", ->
      @options.cleaner = (value) -> _.keys(value)
      observation = new Observation(@name, @returning({ a: 0, b: "c" }), @options)

      observation.inspect().should.equal """
        value: [ 'a', 'b' ]
      """
