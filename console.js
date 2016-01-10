// A console implementation of scientist that works out of the box. This should
// mostly serve as an example or jump-start point.

var Scientist = require('./index');

var scientist = new Scientist();

scientist.on('skip', function (experiment) {
  console.log("Experiment skipped", {
    experiment: experiment.name,
    context: experiment.context(),
  });
});

scientist.on('result', function (result) {
  var experiment = result.experiment;
  var control = result.control;

  var each = function (set, iterator) {
    for (var i = 0; i < result[set].length; i++) {
      iterator(result[set][i]);
    }
  };

  // Log success statuses
  each('matched', function (candidate) {
    console.log("Experiment candidate matched the control", {
      context: result.context,
      result: candidate.inspect(),
    });
  });

  // Log failures with observations
  each('mismatched', function (candidate) {
    console.error("Experiment candidate did not match the control", {
      context: result.context,
      expected: control.inspect(),
      received: candidate.inspect(),
    });
  });

  // Log ignored observations
  each('ignored', function (candidate) {
    console.log("Experiment ignored candidate", {
      context: result.context,
      experiment: experiment,
    });
  });
});

scientist.on('error', function (err) {
  console.error("Error during experiment:", err.stack);
});

module.exports = Scientist.prototype.science.bind(scientist);
