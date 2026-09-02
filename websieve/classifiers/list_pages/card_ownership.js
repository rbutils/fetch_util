  function genericListCardSelector() {
    return "tr, article, li, .post, .entry, [class*='card' i], [class*='story' i], [class*='teaser' i], [class*='item' i], [class*='result' i], [class*='news' i], [class*='headline' i]";
  }

  function genericListPresentationCardNode(node) {
    var classes = ((node && node.getAttribute && node.getAttribute("class")) || "").split(/\s+/);
    return classes.some(function(name) {
      return /^(?:card|story|teaser|result|news|headline)[-_]+(?:body|content|meta(?:data)?|header|footer|details?)(?:[-_].*)?$/i.test(name) ||
        /^(?:Card|Story|Teaser|Result|News|Headline)(?:Body|Content|Meta(?:data)?|Header|Footer|Details?)(?:[-_A-Z].*)?$/.test(name) ||
        /styles__(?:(?:Card|Story|Teaser|Result|News|Headline)(?:Body|Content|Meta(?:data)?|Header|Footer|Details?|Title|Headline|Heading|Image|Media|Thumbnail)|(?:Title|Headline|Heading|Meta(?:data)?|Image|Media|Thumbnail|Kicker|Eyebrow))(?:[-_A-Z].*)?$/.test(name) ||
        /^item[-_]+meta(?:data)?(?:[-_].*)?$/i.test(name);
    });
  }

  function genericListDirectAnchorCard(link, container) {
    if (!link || !container || link.parentElement !== container || !link.matches("a[href]")) return false;

    var recordEvidence = "picture, video, img[alt]:not([alt='']), time, [datetime], [class*='title' i], [class*='summary' i], [class*='description' i], [class*='excerpt' i], [class*='date' i], [class*='duration' i], [class*='count' i], [class*='view' i]";
    if (!link.querySelector(recordEvidence)) return false;

    var peers = Array.prototype.filter.call(container.children, function(child) {
      return child.matches && child.matches("a[href]") &&
        materializedHttpUrl(child.getAttribute("href")) && child.querySelector(recordEvidence);
    });
    return peers.length >= 2;
  }

  function genericListDirectAnchorTitle(link, container) {
    if (!genericListDirectAnchorCard(link, container)) return "";

    var titleNode = link.querySelector("[class*='title' i]");
    var title = normalizeText((titleNode && titleNode.textContent) || link.getAttribute("title") || "");
    return title.length >= 6 && title.length <= 220 ? title : "";
  }

  function genericListControlText(text) {
    return /^(comments?|discuss|hide|more|abonneren|subscribe|newsletter|login|log in|sign in|register|create account|maak een account|instellingen|settings|account|last post|first unread|go to last post|mark read|mark forum read|watch forum|new thread|post new thread|post reply|quick reply|forum rules|forum actions|forum tools)$/i.test(normalizeText(text || ""));
  }

  function genericListControlSegments(text) {
    return normalizeText(text || "").split(/\s+(?:[-–—|·])\s+/).map(function(segment) {
      return normalizeText(segment).replace(/^[([]+\s*/, "").replace(/\s*[)\]]+$/, "");
    }).filter(Boolean);
  }

  function genericListControlMetadataSegment(text) {
    var match = normalizeText(text || "").match(/^(?:last post|first unread)(.*)$/i);
    if (!match) return false;

    var detail = normalizeText(match[1]).replace(/^\s*:\s*/, "");
    if (!detail) return true;
    if (/^by\s+\S+$/i.test(detail)) return true;
    if (/^(?:at|on)\s+(?:today|yesterday|\d{4}-\d{1,2}-\d{1,2}|\d{1,2}:\d{2}(?:\s*[ap]m)?)$/i.test(detail)) return true;
    var timestamp = "(?:today|yesterday|\\d+(?:\\.\\d+)?\\s*(?:s|m|h|d|w|seconds?|minutes?|hours?|days?|weeks?|months?|years?)\\s+ago|\\d{1,2}:\\d{2}(?:\\s*[ap]m)?)";
    return new RegExp("^(?:" + timestamp + "(?:\\s+by\\s+\\S+)?|by\\s+\\S+\\s+(?:at\\s+)?" + timestamp + ")$", "i").test(detail);
  }

  function genericListMetricSegment(text) {
    return /^\d+(?:\.\d+)?\s*(?:comments?|repl(?:y|ies)|posts?|points?|likes?|views?)$/i.test(normalizeText(text || ""));
  }

  function genericListControlMetadataText(text) {
    var segments = genericListControlSegments(text);
    return segments.length > 0 && segments.every(function(segment) {
      return genericListMetricSegment(segment) || genericListControlMetadataSegment(segment);
    });
  }

  function stripGenericListControlPhrases(text) {
    var normalized = normalizeText(text || "");
    var separator = /\s+(?:[-–—|·])\s+/;
    var segments = normalized.split(separator);
    var filtered = segments.filter(function(segment) {
      var comparable = genericListControlSegments(segment).join(" ");
      return !genericListControlText(comparable) && !genericListControlMetadataSegment(comparable);
    });
    if (filtered.length === segments.length) return normalized;

    var delimiter = normalized.match(separator);
    return normalizeText(filtered.join(delimiter ? delimiter[0] : " - "));
  }

  function pruneGenericListControls(root) {
    if (!root || !root.querySelectorAll) return;
    root.querySelectorAll("*").forEach(function(node) {
      var text = node.textContent || node.getAttribute("aria-label") || "";
      var structuredText = Array.prototype.map.call(node.childNodes || [], function(child) {
        return child.textContent || "";
      }).join(" ");
      if (genericListControlText(text) || genericListControlMetadataText(text) || genericListControlMetadataText(structuredText)) node.remove();
    });
  }

  function genericListCardBoundary(node) {
    if (!node || !node.matches || !node.matches(genericListCardSelector())) return false;
    if (genericListPresentationCardNode(node)) return false;
    if (node.matches("main, [role='main']")) return false;
    if (!node.matches(".post, .entry")) return true;

    var links = node.matches("a[href]") ? [node] : Array.prototype.slice.call(node.querySelectorAll("a[href]"));
    var ownedLinks = links.filter(function(link) {
      return link.closest(".post, .entry") === node &&
        !link.matches("[rel='author'], [itemprop='author']") &&
        !link.closest("[class*='author' i], [class*='byline' i]");
    });
    if (!ownedLinks.length) return false;

    var hasNestedCard = Array.prototype.some.call(node.querySelectorAll(genericListCardSelector()), genericListNestedCard);
    if (!hasNestedCard) return true;
    return ownedLinks.some(function(link) {
      return link.parentElement === node || !!link.closest("h1, h2, h3, h4");
    });
  }

  function closestGenericListCard(node) {
    var current = node;
    while (current && current.closest) {
      var card = current.closest(genericListCardSelector());
      if (!card) return null;
      if (genericListCardBoundary(card)) return card;
      current = card.parentElement;
    }
    return null;
  }

  function genericListFieldBoundary(node) {
    if (!genericListCardBoundary(node)) return false;
    return !(node.matches && node.matches("li")) || genericListNestedCard(node);
  }

  function closestGenericListFieldCard(node) {
    var current = node;
    while (current && current.closest) {
      var card = current.closest(genericListCardSelector());
      if (!card) return null;
      if (genericListFieldBoundary(card)) return card;
      current = card.parentElement;
    }
    return null;
  }

  function genericListCardText(node) {
    if (!node || !node.cloneNode) return "";
    var clone = node.cloneNode(true);
    pruneGenericListControls(clone);
    clone.querySelectorAll(genericListCardSelector()).forEach(function(nested) {
      if (genericListFieldBoundary(nested)) nested.remove();
    });
    return stripGenericListControlPhrases(clone.textContent || "");
  }

  function genericListNestedCard(node) {
    if (!node || !node.querySelector || !genericListCardBoundary(node)) return false;
    var explicitCard = node.matches && node.matches("tr, article, li, .post, .entry");
    var linkSelector = explicitCard ? "a[href]" : "h1 a[href], h2 a[href], h3 a[href], h4 a[href]";
    return !!node.querySelector(linkSelector);
  }

  function genericListNestedCardReplaces(card, nested) {
    if (card && card.matches && card.matches("tr")) return false;
    return !(card && nested && card.matches && nested.matches &&
      card.matches(".post, .entry") && nested.matches(".post, .entry") &&
      genericListCardBoundary(card) && genericListCardBoundary(nested));
  }

  function genericListContextCard(card) {
    if (!card || !card.parentElement) return card;
    var outer = card.parentElement.closest && card.parentElement.closest(".post, .entry");

    while (outer && !genericListCardBoundary(outer)) {
      var materialCards = Array.prototype.filter.call(outer.querySelectorAll(genericListCardSelector()), function(nested) {
        if (!genericListNestedCard(nested)) return false;
        var ancestor = nested.parentElement;
        while (ancestor && ancestor !== outer) {
          if (genericListNestedCard(ancestor)) return false;
          ancestor = ancestor.parentElement;
        }
        return ancestor === outer;
      });
      if (materialCards.length !== 1 || materialCards[0] !== card) break;
      card = outer;
      outer = card.parentElement && card.parentElement.closest && card.parentElement.closest(".post, .entry");
    }
    return card;
  }

  function listCardRoot(link, fallback) {
    if (fallback && fallback.matches && fallback.matches("tr")) return fallback;
    if (genericListDirectAnchorCard(link, fallback)) return link;
    var card = genericListContextCard(closestGenericListCard(link));
    return card || fallback || (link && link.parentElement);
  }
