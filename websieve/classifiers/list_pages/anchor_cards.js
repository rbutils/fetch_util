  function genericListPresentationCardNode(node) {
    if (genericListAlignmentOnlyCard(node)) return true;
    if (genericListActionAnchor(node)) return true;
    // A wrapper inside the record's own anchor does not own a separate destination.
    var enclosingLink = node && node.closest && node.closest("a[href]");
    if (enclosingLink && enclosingLink !== node && !node.querySelector("a[href]")) return true;
    if (node && node.matches && !node.matches("a[href], article, li, tr, .post, .entry, .product, .product-tile, [itemtype$='/Product']") &&
        !node.querySelector("a[href]")) return true;
    var classes = ((node && node.getAttribute && node.getAttribute("class")) || "").split(/\s+/);
    return classes.some(function(name) {
      return /^(?:card|story|teaser|result|news|headline)[-_]+(?:body|content|meta(?:data)?|header|footer|details?)(?:[-_].*)?$/i.test(name) ||
        /^(?:Card|Story|Teaser|Result|News|Headline)(?:Body|Content|Meta(?:data)?|Header|Footer|Details?)(?:[-_A-Z].*)?$/.test(name) ||
        /styles__(?:(?:Card|Story|Teaser|Result|News|Headline)(?:Body|Content|Meta(?:data)?|Header|Footer|Details?|Title|Headline|Heading|Image|Media|Thumbnail)|(?:Title|Headline|Heading|Meta(?:data)?|Image|Media|Thumbnail|Kicker|Eyebrow))(?:[-_A-Z].*)?$/.test(name) ||
        /^item[-_]+meta(?:data)?(?:[-_].*)?$/i.test(name);
    });
  }

  function genericListAlignmentOnlyCard(node) {
    if (!node || !node.matches || node.matches("a[href], tr, article, li, .post, .entry, .product, .product-tile, [itemtype$='/Product']")) return false;
    var classes = Array.from(node.classList || []);
    var recordClasses = classes.filter(function(name) {
      return !/(?:^|:)(?:(?:justify|place)-)?items-(?:(?:start|end|center)(?:-safe)?|baseline|stretch|normal|\[[^\]]+\])$/i.test(name);
    });
    return recordClasses.length < classes.length && !recordClasses.some(function(name) {
      return /card|story|teaser|item|result|news|headline/i.test(name);
    }) && !node.matches(genericListLinkedMediaRowSelector());
  }

  function genericListActionAnchor(node) {
    var explicitAction = node && Array.prototype.some.call(node.classList || [], function(name) {
      return /^(?:card|story|teaser|result|news)[-_](?:cta|action)(?:[-_].*)?$/i.test(name);
    });
    return !!(node && node.matches && node.matches("a[href]") &&
      Array.prototype.some.call(node.classList, function(name) {
        return /^(?:card|story|teaser|result|news)[-_](?:cta|link|action)(?:[-_].*)?$/i.test(name);
      }) && !genericListAnchorRecordEvidence(node, !explicitAction));
  }

  function genericListAnchorCardSelector() {
    return "a[href]:has([class$='-name' i]:not(:empty)):has([class$='-desc' i]:not(:empty)), " +
      "a[href]:has(h1, h2, h3, h4):has(p), a[href]:has([class$='-name' i]):has(time, [datetime], [class*='date' i]), " +
      "a[href]:has([class*='title' i]):has([class*='description' i])";
  }

  function genericListPrimaryHeadingLink(record) {
    if (!record || !record.querySelectorAll) return null;
    var links = Array.from(record.querySelectorAll("h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4")).map(function(node) {
      return node.matches("a[href]") ? node : node.closest("a[href]");
    }).filter(function(node, index, all) { return node && all.indexOf(node) === index; });
    return links.length === 1 && genericListAnchorRecordEvidence(links[0]) ? links[0] : null;
  }

  function genericListAuthorMetadataNode(node) {
    if (!node || !node.matches) return false;
    if (node.matches("[rel~='author'], [itemprop~='author'], [data-author]")) return true;
    return Array.prototype.some.call(node.classList || [], function(className) {
      var normalized = className.replace(/([a-z\d])([A-Z])/g, "$1-$2");
      if (/(?:^|[-_])author(?:item|link|name)?(?:$|[-_])/i.test(normalized)) return true;
      return /(?:^|[-_])byline(?:$|[-_](?:authors?|names?|links?|credits?|meta|text|label|row|block|wrapper|container|date|info)(?:$|[-_]))/i.test(normalized);
    });
  }

  function genericListAuthorMetadataLink(link) {
    return !!(link && link.matches && link.matches("a[href]") && genericListAuthorMetadataNode(link));
  }

  function genericListInteractionOwner(node) {
    function interactionNode(candidate) {
      var names = [candidate.id || ""].concat(Array.from(candidate.classList || []));
      return names.some(function(name) {
        var normalized = String(name).replace(/([a-z])([A-Z])/g, "$1-$2");
        return /(?:^|[-_])(?:comment(?:s|ers?)?|repl(?:y|ies))(?:$|[-_](?:thread|author|byline|container|list|item|body|section|panel)(?:$|[-_]))/i.test(normalized);
      });
    }
    var current = node;
    while (current && current.matches && !current.matches("body, html, nav, header, footer, aside, menu, form, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar']")) {
      if (interactionNode(current)) return current;
      if (current !== node && current.matches("article, li, .post, .entry, [itemtype$='/Article'], [itemtype$='/NewsArticle']")) return null;
      current = current.parentElement;
    }
    return null;
  }

  function genericListRecordMetadataCard(link) {
    if (!genericListAuthorMetadataLink(link)) return null;
    var current = link.parentElement;
    while (current && !current.matches("body, html, nav, header, footer, aside, menu, form, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar']")) {
      if (current.matches("article, li, .post, .entry, [itemtype$='/Article'], [itemtype$='/NewsArticle']")) {
        return listCardNodeHidden(current) ? null : current;
      }
      current = current.parentElement;
    }
    return null;
  }

  function genericListRecordMetadataOwner(link) {
    var record = genericListRecordMetadataCard(link);
    if (!record) return null;
    var headings = Array.prototype.filter.call(record.querySelectorAll("h1, h2, h3, h4"), function(heading) {
      return normalizeText(heading.textContent || "");
    });
    if (headings.length !== 1) return null;
    var primary = genericListPrimaryHeadingLink(record);
    return primary && primary !== link ? record : null;
  }

  function genericListSupportingCard(link, candidateCard, cache) {
    function semanticSiblingRecord(card, primary) {
      if (!card.matches("article, li") || !card.parentElement || listCardNodeHidden(card)) return false;
      function soleSemanticRecord(branch) {
        var records = branch.matches("article, li") ? [branch] : Array.from(branch.querySelectorAll("article, li")).filter(function(record) {
          var owner = record.parentElement && record.parentElement.closest("article, li");
          return !owner || !branch.contains(owner);
        });
        return records.length === 1 ? records[0] : null;
      }
      if (genericListPrimaryHeadingLink(card) !== primary) return false;
      var branch = card;
      var parent = branch.parentElement;
      while (parent && !parent.matches("main, body, html, nav, header, footer, menu, form, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar']")) {
        var hasPeer = Array.from(parent.children).some(function(peer) {
          if (peer === branch || !peer.matches) return false;
          var record = soleSemanticRecord(peer);
          return !!(record && !listCardNodeHidden(record) && genericListPrimaryHeadingLink(record));
        });
        if (hasPeer) return true;
        if (parent.matches("section, aside, [role='region'], [role='complementary']") || soleSemanticRecord(parent) !== card) break;
        branch = parent;
        parent = branch.parentElement;
      }
      return false;
    }

    function structuredCardLink(card, requireBoundary) {
      if (!cache) return genericListStructuredCardLink(card, requireBoundary);
      var cached = cache.get(card) || {};
      var key = requireBoundary === false ? "detached" : "bounded";
      if (Object.prototype.hasOwnProperty.call(cached, key)) return cached[key];
      cached[key] = genericListStructuredCardLink(card, requireBoundary);
      cache.set(card, cached);
      return cached[key];
    }

    if (genericListAuthorMetadataLink(link)) {
      var interactionOwner = genericListInteractionOwner(link);
      if (interactionOwner) return interactionOwner;
      var metadataOwner = genericListRecordMetadataOwner(link);
      if (metadataOwner) return metadataOwner;
      var metadataCard = genericListRecordMetadataCard(link);
      var metadataPrimary = metadataCard && (genericListPrimaryHeadingLink(metadataCard) || structuredCardLink(metadataCard, false));
      if (metadataCard && metadataPrimary !== link) return metadataCard;
    }
    if (!link || !candidateCard || !candidateCard.contains(link) || link === candidateCard) return null;
    if (semanticSiblingRecord(candidateCard, link)) return null;
    var section = link.closest("section");
    if (section && candidateCard.contains(section) && structuredCardLink(section, false) === link) return null;
    var candidateBoundary = candidateCard.parentElement && genericListCardBoundary(candidateCard);
    if (candidateBoundary && candidateCard === link) {
      var directHeading = link.querySelector("h1, h2, h3, h4");
      var directTitle = normalizeText(directHeading && directHeading.textContent);
      if (directTitle.length >= minimumListTitleLength(directTitle) && directTitle.length <= 220) return null;
    }
    var candidatePrimary = candidateCard && candidateCard.contains(link) && !candidateBoundary && structuredCardLink(candidateCard, false);
    if (candidatePrimary && candidatePrimary !== link) return candidateCard;

    var current = link && link.parentElement;
    while (current && current !== document.body && current !== document.documentElement) {
      if (genericListCardBoundary(current)) {
        var primary = structuredCardLink(current);
        if (primary && primary !== link) return current;
        if (primary === link) return null;
      }
      current = current.parentElement;
    }
    return null;
  }

  function genericListAnchorRecordEvidence(link, includeImages) {
    var name = link.querySelector("[class$='-name' i]");
    var description = link.querySelector("[class$='-desc' i]");
    if (name && description && !listCardNodeHidden(name) && !listCardNodeHidden(description) &&
        normalizeText(name.textContent) && normalizeText(description.textContent)) return true;
    var recordEvidence = "article, time, [datetime], [class*='title' i], [class*='summary' i], [class*='description' i], [class*='excerpt' i], [class*='date' i], [class*='duration' i], [class*='count' i], [class*='view' i]";
    if (includeImages !== false) recordEvidence += ", picture, video, img[alt]:not([alt=''])";
    function visibleEvidence(node) {
      return !listCardNodeHidden(node) && (!node.matches("article") || !!normalizeText(node.textContent));
    }
    var firstEvidence = link.querySelector(recordEvidence);
    if (firstEvidence && visibleEvidence(firstEvidence)) return true;
    if (Array.prototype.some.call(link.querySelectorAll(recordEvidence), visibleEvidence)) return true;
    var text = normalizeText(link.textContent);
    if (includeImages !== false && text.length >= minimumListTitleLength(text) && !genericListControlText(text) &&
        Array.prototype.some.call(link.querySelectorAll("img[src]"), function(image) {
          return materializedHttpUrl(image.getAttribute("src")) && !elementSubtreeHidden(image);
        })) return true;
    var heading = link.querySelector("h1, h2, h3, h4");
    return !!(heading && normalizeText(heading.textContent) &&
      Array.prototype.some.call(link.querySelectorAll("p"), function(paragraph) {
        return !!normalizeText(paragraph.textContent);
      }));
  }

  function genericListWrappedAnchorCard(link) {
    if (!link || !link.matches || !link.matches("a[href]") ||
        !materializedHttpUrl(link.getAttribute("href")) || elementSubtreeHidden(link) ||
        !genericListAnchorRecordEvidence(link)) return false;
    var chromeSelector = "nav, header, footer, aside, [role='navigation'], [role='menu'], [role='menubar'], [role='complementary'], [hidden], [inert], [aria-hidden='true']";
    if (link.closest(chromeSelector)) return false;
    var knownCard = closestGenericListCard(link.parentElement);
    var wrapper = link.parentElement;
    if (!wrapper || wrapper.querySelectorAll("a[href]").length !== 1 || normalizeText(wrapper.textContent) !== normalizeText(link.textContent)) return false;
    var destination = materializedHttpUrl(link.getAttribute("href"));
    while (wrapper && wrapper.parentElement && !wrapper.matches("main, body, html")) {
      var hasIndependentPeer = Array.prototype.some.call(wrapper.parentElement.children, function(peer) {
        var links = peer.querySelectorAll("a[href]");
        var anchor = links.length === 1 && links[0];
        if (!anchor || anchor === link) return false;
        var url = materializedHttpUrl(anchor.getAttribute("href"));
        return !!(url && url !== destination && !anchor.closest(chromeSelector) && !elementSubtreeHidden(anchor) &&
          normalizeText(peer.textContent) === normalizeText(anchor.textContent) &&
          genericListAnchorRecordEvidence(anchor));
      });
      if (hasIndependentPeer) return true;
      if (wrapper === knownCard) break;
      wrapper = wrapper.parentElement;
    }
    return false;
  }

  function genericListDirectAnchorCard(link, container) {
    if (!link || !container || !link.matches("a[href]") || !genericListAnchorRecordEvidence(link)) return false;
    if (link.parentElement !== container) return genericListWrappedAnchorCard(link);
    var peers = Array.prototype.filter.call(container.children, function(child) {
      return child.matches && child.matches("a[href]") &&
        materializedHttpUrl(child.getAttribute("href")) && genericListAnchorRecordEvidence(child);
    });
    return peers.length >= 2 || genericListWrappedAnchorCard(link);
  }

  function genericListMixedAnchorCollection(link) {
    var parent = link && link.parentElement;
    if (!parent || !link.matches("a[href]") || listChromeNode(parent) || listChromeAncestor(link)) return false;
    var children = Array.from(parent.children).filter(function(node) {
      if (node.matches("script, style, template") || elementSubtreeHidden(node)) return false;
      return !node.matches("div, span") || node.children.length || normalizeText(node.textContent) ||
        node.hasAttribute("role") || node.hasAttribute("aria-label") || node.hasAttribute("title");
    });
    if (children.length < 2 || children.indexOf(link) < 0 || children.some(function(node) {
      return !node.matches("a[href]") || node.querySelector("a[href]") ||
        !materializedHttpUrl(node.getAttribute("href")) || !normalizeText(node.textContent);
    })) return false;
    if (Array.from(parent.childNodes).some(function(node) {
      return node.nodeType === 3 && normalizeText(node.textContent);
    })) return false;
    var destinations = new Set(children.map(function(node) { return materializedHttpUrl(node.getAttribute("href")); }));
    var rich = children.filter(function(node) { return genericListAnchorRecordEvidence(node); });
    return destinations.size >= 2 && rich.length > 0 && rich.length < children.length;
  }
