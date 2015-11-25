Promise = require('bluebird')
sinon = require('sinon')

Experiment = require('../src/experiment')
Observation = require('../src/observation')
Result = require('../src/result')

describe "Lib: Scientist: Result", ->
  beforeEach ->
    @experiment = new Experiment("test")
    @control = new Observation("control", (-> return 1), @experiment._options)
    @candidates = [
      new Observation("candidate0", (-> return 1), @experiment._options)
      new Observation("candidate1", (-> return 2), @experiment._options)
      new Observation("candidate2", (-> throw Error(1)), @experiment._options)
    ]

  describe "constructor", ->
    it "exposes the experiment, context, and observations", ->
      context = { a: {}, b: [] }
      @experiment.context(context)
      result = new Result(@experiment, @control, @candidates)

      result.should.have.properties
        experiment: @experiment
        context: context
        control: @control
        candidates: @candidates

    it "exposes an array of ignored observations", ->
      @experiment.ignore (control, candidate) ->
        candidate.value == 2
      result = new Result(@experiment, @control, @candidates)

      result.should.have.property('ignored').eql [@candidates[1]]

    it "exposes an array of matched observations", ->
      result = new Result(@experiment, @control, @candidates)

      result.should.have.property('matched').eql [@candidates[0]]

    it "exposes an array of mismatched observations", ->
      result = new Result(@experiment, @control, @candidates)

      result.should.have.property('mismatched').eql @candidates[1..2]

    it "removes ignored observations from matched and mismatched", ->
      spy = sinon.spy()
      @experiment.ignore -> true
      @experiment.compare(spy)

      result = new Result(@experiment, @control, @candidates)

      result.should.have.property('ignored').eql @candidates
      result.should.have.property('matched').eql []
      result.should.have.property('mismatched').eql []
      spy.should.not.be.called()
