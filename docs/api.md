# API Documentation

## `Scientist`

### `#sample(function(String name) sampler)`

Takes a `sampler` function that should accept a `String` for an experiment name
and return a `Boolean` to determine whether that experiment should be run or
not.

### `#science(String name, function(Experiment e) setup) -> any`

Takes a `name` string and `setup` function to create a new experiment. The setup
function will be invoked with a single `Experiment` argument. Returns the value
returned by the control behavior.

### `event: 'experiment', (Experiment e) `

Fires when a new experiment is started.

### `event: 'skip'`
### `event: 'result'`
### `event: 'error'`

All experiments created through this scientist object will have their events
emitted through this.

## `Experiment`

### `#name`

The name given to identify the experiment.

### `#use(function() block)`

Syntactic sugar for `#try('control', block)`. The `'control'` name implies it is
the behavior that the other behaviors are tested against.

### `#try(?String name, function() block)`

Define a new behavior to perform science on. The `name` string defaults to
`'candidate'` and must be unique if defining more than one non-control behavior.
The block is the behavior to execute to get a result.

### `#context(Object ctx) -> Object`

If given, merges the `ctx` into the current context. Always returns the current
context.

Default: empty object (`{}`)

### `#async(Boolean isAsync)`

Declare the current experiment as any asynchronous experiment. See [async][1]
for more detail.

Default: synchronous (`false`)

### `#skipWhen(function() skipper)`

Declare a function that returns true if the experiment should be skipped.

Default: never (`() => false`)

### `#map(function(any observedValue) mapper)`

Declare the mapping function that takes a result value and returns a new form of
it. This resulting value is used for comparison and in the result. When
operating in [async mode][1], the mapping function is *always* called with a
`Promise` and the return value *must* also be a promise.

Default: identity function (`(a) => a`)

### `#ignore(function(Observation control, Observation candidate) ignorer)`

Declare an ignorer function that tests a control and candidate observation and
returns `true` if they should not be compared and the result simply ignored.
Unlike most experiment configuration, multiple calls to this function will add
multiple ignorers such that if *any* of them return `true`, the comparison is
skipped.

Default: no ignorers (`[]`)

### `#compare(function(any controlValue, any candidateValue) comparator)`

Declare the comparator to examine the values of the control and another
candidate and return `true` if they should be considered equal. This only works
with returned or resolved values; there is currently no way to compare thrown or
rejected values.

Default: deep object equality ([`_.isEqual`](http://underscorejs.org/#isEqual))

### `#clean(function(any observedValue) cleaner)`

Declare the cleaning function to use when calling `inspect()` on an
`Observation` that returned or resolved a value. There is currently no way to
compare thrown or rejected values.

Default: identity function (`(a) => a`)

### `event: 'skip', (Experiment e)`

Fires when an experiment is skipped. This happens when one of the following is
true:

1. There are no candidates defined
2. The sampler function configured on the scientist returns false
3. The skipping function configured on the experiment returns true

### `event: 'result', (Result r)`

Fires when all behaviors have been completed and compared.

### `event: 'error', (Error e)`

Fires when any user-provided configuration function or event handler throws an
error. This includes the mapping function, comparator function, etc.

The error object provided will have `experiment` and `context` properties.

## `Observation`

### `#didReturn() -> Boolean`

Returns `true` if the block returned or resolved, `false` if the block threw or
rejected.

### `#value`

The value that was returned or resolved by the block.

### `#error`

The error that was thrown or rejected by the block.

### `#startTime`

A `Date` value that represents when the observation was started.

### `#duration`

An `Integer` value in milliseconds that represents the time between when the
observation was started and when it was finished. In [async mode][1], this also
includes the time it took to resolve.

### `#inspect() -> String`

Returns a string representation of the cleaned value or error for printing or
logging. Follows Node.js' [`util.inspect()`][2] conventions.

[2]: https://nodejs.org/api/util.html#util_custom_inspect_function_on_objects

## `Result`

### `#experiment`

The experiment that produced the result

### `#context`

The context of the experiment

### `#control`

The single control observation

### `#candidates`

An array of candidate observations

### `#ignored`

An array of candidate observations that were ignored

### `#matched`

An array of candidate observations that did match the control observation

### `#mismatched`

An array of candidate observations that did not match the control observation

[1]: (./async.md)
