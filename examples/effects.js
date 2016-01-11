"use strict";

const _ = require('underscore');
const science = require('../console');

const userMiddleware = (req) => {
  return science('user middleware', (experiment) => {
    experiment.use(() => {
      findUser(req);
      return req;
    });
    experiment.try(() => {
      let clone = _.clone(req);
      findUserById(clone);
      findUserByName(clone);
      return clone;
    });

    experiment.map((req) => req.user);
  });
};

const db = [{ id: 1, name: 'foo' }];

const findUser = (req) => {
  if (/\d+/.test(req.userId)) {
    req.user = _.find(db, { id: req.userId });
  } else {
    req.user = _.find(db, { name: req.userId });
  }
};
const findUserById = (req) => {
  req.user = req.user || _.find(db, { id: req.userId });
};
const findUserByName = (req) => {
  req.user = req.user || _.find(db, { name: req.userId });
};


let req = { userId: 'foo' };
userMiddleware(req);
console.log(req);
