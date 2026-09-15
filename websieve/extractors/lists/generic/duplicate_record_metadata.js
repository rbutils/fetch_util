  function duplicateRecordAuthors(card, authorSelector) {
    var nodes = cardOwnedNodes(card, authorSelector).filter(function(node) {
      return genericListAuthorMetadataNode(node) && !genericListInteractionOwner(node) &&
        node.closest("article, li, tr") === card;
    });
    return nodes.filter(function(node) {
      return !nodes.some(function(other) { return other !== node && node.contains(other); });
    }).map(function(node) {
      var markdown = normalizeText(listTextWithReferences(node));
      if (!markdown) return null;
      var links = [];
      if (node.matches("a[href]")) links.push(node);
      Array.prototype.push.apply(links, Array.from(node.querySelectorAll("a[href]")));
      var destinations = links.map(function(link) {
        var url = materializedHttpUrl(link.getAttribute("href"));
        return url && listCanonicalKey(url);
      }).filter(Boolean).filter(function(value, index, values) {
        return values.indexOf(value) === index;
      }).sort();
      return { markdown: markdown, identity: markdown.toLowerCase() + "\u0000" + destinations.join("\u0000") };
    }).filter(Boolean).filter(function(author, index, authors) {
      return authors.findIndex(function(other) { return other.identity === author.identity; }) === index;
    });
  }

  function duplicateRecordTitleNodes(card) {
    var titles = Array.from(card.querySelectorAll(
      "h1, h2, h3, h4, h5, h6, [role='heading'], [itemprop~='headline'], [class*='title' i], [class*='headline' i]"
    )).filter(function(node) {
      if (node.closest("article, li, tr") !== card || listCardNodeHidden(node)) return false;
      if (node.matches("h1, h2, h3, h4, h5, h6, [role='heading'], [itemprop~='headline']")) return true;
      var hints = (node.getAttribute("class") || "").replace(/([a-z\d])([A-Z])/g, "$1 $2");
      var text = normalizeText(node.textContent);
      return /(?:^|[\s_-])(?:title|headline)(?:$|[\s_-])/i.test(hints) && text.length >= minimumListTitleLength(text);
    });
    return titles.filter(function(node) {
      return !titles.some(function(other) { return other !== node && node.contains(other); });
    });
  }

  function duplicateRecordCandidate(card, authorSelector) {
    if (listCardNodeHidden(card) || card.closest("nav, header, footer, menu, form, [role='navigation'], [role='menu'], [role='toolbar']")) return null;
    if (card.parentElement && card.parentElement.closest("article, li, tr")) return null;

    var titleRecords = duplicateRecordTitleNodes(card).map(function(title) {
      var link = title.closest("a[href]") || title.querySelector("a[href]");
      if (!link || link.closest("article, li, tr") !== card || listCardNodeHidden(link)) return null;
      var url = materializedHttpUrl(link.getAttribute("href"));
      return { title: normalizeText(title.textContent).toLowerCase(), key: url && listCanonicalKey(url) };
    }).filter(function(record) { return record && record.title && record.key; });
    var primaryKeys = Array.from(new Set(titleRecords.map(function(record) {
      return record.key;
    }).filter(Boolean)));
    var titles = Array.from(new Set(titleRecords.map(function(record) {
      return record.title;
    }).filter(Boolean)));
    if (primaryKeys.length !== 1 || titles.length !== 1) return null;

    var primaryKey = primaryKeys[0];
    var competing = cardOwnedNodes(card, "a[href]").some(function(link) {
      var authorOwner = link.closest(authorSelector);
      if ((authorOwner && card.contains(authorOwner) && genericListAuthorMetadataNode(authorOwner)) || genericListInteractionOwner(link)) return false;
      var url = materializedHttpUrl(link.getAttribute("href"));
      return url && listCanonicalKey(url) !== primaryKey;
    });
    return {
      card: card,
      key: primaryKey,
      title: titles[0],
      authors: duplicateRecordAuthors(card, authorSelector),
      competing: competing
    };
  }

  function mergeDuplicateRecordAuthorContext(root, items) {
    if (!root || !root.querySelectorAll || !items || !items.length) return;
    var authorSelector = "[rel~='author'], [itemprop~='author'], [data-author], [class*='author' i], [class*='byline' i]";
    var candidatesByUrl = {};

    Array.prototype.forEach.call(root.querySelectorAll("article, li, tr"), function(card) {
      var candidate = duplicateRecordCandidate(card, authorSelector);
      if (!candidate) return;
      if (!candidatesByUrl[candidate.key]) candidatesByUrl[candidate.key] = [];
      candidatesByUrl[candidate.key].push(candidate);
    });

    items.forEach(function(item) {
      var key = item && item.url && listCanonicalKey(item.url);
      if (!key || item.author || !candidatesByUrl[key]) return;
      var candidates = candidatesByUrl[key].filter(function(candidate) {
        return candidate.card !== item.card && (!item.sourceNode || !candidate.card.contains(item.sourceNode));
      });
      var title = normalizeText(item.text || "").toLowerCase();
      var matching = candidates.filter(function(candidate) { return candidate.title === title; });
      if (!matching.length || matching.some(function(candidate) { return candidate.competing; })) return;
      var authors = matching.reduce(function(values, candidate) {
        return values.concat(candidate.authors);
      }, []).filter(function(author, index, values) {
        return values.findIndex(function(other) { return other.identity === author.identity; }) === index;
      });
      if (authors.length === 1) item.author = authors[0].markdown;
    });
  }
