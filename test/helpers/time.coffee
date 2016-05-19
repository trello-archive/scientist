Promise = require('bluebird')
sinon = require('sinon')

sandbox = ->
  Promise.resolve(sinon.sandbox.create())
  .disposer (sandbox) ->
    sandbox.restore()

# A more simple abstraction of sinon's clock-stubbing feature. Note that this
# *freezes* time for all code run within this context. Use the tick(ms)
# function provided to your callback to move time forward. Should work for all
# time-related functionality using Date.now() and setTimeout(...).
HOOKS = [
  'Date'
  'setTimeout'
  'clearTimeout'
  'setInterval'
  'clearInterval'
]

useFakeHrTime = (sandbox) ->
  ticked = 0

  sandbox.stub process, 'hrtime', (start) ->
    now = [Math.floor(ticked / 1e3), (ticked % 1e3) * 1e6]

    if start
      [now[0] - start[0], now[1] - start[1]]
    else
      now

  return tick: (ms) -> ticked += ms

useFakeTimers = (sandbox, time, hooks...) ->
  sinonClock = sandbox.useFakeTimers(time, hooks...)
  hrClock = useFakeHrTime(sandbox)

  return tick: (ms) ->
    sinonClock.tick(ms)
    hrClock.tick(ms)

module.exports = (callback) ->
  Promise.using sandbox(), (s) ->
    # Resolve/then will let the timeout execute first before the fake timers
    # come into play.
    Promise.resolve().then ->
      # We intentionally omit setImmediate/clearImmediate because freezing
      # those breaks a lot of request-based integration testing.
      clock = useFakeTimers(s, Date.now(), HOOKS...)
      Promise.try -> callback(clock.tick)
    # We are forcing a short timeout of 1000ms so that we can clean up the
    # timers before the next test if this does time out.
    .timeout(1000)
