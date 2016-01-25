_ = require('underscore')
sinon = require('sinon')

Measurement = require('../src/measurement')

time = require('./helpers/time')

describe "Measurement", ->
  beforeEach ->
    @measurement = Measurement.benchmark(->)
  describe ".benchmark()", ->
    it "runs a block and returns a new measurement", ->
      block = sinon.spy()
      measurement = Measurement.benchmark(block)

      block.should.be.calledOnce()
      measurement.should.be.instanceof(Measurement)

    it "captures the time elapsed", ->
      time (tick) ->
        measurement = Measurement.benchmark -> tick(10)
        measurement.elapsed.should.equal(10)

  describe "::remeasure()", ->
    it "calls the block and returns a new measurement", ->
      block = sinon.spy()
      remeasurement = @measurement.remeasure(block)

      block.should.be.calledOnce()
      remeasurement.should.be.instanceof(Measurement)
      remeasurement.should.not.equal(@measurement)

    it "extends the elapsed time to the end of the new block", ->
      time (tick) =>
        measurement = Measurement.benchmark -> tick(10)
        tick(10)
        remeasurement = measurement.remeasure -> tick(10)

        remeasurement.elapsed.should.equal(30)

  describe "::preserve()", ->
    it "calls the block and returns the same measurement", ->
      block = sinon.spy()
      remeasurement = @measurement.preserve(block)

      block.should.be.calledOnce()
      remeasurement.should.be.instanceof(Measurement)
      remeasurement.should.equal(@measurement)
