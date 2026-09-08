  function pushUniqueListCandidate(candidates, seen, candidate) {
    if (!candidate) return false;

    var canonicalKey = candidate.canonicalKey || listCanonicalKey(candidate.url);
    var dedupeKey = candidate.dedupeKey || canonicalKey;
    var key = candidate.text + "|" + dedupeKey;
    if (seen[key] || seen["url:" + dedupeKey]) return false;
    seen[key] = true;
    seen["url:" + dedupeKey] = true;
    candidate.canonicalKey = canonicalKey;
    candidates.push(candidate);
    return true;
  }

  function listItemsQualityScore(items) {
    return (items || []).reduce(function(total, item, index) {
      var value = Math.max(0, item && item.rankScore ? item.rankScore : textLength(item && item.text));
      value = Math.min(value, 1200);
      if (index >= 8) value = Math.round(value / 2);
      return total + value;
    }, 0);
  }

  function collectCardLinkCandidates(root, options) {
    options = options || {};
    root = root || document;

    var cards = [];
    var selectors = options.cardSelectors || [];
    var seenCards = [];
    var seenCandidates = {};
    var items = [];
    var minTitleLength = options.minTitleLength || 0;
    var maxTitleLength = options.maxTitleLength || Infinity;
    var dedupe = options.dedupe !== false;

    if (typeof selectors === "string") selectors = [selectors];

    function pushCard(node) {
      if (!node || elementVisuallyHidden(node) || seenCards.indexOf(node) !== -1) return;
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
    var nodes = Array.prototype.slice.call(card.querySelectorAll(selector));
    if (card.matches && card.matches("tr")) return nodes;
    if (!genericListFieldBoundary(card)) return nodes;
    return nodes.filter(function(node) {
      return closestGenericListFieldCard(node) === card;
    });
  }

  function sectionCardCandidate(card, options) {
    if (options && options.directCard) {
      var directLink = card.matches && card.matches("a[href]") ? card : card.querySelector("a[href]");
      var directText = normalizeText((card.querySelector("h1, h2, h3, h4") || directLink || {}).textContent || "");
      if (directLink && directText.length >= 6) {
        var directHref = directLink.getAttribute("href") || "";
        var directUrl = materializedHttpUrl(directHref);
        var directCandidate = { text: directText, url: directUrl, detail: "", rankScore: directText.length };
        directCandidate.canonicalKey = directUrl ? listCanonicalKey(directUrl) : "unlinked:" + directText.toLowerCase() + "|href:" + directHref;
        directCandidate.url = directUrl ? directCandidate.canonicalKey : null;
        directCandidate.card = card;
        directCandidate.sourceNode = directLink;
        addCardContext(directCandidate, card);
        return directCandidate;
      }
    }
    var nestedCards = card.querySelectorAll(genericListCardSelector());
    if (Array.prototype.some.call(nestedCards, function(nested) {
      return genericListNestedCard(nested) && genericListNestedCardReplaces(card, nested);
    })) return null;
    var links = cardOwnedNodes(card, "a[href]").filter(function(anchor) {
      return !anchor.matches("[rel='author'], [itemprop='author']") &&
        !anchor.closest("[class*='author' i], [class*='byline' i]");
    });
    var headingLink = links.filter(function(anchor) {
      return !!(anchor.closest("h1, h2, h3, h4") || anchor.querySelector("h1, h2, h3, h4"));
    })[0];
    if (card.matches && card.matches("a[href]")) links = [card];
    var namedCard = card.matches && (card.matches("tr") ||
      (card.matches(".post, .entry") && genericListCardBoundary(card)) ||
      genericListDirectAnchorCard(card, card.parentElement));
    if (!headingLink && !namedCard && !cardOwnedNodes(card, "p, [class*='summary'], [class*='description'], [class*='excerpt'], time, img[alt]:not([alt=''])").length) return null;
    var link = headingLink;
    if (!link) {
      link = links.reduce(function(best, anchor) {
        var candidate = listLinkCandidate(anchor, card, listPageContext(), true);
        return candidate && (!best || candidate.rankScore > best.rankScore) ? anchor : best;
      }, null);
    }
    if (!link && options && options.ancestorLink) link = card.closest("a[href]");
    var candidate = listLinkCandidate(link, card, listPageContext(), true);
    if (!candidate && link) {
      var href = link.getAttribute("href");
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      var url = materializedHttpUrl(href);
      if (href && url && text.length >= 6 && text.length <= 220) candidate = { text: text, url: url, detail: "", rankScore: text.length };
    }
    if (!candidate) return null;

    candidate.domIndex = Array.prototype.indexOf.call(document.querySelectorAll("a[href]"), link);
    if (candidate.url) {
      candidate.canonicalKey = listCanonicalKey(candidate.url);
      candidate.url = candidate.canonicalKey;
    }
    candidate.card = listCardRoot(link, card);
    candidate.sourceNode = link;
    addCardContext(candidate, candidate.card);
    return candidate;
  }

  function completeCardText(card, selectors) {
    var field = cardOwnedNodes(card, selectors)[0];
    if (!field) return "";
    return normalizeText(field.textContent);
  }

  function meaningfulMediaText(card) {
    var media = cardOwnedNodes(card, "img[alt]:not([alt='']), figcaption")[0];
    if (!media) return "";

    var text = normalizeText(media.getAttribute ? media.getAttribute("alt") : media.textContent);
    if (text.length <= 2 || /^(image|photo|thumbnail|logo|icon|avatar)$/i.test(text)) return "";
    return text;
  }

  function listTableCellText(cell) {
    var text = normalizeText(cell.innerText || cell.textContent || "");
    if (text) return text;

    var labels = [];
    var nodes = [cell].concat(Array.prototype.slice.call(cell.querySelectorAll("[aria-label], [title], img[alt]")));
    nodes.forEach(function(node) {
      var label = normalizeText(node.getAttribute("aria-label") || node.getAttribute("title") || node.getAttribute("alt") || "");
      if (label && labels.indexOf(label) === -1) labels.push(label);
    });
    return labels.join(" ");
  }

  function listTableRowDetail(row, title, logicalCells) {
    var cells = logicalCells || tableIndexCells(row);
    var cellsAreLogical = !!logicalCells;
    var table = row.closest && row.closest("table");
    var headers = table ? tableIndexHeaders(table) : [];
    var titleCellIndex = cells.findIndex(function(cell) {
      return cell && listTableCellText(cell).indexOf(title) !== -1;
    });
    var headerIndex = 0;
    return cells.map(function(cell, index) {
      if (!cell) return "";
      if (cellsAreLogical && index > 0 && cells[index - 1] === cell) return "";
      var label = headers[cellsAreLogical ? index : headerIndex] || "";
      if (!cellsAreLogical) headerIndex += tableIndexSpan(cell, "colSpan", "colspan");
      var value = listTableCellText(cell);
      if (genericListControlText(label) || genericListControlMetadataText(value)) return "";
      var titleIndex = value.indexOf(title);
      if (titleIndex !== -1) value = normalizeText(value.slice(0, titleIndex) + " " + value.slice(titleIndex + title.length));
      if (!value) return "";

      return index !== titleCellIndex && label && label.toLowerCase() !== value.toLowerCase() ? label + ": " + value : value;
    }).filter(Boolean).join(" | ");
  }

  function addCardContext(candidate, card) {
    candidate.summary = completeCardText(card, "[class*='summary'], [class*='description'], [class*='excerpt'], p");
    candidate.category = completeCardText(card, "[class*='category'], [class*='eyebrow'], [class*='kicker']");

    var time = cardOwnedNodes(card, "time")[0];
    if (time) candidate.time = normalizeText(time.getAttribute("datetime") || time.textContent);

    candidate.image = meaningfulMediaText(card);
    if (normalizeText(candidate.image) === normalizeText(candidate.text)) candidate.image = "";
    candidate.caption = completeCardText(card, "figcaption");
  }
