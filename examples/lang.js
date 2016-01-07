const science = require('scientist/console');

// Express middleware that picks a language to use from the accept-language
// header.

module.exports = function(req, res, next) {
  if (req.method != "GET") {
    return next();
  }

  preferred = science('middleware-lang-cookie', (experiment) => {
    experiment.context({ langHeader: req.get('accept-language') });
    experiment.use(() => oldLang(req))
    experiment.try(() => newLang(req))
  });

  req.lang = preferred;

  next()
};

const oldLang = function(req) {
  acceptLanguage = req.headers["accept-language"]
  if !acceptLanguage? || acceptLanguage.length > 128
    return null

  entries = acceptLanguage.split(",")

  # Drop the "en" entry, if it exists, and prefer the more specific en-FOO entry
  # We're abusing the language header, to decide if the person is likely to want
  # a 24-hour clock and weeks starting on a Monday
  entries = _.filter entries, (entry) ->
    !/^en(;|$)/.test(entry)

  # Accept-Language: da, en-gb;q=0.8, en;q=0.7
  preferredEntry = _.max entries, (entry) ->
    parseFloat(/;q=([0-9\.]+)$/.exec(entry)?[1]) || 1.0

  return /^\s*([-a-z_]+)/i.exec(preferredEntry)?[1] ? "en-US"
};

const newLang = function(req) {
  locales = new locale.Locales(req.get('accept-language'))

  preferred = _.first(locales)?.code

  // If we see an 'en' full-language code, try to replace it with a more
  // specific en-FOO language code. This lets us distinguish between things like
  // 24-hour clock and weeks starting on a Monday. If there is no more specific
  // entry, use 'en'.
  if preferred == 'en'
    preferred = _.find(_.tail(locales), language: 'en')?.code ? 'en'

  preferred ? null
};
