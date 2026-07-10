function normalizeLanguageCode(value) {
  var text = normalizeText(value || "").toLowerCase();
  if (!text) return null;

  var first = text.split(",")[0].replace(/_/g, "-");
  var match = first.match(/^[a-z]{2,3}(?=-|$)/);
  if (!match) return null;

  var code = match[0];
  var aliases = { eng: "en", spa: "es", hin: "hi", fra: "fr", fre: "fr", deu: "de", ger: "de", por: "pt", zho: "zh", chi: "zh" };
  code = aliases[code] || code;

  return code.length === 2 ? code : null;
}

function languageFromText() {
  var text = normalizeText(document.body && document.body.innerText || "");
  if (text.length < 80) return null;

  var compact = text.replace(/\s/g, "");
  var scriptPatterns = [
    ["hi", /[\u0900-\u097F]/g],
    ["ar", /[\u0600-\u06FF]/g],
    ["zh", /[\u4E00-\u9FFF]/g],
    ["ja", /[\u3040-\u30FF]/g],
    ["ko", /[\uAC00-\uD7AF]/g],
    ["el", /[\u0370-\u03FF]/g],
    ["ru", /[\u0400-\u04FF]/g]
  ];

  for (var i = 0; i < scriptPatterns.length; i++) {
    var matches = compact.match(scriptPatterns[i][1]) || [];
    if (matches.length >= 20 && matches.length / compact.length >= 0.25) return scriptPatterns[i][0];
  }

  var words = text.toLowerCase().match(/[a-zÀ-ž]+/g) || [];
  if (words.length < 30) return null;

  var stopwords = {
    en: /^(?:the|and|that|for|with|this|from|are|was|were|have|has|not|but|their|about|more|will|would|which|when)$/,
    es: /^(?:el|la|los|las|un|una|del|de|al|a|en|y|por|con|para|que|más|son|sus|su|se|pero|como|esta|todo|nos|hay|fue|muy|han|sin|sobre|tiene)$/,
    fr: /^(?:les|des|une|est|dans|pour|sur|par|pas|qui|que|avec|son|sont|plus|ses|mais|cette|ont|tout|nous|vous|aux|leur)$/,
    de: /^(?:und|die|der|das|ist|von|zu|mit|den|ein|eine|für|auf|als|auch|nicht|sich|werden|nach|bei|aus|wie|oder|noch|nur|dem|des|über)$/,
    pt: /^(?:dos|das|uma|por|com|para|que|mais|são|mas|como|esta|seu|sua|tem|nos|foi|pode|muito|seus|sobre|também)$/,
    it: /^(?:gli|una|del|per|con|che|sono|più|dalla|della|delle|dei|anche|come|questa|tutto|suo|sua|suoi|nelle|alla)$/,
    nl: /^(?:een|het|van|zijn|met|dat|voor|maar|niet|ook|als|nog|wel|hun|uit|bij|kan|zou|meer|alle|dit|wordt)$/
  };
  var scores = {};
  Object.keys(stopwords).forEach(function(code) { scores[code] = 0; });
  words.forEach(function(word) {
    Object.keys(stopwords).forEach(function(code) {
      if (stopwords[code].test(word)) scores[code] += 1;
    });
  });

  var best = Object.keys(scores).sort(function(a, b) { return scores[b] - scores[a]; })[0];
  var runnerUp = Object.keys(scores).sort(function(a, b) { return scores[b] - scores[a]; })[1];
  return best && scores[best] >= 4 && scores[best] >= (scores[runnerUp] || 0) * 1.8 ? best : null;
}

function documentLanguage() {
  return normalizeLanguageCode(document.documentElement && document.documentElement.getAttribute("lang")) ||
    normalizeLanguageCode(metadataValue("Content-Language", "http-equiv")) ||
    normalizeLanguageCode(metadataValue("og:locale", "property")) ||
    languageFromText();
}
