const science = require('../console');

const error = (msg) => {
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
};

try {
  error("An error occured!");
} catch (err) {
  console.log("Caught error:", err);
}
