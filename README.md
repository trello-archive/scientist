# Scientist

## Table of contents

* [API Documentation](./docs/api)
* [How it works](#how-it-works)
* [Getting started](#getting-started)
* [Errors in behaviors](#errors-in-behaviors)
* [Asynchronous behaviors](#asynchronous-behaviors)
* [Customizing your experiment](#customizing-your-experiment)
* [Why CoffeeScript?](#why-coffeescript)

## How it works

So you just refactored a swath of code and all tests pass. You feel completely
confident that this can go to production. Right? In reality, not so much. Be it
poor test coverage or just that the refactored code is very critical, sometimes
you need more reassurance.

Scientist lets you run your refactored code alongside the actual code, comparing
the outputs and logging when it did not return as expected. It's heavily based
on GitHub's [Scientist](https://github.com/github/scientist) gem. Let's walk
through an example. Start with this code:

```javascript
const sumList = (arr) => {
  let sum = 0;
  for (var i of arr) {
    sum += i;
  }
  return sum;
};
```

And let's refactor it as so:

```javascript
const sumList = (arr) => {
  return _.reduce(arr, (sum, i) => sum + i);
};
```

To do science, all you need to do is replace the original function with a
science wrapper that uses both functions:

```javascript
const sumList = (arr) => {
  return science('sum-list', (experiment) => {
    experiment.use(() => sumListOld(arr));
    experiment.try(() => sumListNew(arr));
  });
};
```

And that's it. The `science` function takes a string to identify the experiment
by and passes an `experiment` object to a function that you can use to set up
your experiment. We call `use` to define what our *control behavior* is --
that's also the value that is returned from the original `science` call, which
makes this a drop-in replacement. The `try` function can be used to define one
or more candidates to compare. So what happens if we do this:

```javascript
sumList([1, 2, 3]);
// -> 6
// Experiment candidate matched the control
```

But there's also a bug in our refactored code. Science logs that as appropriate,
but still returns the old value that we know works.

```javascript
sumList([]);
// -> 0
// Experiment candidate did not match the control
//   expected value: 0
//   received value: undefined
```
You can find this implemented in [examples/basic.js](examples/basic.js).

## Getting started

Above we just used a simple `science()` function to run an experiment. If you're
just looking to play around, you can get the same function with
`require('scientist/console')`. If you examine `console.js`, you'll notice that
this is a very simple implementation of the `Scientist` class, which is exposed
through a normal `require('scientist')` call.

The recommended usage is to create a file specific to your application and
export the `science` method bound to a fully set-up `Scientist` instance.

```javascript
const Scientist = require('./index');

const scientist = new Scientist();

scientist.on('skip', function (experiment) { /* ... */ });
scientist.on('result', function (result) { /* ... */ });
scientist.on('error', function (err) { /* ... */ });

module.exports = scientist.science.bind(scientist);
```

Then you can rely on your own internal logging and metrics tools to do science.

## Errors in behaviors

Scientist has built-in support for handling errors thrown by any of your
behaviors.

```javascript
science('throwing errors', (experiment) => {
  experiment.use(() => {
    throw Error(msg)
  });
  experiment.try("with-new", () => {
    throw new Error(msg)
  });
  experiment.try("as-type-error", () => {
    throw TypeError(msg)
  });
});

error("An error occured!");
// Experiment candidate matched the control
// Experiment candidate did not match the control
//   expected: error: [Error] 'An error occured!'
//   received: error: [TypeError] 'An error occured!'
```

In this case, the call to `science()` is actually *throwing* the same error that
the control function threw, but *after* testing the other functions and readying
the logging. The criteria for matching errors is based on the constructor and
message.

You can find this full example at [examples/errors.js](examples/error.js).

## Asynchronous behaviors

See [docs/async.md](docs/async.md).

## Customizing your experiment

There are several functions you can use to configure science:

* [`context`]: Record information to give context to results
* [`async`]: Turn async mode on
* [`skipWhen`]: Determine whether the experiment should be skipped
* [`map`]: Change values for more simple comparison and logging
* [`ignore`]: Throw away certain observations
* [`compare`]: Decide whether two observations match
* [`clean`]: Prepare data for logging

[`context`]: docs/api.md#contextobject-ctx---object
[`async`]: docs/api.md#asyncboolean-isasync
[`skipWhen`]: docs/api.md#skipwhenfunction-skipper
[`map`]: docs/api.md#mapfunctionany-observedvalue-mapper
[`ignore`]: docs/api.md#ignorefunctionobservation-control-observation-candidate-ignorer
[`compare`]: docs/api.md#comparefunctionany-controlvalue-any-candidatevalue-comparator
[`clean`]: docs/api.md#cleanfunctionany-observedvalue-cleaner

Because of the first-class promise support, the `compare` and `clean` functions
will take values after they are settled. `map` happens synchronously and may
also return a promise, which could be resolved.

If you want to think about the flow of data in a pipeline, it looks like this:

1. Block is called and the value or error is saved as an observation
2. `map()` is applied to the value
3. Promises are settled if `async` was set to `true`
4. The `Result` object is instantiated and observations are passed to
   `compare()`
5. The consumer may call `inspect()` on an observation, which applies
   `clean()`

### Why CoffeeScript?

This project started out internally at Trello and only later was spun off into a
separate module. As such, it was written using the language, dependencies, and
style of the Trello codebase. The code is hopefully simple enough to grok such
that the language choice does not deter contributors.
