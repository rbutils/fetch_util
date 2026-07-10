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

  function cardOwnedNodes(card, selector) {
    var cardSelector = "article, li, [class*='card'], [class*='story'], [class*='teaser'], [class*='item'], [class*='result'], [class*='news'], [class*='headline']";
    var cardIsRoot = card.matches && card.matches(cardSelector);
    return Array.prototype.filter.call(card.querySelectorAll(selector), function(node) {
      var nearest = node.parentElement;
      while (nearest && nearest !== card && !(nearest.matches && nearest.matches(cardSelector))) nearest = nearest.parentElement;
      return !cardIsRoot || nearest === card;
    });
  }

  function sectionCardCandidate(card, options) {
    if (options && options.directCard) {
      var directLink = card.matches && card.matches("a[href]") ? card : card.querySelector("a[href]");
      var directText = normalizeText((card.querySelector("h1, h2, h3, h4") || directLink || {}).textContent || "");
      if (directLink && directText.length >= 6) {
        var directCandidate = { text: directText, url: absoluteUrl(directLink.getAttribute("href")), detail: "", score: directText.length };
        directCandidate.canonicalKey = listCanonicalKey(directCandidate.url);
        directCandidate.url = directCandidate.canonicalKey;
        directCandidate.card = card;
        addCardContext(directCandidate, card);
        return directCandidate;
      }
    }
    var nestedCards = card.querySelectorAll("article, li, [class*='card'], [class*='story'], [class*='teaser'], [class*='item'], [class*='result'], [class*='news'], [class*='headline']");
    if (Array.prototype.some.call(nestedCards, function(nested) {
      return nested.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href]");
    })) return null;
    var links = cardOwnedNodes(card, "a[href]");
    var headingLink = cardOwnedNodes(card, "h1 a[href], h2 a[href], h3 a[href], h4 a[href]")[0];
    if (card.matches && card.matches("a[href]")) links = [card];
    if (!headingLink && !cardOwnedNodes(card, "p, [class*='summary'], [class*='description'], [class*='excerpt'], time, img[alt]:not([alt=''])").length) return null;
    var link = headingLink;
    if (!link) {
      link = links.filter(function(anchor) {
        return anchor.querySelector("h1, h2, h3, h4");
      })[0];
    }
    if (!link) {
      link = links.reduce(function(best, anchor) {
        var candidate = listLinkCandidate(anchor, card, listPageContext());
        return candidate && (!best || candidate.score > best.score) ? anchor : best;
      }, null);
    }
    if (!link && options && options.ancestorLink) link = card.closest("a[href]");
    var candidate = listLinkCandidate(link, card, listPageContext());
    if (!candidate && link) {
      var href = link.getAttribute("href");
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      var url = absoluteUrl(href);
      if (href && url && text.length >= 6 && text.length <= 220) candidate = { text: text, url: url, detail: "", score: text.length };
    }
    if (!candidate) return null;

    candidate.domIndex = Array.prototype.indexOf.call(document.querySelectorAll("a[href]"), link);
    candidate.canonicalKey = listCanonicalKey(candidate.url);
    candidate.url = candidate.canonicalKey;
    candidate.card = card;
    addCardContext(candidate, card);
    return candidate;
  }

  function boundedCardText(card, selectors, maximum) {
    var field = cardOwnedNodes(card, selectors)[0];
    if (!field) return "";
    return normalizeText(field.textContent).slice(0, maximum);
  }

  function meaningfulMediaText(card) {
    var media = cardOwnedNodes(card, "img[alt]:not([alt='']), figcaption")[0];
    if (!media) return "";

    var text = normalizeText(media.getAttribute ? media.getAttribute("alt") : media.textContent);
    if (text.length <= 2 || /^(image|photo|thumbnail|logo|icon|avatar)$/i.test(text)) return "";
    return text.slice(0, 160);
  }

  function addCardContext(candidate, card) {
    candidate.summary = boundedCardText(card, "[class*='summary'], [class*='description'], [class*='excerpt'], p", 240);
    candidate.category = boundedCardText(card, "[class*='category'], [class*='eyebrow'], [class*='kicker']", 80);

    var time = cardOwnedNodes(card, "time")[0];
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
