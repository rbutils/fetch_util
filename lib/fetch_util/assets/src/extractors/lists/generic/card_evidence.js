  function pushUniqueListCandidate(candidates, seen, candidate) {
    if (!candidate) return false;

    var key = candidate.text + "|" + candidate.url;
    var canonicalKey = candidate.canonicalKey || listCanonicalKey(candidate.url);
    if (seen[key] || seen["url:" + canonicalKey]) return false;
    seen[key] = true;
    seen["url:" + canonicalKey] = true;
    candidate.canonicalKey = canonicalKey;
    candidates.push(candidate);
    return true;
  }

  function collectCardLinkCandidates(root, options) {
    options = options || {};
    root = root || document;

    var cards = [];
    var selectors = options.cardSelectors || [];
    var seenCards = [];
    var seenCandidates = {};
    var items = [];
    var maxItems = options.maxItems || Infinity;
    var minTitleLength = options.minTitleLength || 0;
    var maxTitleLength = options.maxTitleLength || Infinity;
    var dedupe = options.dedupe !== false;

    if (typeof selectors === "string") selectors = [selectors];

    function pushCard(node) {
      if (!node || seenCards.indexOf(node) !== -1) return;
      seenCards.push(node);
      cards.push(node);
    }

    function candidateKeys(candidate, card, link) {
      var keys;
      if (options.keyBuilder) keys = options.keyBuilder(candidate, card, link);
      if (keys === null || keys === undefined) keys = [candidate.text + "|" + (candidate.url || "")];
      if (!Array.isArray(keys)) keys = [keys];
      return keys.filter(Boolean);
    }

    selectors.forEach(function(selector) {
      Array.prototype.forEach.call(root.querySelectorAll(selector), pushCard);
    });
    if (!selectors.length && root.querySelectorAll) pushCard(root);

    cards.forEach(function(card) {
      if (items.length >= maxItems) return;

      var link = options.linkBuilder ? options.linkBuilder(card) : (options.linkSelector ? card.querySelector(options.linkSelector) : null);
      var candidate = options.candidateBuilder ? options.candidateBuilder(card, link) : null;
      var keys;
      if (!candidate) return;
      candidate.text = normalizeText(candidate.text || "");
      candidate.url = candidate.url || "";
      var candidateMinTitleLength = typeof minTitleLength === "function" ? minTitleLength(candidate.text) : minTitleLength;
      if (!candidate.text || candidate.text.length < candidateMinTitleLength || candidate.text.length > maxTitleLength) return;
      if (!options.allowMissingUrl && !candidate.url) return;
      if (options.rejectCandidate && options.rejectCandidate(candidate, card, link)) return;
      if (candidate.detail === undefined && options.detailBuilder) candidate.detail = options.detailBuilder(card, candidate, link);

      keys = candidateKeys(candidate, card, link);
      if (dedupe && keys.some(function(key) { return seenCandidates[key]; })) return;
      if (dedupe) keys.forEach(function(key) { seenCandidates[key] = true; });
      items.push(candidate);
    });

    return items;
  }

  function sectionCardCandidate(card) {
    var link = card.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href]");
    var candidate = listLinkCandidate(link, card, listPageContext());
    if (!candidate) return null;

    candidate.domIndex = Array.prototype.indexOf.call(document.querySelectorAll("a[href]"), link);
    candidate.canonicalKey = listCanonicalKey(candidate.url);
    candidate.url = candidate.canonicalKey;
    addCardContext(candidate, card);
    return candidate;
  }

  function boundedCardText(card, selectors, maximum) {
    var field = card.querySelector(selectors);
    if (!field) return "";
    return normalizeText(field.textContent).slice(0, maximum);
  }

  function meaningfulMediaText(card) {
    var media = card.querySelector("img[alt]:not([alt='']), figcaption");
    if (!media) return "";

    var text = normalizeText(media.getAttribute ? media.getAttribute("alt") : media.textContent);
    if (text.length <= 2 || /^(image|photo|thumbnail|logo|icon|avatar)$/i.test(text)) return "";
    return text.slice(0, 160);
  }

  function addCardContext(candidate, card) {
    candidate.summary = boundedCardText(card, "[class*='summary'], [class*='description'], [class*='excerpt'], p", 240);
    candidate.category = boundedCardText(card, "[class*='category'], [class*='eyebrow'], [class*='kicker']", 80);

    var time = card.querySelector("time");
    if (time) candidate.time = normalizeText(time.getAttribute("datetime") || time.textContent).slice(0, 80);

    candidate.image = meaningfulMediaText(card);
    candidate.caption = boundedCardText(card, "figcaption", 160);
  }

  function listMarkdown(items) {
    return items.map(function(item) {
      var line = item.url ? "- [" + item.text + "](" + item.url + ")" : "- " + item.text;
      var context = [item.category, item.summary, item.time, item.image, item.caption].filter(Boolean).join(" - ");
      if (context) line += " - " + context;
      else if (item.detail) line += " - " + item.detail;
      return line;
    }).join("\n");
  }
