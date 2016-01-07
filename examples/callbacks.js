const fs = require('fs');
const science = require('../console');

// Define this wrapper once and export it
callbackScience = (name, block, next) => {
  science(name, (experiment) => {
    experiment.async(true);
    // Overwrite #try()
    experiment.try = (name, block) => {
      if (!block) {
        block = name;
        name = "candidate";
      }
      experiment.constructor.prototype.try.call(experiment, name, () => {
        // Wrap callback as promise
        return new Promise((resolve, reject) => {
          block((error, result) => {
            error ? reject(error) : resolve(result);
          });
        });
      });
    };

    block(experiment);
  }).then(
    (res) => next(null, res)
  , (err) => next(err, null)
  );
};

// Example usage
callbackScience('read file', (experiment) => {
  experiment.use((next) => fs.readFile("package.json", next));
  experiment.try((next) => next(null, fs.readFileSync("package.json")));
}, console.log);
