# Asynchronous behaviors

In JavaScript, it is not uncommon to have asynchronous functions, and those can
be difficult to work with. Fortunately, Scientist comes with a lot of support
for promises baked in. Just specify `experiment.async(true)` when setting up
your experiment:

```javascript
const permissionTest = (user, resource) => {
  return science('permission-test', (experiment) => {
    experiment.async(true);

    experiment.use(() => oldTest(user, resource));
    experiment.try(() => newTest(user, resource));
  });
};

// ...

permissionTest(user, resource)
.then((canView) => {
  // ...
})
```

Remember, the return value of `science` is just exactly what the control
returned. Since we returned a promise from `oldTest()`, we got a promise out of
`permissionTest()`. If a promise is rejected in async mode, then it is treated
the same as a thrown error for the purposes of comparison.

## Mapping and comparing

For asynchronous experiments, values are resolved before passing them to your
comparator. On the other hand, Scientist will *always* pass a promise to your
mapping function and will *assert* that you return a promise. While this seems
like an inconvenience, it exists to prevent mistakes like this:

```javascript
experiment.map((result) => result.key)
```

This does not work as you expect, since `result` is of type `Promise`, and this
code effectively maps all observations to `undefined`, which in turn makes them
all match the control. Here is a more full example:

```javascript
science('file stat', (experiment) => {
  experiment.async(true);
  experiment.use(() => open(file, 'r').then(fstat));
  experiment.try(() => stat(file));

  experiment.map((file) => {
    return file.then((stat) => stat.ino);
  });
});
```

You can find this example at [examples/fsStat.js](../examples/callbacks.js).

## Callbacks

There is currently no support planned for node-style callbacks in Scientist. If
you are using Node.js 0.12 or greater, you can create a wrapped version of
science to support callbacks.

An example of how that may be done can be found at
[examples/callbacks.js](../examples/callbacks.js).
