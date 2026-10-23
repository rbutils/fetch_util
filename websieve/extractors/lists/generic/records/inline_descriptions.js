  function listInlineDescriptionNode(node) {
    if (!paragraphLikeDiv(node) || node.closest("a, button, label, summary, p, table, ul, ol, pre, code, blockquote") ||
        node.querySelector("button, input, select, textarea, label, video, audio, canvas, object, iframe")) return false;

    var hiddenSelector = "[aria-hidden='true' i], [inert]";
    if (node.closest(hiddenSelector) || Array.prototype.some.call(node.querySelectorAll(hiddenSelector), function(hidden) {
      return !!normalizeText(hidden.textContent);
    })) return false;
    if (node.closest(COMMON_CHROME_SELECTOR + ", header, dialog, [role='dialog'], [aria-modal='true'], [role='navigation'], [role='menu'], [role='toolbar']")) return false;
    if (AD_LABEL_TEXT_PATTERN.test(normalizeText(node.textContent))) return false;
    if (node.classList.contains("vjs-modal-dialog-content") && videoFallbackText(node.textContent)) return false;

    var withoutMetadata = node.cloneNode(true);
    var metadata = withoutMetadata.querySelectorAll("time, [datetime], [rel='author'], [itemprop='author'], [class*='author' i], [class*='score' i], [class*='reply' i], [class*='replies' i], [class*='community' i]");
    if (metadata.length) {
      metadata.forEach(function(field) { field.remove(); });
      if (!/\p{L}/u.test(normalizeText(withoutMetadata.textContent))) return false;
    }

    for (var owner = node; owner; owner = owner.parentElement) {
      var identity = [owner.id, owner.getAttribute("class")].join(" ").replace(/([a-z])([A-Z])/g, "$1-$2");
      if (/(cookie|consent|privacy)[-_\s]*(modal|dialog|banner|notice|popup|container)/i.test(identity)) return false;
    }

    // Inline link collections are records, not a paragraph describing those records.
    if (node.querySelector("a[href]")) {
      var prose = node.cloneNode(true);
      prose.querySelectorAll("a").forEach(function(link) { link.remove(); });
      prose.querySelectorAll("time, [datetime]").forEach(function(time) { time.remove(); });
      var remainder = normalizeText(prose.textContent)
        .replace(/\b\d+(?:\.\d+)?\s*(?:seconds?|minutes?|hours?|days?|weeks?|months?|years?)\s+ago\b/gi, "")
        .replace(/\b\d+(?:\.\d+)?[kmb](?=\s|$)/gi, "");
      if (!/\p{L}/u.test(remainder)) return false;
    }
    return true;
  }

  function listPublicationCreditDescriptionParts(root, items, descriptions) {
    if (!items || !items.length) return [];
    return Array.from(root.querySelectorAll("span")).filter(function(node) {
      var markers = [node.id, node.getAttribute("class"), node.getAttribute("data-testid")];
      if (!markers.some(inferredBylineFieldMarker) && !node.matches("[itemprop~='author'], [rel~='author']")) return false;
      if (node.closest("a, p, blockquote, table, ul, ol, pre, code, kbd, samp, nav, header, footer, aside, form, button, label, summary, menu, dialog, [role='button'], [role='navigation'], [role='menu'], [role='toolbar'], [role='dialog']") ||
          listCardNodeHidden(node) || listNodeWithinClosedDisclosure(node)) return false;
      if (!normalizeText(node.textContent) ||
          node.querySelector("p, h1, h2, h3, h4, h5, h6, img, picture, video, audio, iframe, input, select, textarea, button, script, style, template")) return false;
      if (descriptions.some(function(part) { return part.node && part.node.contains(node); })) return false;
      if (items.some(function(item) {
        return (item.sourceOrderedRepeatedRecord || item.sourceOrderedStructuredCard) &&
          item.card && item.card.contains(node);
      })) return false;
      return !!bylineLinkedMediaPublicationOwner(node);
    }).map(function(node) {
      var clone = node.cloneNode(true);
      pruneListCardVisibility(node, clone);
      return { node: node, markdown: markdownFor(clone.outerHTML).trim(), publicationCredit: true };
    }).filter(function(part) { return part.markdown; });
  }

  function listUnownedEmptyReference(link, root, recordContext, descriptionOwners) {
    if (link.querySelector("img, picture, svg, video, audio, canvas, object, iframe") ||
        link.closest("pre, code, [aria-hidden='true' i], [inert]") || listCardNodeHidden(link)) return false;
    var url = materializedHttpUrl(link.getAttribute("href"));
    if (!url || emptyMarkdownSelfControl(link, url, root)) return false;
    for (var owner = link; owner; owner = owner.parentElement) {
      if (recordContext.selectedSources.has(owner) || recordContext.byCard.has(owner) ||
          descriptionOwners.has(owner)) return false;
      if (owner.matches("details:not([open])")) {
        var summary = Array.from(owner.children).find(function(child) { return child.tagName === "SUMMARY"; });
        if (!summary || !summary.contains(link)) return false;
      }
      if (owner === root) return true;
    }
    return false;
  }

  function listUnrepresentedMetadataReferences(extraction, descriptions) {
    var primaryRecordKeys;
    var unownedReferences = new WeakSet();
    var descriptionOwners = new WeakSet();
    descriptions.forEach(function(part) {
      (part.sourceNodes || [part.node]).filter(Boolean).forEach(function(node) { descriptionOwners.add(node); });
    });
    var links = Array.from(extraction.root.querySelectorAll("a[href]")).filter(function(link) {
      if (link.closest("nav, header, footer, form, menu, dialog, [role='navigation'], [role='menu'], [role='toolbar'], [aria-modal='true']")) return false;
      var text = normalizeText(link.textContent);
      if (!text) {
        primaryRecordKeys = primaryRecordKeys || listPrimaryRecordKeys(extraction.items);
        if (!listUnownedEmptyReference(link, extraction.root, primaryRecordKeys.recordContext, descriptionOwners)) return false;
        unownedReferences.add(link);
        return true;
      }
      var namedField = Array.from(link.classList || []).some(function(name) {
        return /^(?:card|story|teaser|result|news|headline)[-_]+(?:tags?|topics?|categor(?:y|ies))(?:[-_]|$)/i.test(name) ||
          /^(?:Card|Story|Teaser|Result|News|Headline)(?:Tags?|Topics?|Categor(?:y|ies))(?:[-_]|$)/.test(name);
      }) && !link.querySelector("h1, h2, h3, h4") && Array.from(link.querySelectorAll("p")).every(function(paragraph) {
        return normalizeText(paragraph.textContent) === text;
      });
      return text && (namedField || link.matches("[rel~='tag'], [itemprop~='keywords'], [itemprop~='about']") || /^(?:topics?|categor(?:y|ies)|tags?)\s*:\s*\S/i.test(text));
    });
    if (!links.length) return [];
    var primaryUrls = new Set(extraction.items.map(function(item) {
      var url = materializedHttpUrl(item.url || "");
      return url && listCanonicalKey(url);
    }).filter(Boolean));
    primaryRecordKeys = primaryRecordKeys || listPrimaryRecordKeys(extraction.items);
    var rendered = extraction.items.map(function(item) {
      return { node: item.card || item.sourceNode, markdown: listMarkdown([item], primaryUrls, primaryRecordKeys) };
    }).concat(descriptions);
    return links.map(function(link) {
      var url = materializedHttpUrl(link.getAttribute("href"));
      var text = normalizeText(link.textContent);
      if (unownedReferences.has(link)) {
        var label = inlineLinkLabel(link) || normalizeText(link.getAttribute("title")) || url;
        return { node: link, markdown: markdownLink(label, url), metadataReference: true };
      }
      if (!url || primaryUrls.has(listCanonicalKey(url)) || genericListControlText(text) || looksLikeFooterLink(text, url)) return null;
      var destination = "](" + listPresentationUrl(url) + ")";
      if (rendered.some(function(part) {
        return part.node && part.node.contains(link) && part.markdown.indexOf(destination) !== -1;
      })) return null;
      return { node: link, markdown: markdownLink(text, url), metadataReference: true };
    }).filter(Boolean);
  }

  function listMarkdownWithMetadataReferences(extraction) {
    if (!extraction.renderedSections) return "";
    var descriptions = extraction.renderedDescriptions || [];
    var references = listUnrepresentedMetadataReferences(extraction, descriptions);
    if (!references.length) return "";
    return sectionedListMarkdownWithDescriptions(extraction.renderedSections, descriptions.concat(references));
  }

  function listMarkdownWithInlineDescriptions(extraction) {
    var descriptions = listDescriptionParts(extraction.root, extraction.items, {
      includeInlineProse: true, preserveUnrepresentedText: true
    });
    descriptions = descriptions.concat(listUnrepresentedMetadataReferences(extraction, descriptions));
    var wrappedRecords = extraction.items.some(function(item) { return genericListWrappedAnchorCard(item.card); });
    if (!wrappedRecords && !descriptions.some(function(part) {
      return part.metadataReference || part.publicationCredit || part.node.tagName === "DIV";
    })) return "";

    var links = Array.prototype.slice.call(extraction.root.querySelectorAll("a[href]"));
    var cards = extraction.items.map(function(item) {
      if (item.sourceNode) return item;
      var key = item.url && listCanonicalKey(item.url);
      var link = key && links.find(function(candidate) {
        if (item.card && !item.card.contains(candidate)) return false;
        var url = materializedHttpUrl(candidate.getAttribute("href"));
        return url && listCanonicalKey(url) === key;
      });
      return Object.assign({}, item, { sourceNode: link || item.card || extraction.root });
    });
    return sectionedListMarkdownWithDescriptions({ regions: [{ node: extraction.root, cards: cards }] }, descriptions);
  }
