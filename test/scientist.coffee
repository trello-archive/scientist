_ = require('underscore')
Promise = require('bluebird')
sinon = require('sinon')

Scientist = require('../src/scientist')

describe "Scientist", ->
  beforeEach ->
    @scientist = new Scientist()

  describe "::science()", ->
    it "sets up and runs an experiment", ->
      value = {}
      setup = (experiment) ->
        experiment.use(_.constant(value))

      @scientist.science("test", setup).should.equal(value)

    it "proxies result events from the experiment onto itself", ->
      new Promise (resolve, reject) =>
        @scientist.on('result', resolve)
        @scientist.science "test", (e) ->
          e.use(_.noop)
          e.try(_.noop)

    it "proxies error events from the experiment onto itself", ->
      new Promise (resolve, reject) =>
        @scientist.on('error', resolve)
        @scientist.science "test", (e) ->
          e.map -> throw Error()
          e.use(_.noop)
          e.try(_.noop)

    it "uses the configured sampler for the experiment", ->
      control = sinon.spy()
      candidate = sinon.spy()

      @scientist.sample(_.constant(false))
      @scientist.science "test", (e) ->
        e.use(control)
        e.try(candidate)

      control.should.be.calledOnce()
      candidate.should.not.be.called()

  describe "::sample()", ->
    it "takes a function to use as the sampler", ->
      sampler = (->)
      @scientist.sample(sampler)

      @scientist._sampler.should.equal(sampler)
