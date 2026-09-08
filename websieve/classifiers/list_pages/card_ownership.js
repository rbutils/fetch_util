  function genericListCardSelector(includeAnchors) {
    var selector = "tr, article, li, .post, .entry, .product, .product-tile, [itemtype$='/Product'], [class*='card' i], [class*='story' i], [class*='teaser' i], [class*='item' i], [class*='result' i], [class*='news' i], [class*='headline' i]";
    return includeAnchors === false ? selector : selector + ", " + genericListAnchorCardSelector();
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

  function genericListStructuredCardLink(card) {
    if (!card || !card.parentElement || !genericListCardBoundary(card)) return null;

    var titleNode = card.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4");
    var link = titleNode && (titleNode.matches("a[href]") ? titleNode : titleNode.closest("a[href]"));
    var title = normalizeText(titleNode && titleNode.textContent);
    if (!link || !materializedHttpUrl(link.getAttribute("href")) ||
        title.length < minimumListTitleLength(title) || title.length > 220) return null;

    var recordEvidence = "picture, video, img[alt]:not([alt='']), p, time, [datetime], [class*='summary' i], [class*='description' i], [class*='excerpt' i], [class*='date' i], [class*='duration' i], [class*='count' i], [class*='view' i], [class*='pages' i]";
    return card.querySelector(recordEvidence) ? link : null;
  }

  function genericListChromeOwnedRecordRoots(node) {
    if (!node || !node.querySelectorAll) return [];

    var selector = "ul, ol, [role='list'], [class*='listing' i], [class*='grid' i], [class*='feed' i], [class*='results' i]";
    var roots = [];
    Array.prototype.forEach.call(node.querySelectorAll(selector), function(collection) {
      if (listChromeNode(collection) || scoreListContainer(collection, listPageContext()) === -Infinity) return;
      var records = Array.prototype.filter.call(collection.querySelectorAll(genericListCardSelector()), function(card) {
        return !!genericListStructuredCardLink(card);
      });
      var recordRoots = [];
      records.forEach(function(record) {
        var root = record.parentElement;
        if (recordRoots.indexOf(root) < 0) recordRoots.push(root);
      });
      recordRoots.forEach(function(root) {
        if (roots.indexOf(root) >= 0) return;
        var peers = Array.prototype.filter.call(root.children, function(sibling) {
          return !!genericListStructuredCardLink(sibling);
        });
        if (peers.length >= 4) roots.push(root);
      });
    });
    return roots.filter(function(root) {
      return !roots.some(function(other) {
        return other !== root && other.contains(root);
      });
    });
  }

  function genericListChromeOwnsCollection(node) {
    return genericListChromeOwnedRecordRoots(node).length > 0;
  }

  function genericListFigureRecordLink(figure) {
    if (!figure || !figure.matches || !figure.matches("figure") || !figure.querySelector("figcaption")) return null;

    var heading = figure.querySelector("a[href] h1, a[href] h2, a[href] h3, a[href] h4");
    var link = heading && heading.closest("a[href]");
    return link && materializedHttpUrl(link.getAttribute("href")) ? link : null;
  }

  function genericListFigureCollection(node) {
    if (!node || !node.children) return false;
    var records = Array.prototype.filter.call(node.children, function(child) {
      var figures = child.matches && child.matches("figure") ?
        [child] : Array.prototype.slice.call(child.querySelectorAll ? child.querySelectorAll("figure") : []);
      return figures.filter(function(figure) { return !!genericListFigureRecordLink(figure); }).length === 1;
    });
    return records.length >= 2;
  }

  function genericListFigureCollectionAncestor(node) {
    var current = node;
    while (current && current !== document.body) {
      if (genericListFigureCollection(current)) return current;
      current = current.parentElement;
    }
    return null;
  }

  function genericListFigureAnchorCard(link, figure) {
    return !!(link && figure && link.closest("figure") === figure &&
      genericListFigureRecordLink(figure) === link && genericListFigureCollectionAncestor(figure.parentElement));
  }

  function genericListFigureCollectionRejectsLink(link, container) {
    if (!link || !link.closest) return false;
    var figure = link.closest("figure");
    var collection = genericListFigureCollectionAncestor(figure ? figure.parentElement : (container || link.parentElement));
    if (!collection) return false;

    return !figure || !collection.contains(figure) || genericListFigureRecordLink(figure) !== link;
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

  function genericListPageContainer(node) {
    if (!node || !node.matches) return false;
    if (node.matches("body, main, [role='main'], article.type-page, [itemtype$='/WebPage']")) return true;
    if (!node.matches("article") || !homepageRootPath() ||
        (node.parentElement && node.parentElement.closest("article"))) return false;

    var main = node.closest("main, [role='main']");
    if (!main) return !!node.querySelector("main, [role='main']");
    // Reject the article subtree rather than repeatedly cloning the entire page.
    var walker = document.createTreeWalker(main, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
      acceptNode: function(current) {
        if (current === node || (current.nodeType === 1 && current.matches("script, style, template"))) {
          return NodeFilter.FILTER_REJECT;
        }
        if (current.nodeType === 1 && current.matches("a[href]")) {
          var url = materializedHttpUrl(current.getAttribute("href"));
          if (url && url.indexOf("#") >= 0 && url.split("#")[0] === location.href.split("#")[0]) return NodeFilter.FILTER_REJECT;
        }
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    var current;
    while ((current = walker.nextNode())) {
      if (current.nodeType === 3 && normalizeText(current.nodeValue)) return false;
      if (current.nodeType === 1 && current.matches("a[href], img, picture, video, audio, iframe, canvas, object, embed, [role='img'], input, select, textarea, button")) return false;
    }
    return true;
  }

  function genericListCardBoundary(node) {
    if (!node || !node.matches || !node.matches(genericListCardSelector())) return false;
    if (genericListPresentationCardNode(node)) return false;
    if (genericListPageContainer(node)) return false;
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
    var figure = link && link.closest && link.closest("figure");
    if (genericListFigureAnchorCard(link, figure)) return figure;
    var group = genericListLinkGroup(link);
    if (group) return group.card;
    var card = genericListContextCard(closestGenericListCard(link));
    return card || (fallback && !genericListPageContainer(fallback) ? fallback : null) || (link && link.parentElement);
  }
