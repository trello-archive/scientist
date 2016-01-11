const _ = require('underscore');
const science = require('../console');

const search = (terms) => {
  return science('search', (experiment) => {
    experiment.context({ terms });

    experiment.use(() => current(terms));
    experiment.try(() => refactor(terms));

    // Get rid of the time data since we don't need that
    experiment.map((result) => ({
      users: _.pluck(result.users, 'id'),
      count: result.count,
    }));

    // We use deep equality by default, but maybe in this case search is
    // non-deterministic by design
    experiment.compare((a, b) =>
      a.count == b.count && _.isEqual(a.users.sort(), b.users.sort()));

    // And to store in the logs, we might want to get rid of the array
    experiment.clean((result) => ({
      users: result.users.sort().join(","),
      count: result.count,
    }));
  });
};

// These are fixtures to demonstrate the science
const current = (terms) => ({
  timestamp: new Date(),
  users: [{ id: 1, name: 'foo' }, { id: 2, name: 'bar' }],
  count: 2,
});
const refactor = (terms) => ({
  timestamp: new Date(),
  users: [{ id: 2, name: 'bar' }, { id: 1, name: 'foo' }],
  count: 2,
});

console.log(search("test"));
