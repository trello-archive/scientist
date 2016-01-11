const _ = require('underscore');
const fs = require('fs');
const Promise = require('bluebird');
const science = require('../console');

const open = Promise.promisify(fs.open);
const stat = Promise.promisify(fs.stat);
const fstat = Promise.promisify(fs.fstat);

const fsStat = (file) => {
  return science('file stat', (experiment) => {
    experiment.async(true);
    experiment.use(() => open(file, 'r').then(fstat));
    experiment.try(() => stat(file));

    experiment.map((file) => {
      // We don't want to deal with timestamp race conditions, so just compare
      // inode.
      return file.then((stat) => stat.ino);
    });
  });
};

fsStat("package.json").then(console.log);
