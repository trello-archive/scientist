"use strict";

const _ = require('underscore');
const science = require('../console');

const sumList = (arr) => {
  return science('sum-list', (experiment) => {
    experiment.use(() => sumListOld(arr));
    experiment.try(() => sumListNew(arr));
  });
};

const sumListOld = (arr) => {
  let sum = 0;
  for (var i of arr) {
    sum += i;
  }
  return sum;
};

const sumListNew = (arr) => {
  return _.reduce(arr, (sum, i) => sum + i);
};

console.log(sumList([1, 2, 3]));
console.log(sumList([]));
