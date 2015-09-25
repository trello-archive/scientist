Promise = require('bluebird')

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

    it "exposes a matched array of observations", ->
      result = new Result(@experiment, @control, @candidates)

      result.should.have.property('matched').eql [@candidates[0]]

    it "exposes a mismatched array of observations", ->
      result = new Result(@experiment, @control, @candidates)

      result.should.have.property('mismatched').eql @candidates[1..2]
