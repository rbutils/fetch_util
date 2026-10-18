function listPrimaryRecordContext(items) {
  var byCard = new WeakMap();
  var selectedSources = new WeakSet();
  (items || []).forEach(function(item) {
    if (!item.sourceNode) return;
    selectedSources.add(item.sourceNode);
    var mappedSource = item.supplementalSourceClones && item.supplementalSourceClones.get(item.sourceNode);
    if (mappedSource) selectedSources.add(mappedSource);
    if (!item.card) return;
    var records = byCard.get(item.card);
    if (!records) {
      records = [];
      byCard.set(item.card, records);
    }
    records.push(item);
  });
  return {
    byCard: byCard,
    headingOwners: new WeakMap(),
    referenceOwners: new WeakMap(),
    mediaOwners: new WeakMap(),
    unlabeledPeerOwners: new WeakMap(),
    selectedSources: selectedSources
  };
}

function listUnlabeledReferencePeer(link) {
  return !normalizeText(link.textContent || "") &&
    !normalizeText(link.getAttribute("aria-label") || "") &&
    !normalizeText(link.getAttribute("title") || "");
}

function listSelectedUnlabeledReferenceContextOwner(card, records) {
  if (!records || records.length !== 1 ||
      card.closest("nav, [role='navigation'], [role='toolbar'], [role='button']") ||
      card.querySelector("p, h1, h2, h3, h4, h5, h6, ul, ol, li, dl, blockquote, pre, code, table, figure, img, picture, svg, video, audio, canvas, object, iframe, form, input, button, select, textarea, time, [datetime], [rel~='author'], [aria-controls], [role='button']")) return null;
  var source = records[0].sourceNode;
  if (!source || source.parentElement !== card || !source.matches("a[href]")) return null;
  var links = Array.from(card.children).filter(function(node) { return !listCardNodeHidden(node); });
  if (!links.includes(source) || !links.every(function(link) {
    return link.matches("a[href]") && materializedHttpUrl(link.getAttribute("href")) &&
      (normalizeText(link.textContent || "") || listUnlabeledReferencePeer(link));
  })) return null;
  if (Array.from(card.childNodes).some(function(node) {
    return node.nodeType === 3 && normalizeText(node.textContent || "");
  })) return null;
  return links.some(function(link) {
    return link !== source && listUnlabeledReferencePeer(link);
  }) ? records[0] : null;
}

function listSelectedMediaContextOwner(card, records) {
  if (!records || records.length < 2 || card.querySelector("pre, code, table, form, input, button, select, textarea, nav, [role='navigation'], [role='toolbar']")) return null;

  function mediaRecord(node, destination) {
    var headings = Array.from(node.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(heading) {
      return !heading.closest("a[href]") && !listCardNodeHidden(heading) && normalizeText(heading.textContent);
    });
    var images = Array.from(node.querySelectorAll("img[src]")).filter(function(image) {
      return !listCardNodeHidden(image) && materializedHttpUrl(image.getAttribute("src"));
    });
    var links = Array.from(node.querySelectorAll("a[href]")).filter(function(link) { return !listCardNodeHidden(link); });
    if (!headings.length || !images.length || !links.length) return false;
    var primary = destination || materializedHttpUrl(links[0].getAttribute("href"));
    return !!primary && links.every(function(link) {
      var url = materializedHttpUrl(link.getAttribute("href"));
      return url && listCanonicalKey(url) === listCanonicalKey(primary);
    });
  }

  var owners = [];
  for (var record of records) {
    var source = record.sourceNode;
    if (!source || !source.matches("a[href]") || source.closest("h1, h2, h3, h4, h5, h6") ||
        source.querySelector("h1, h2, h3, h4, h5, h6") || !card.contains(source)) return null;
    var owner = source.parentElement;
    var destination = materializedHttpUrl(record.url || "");
    while (owner && owner !== card && !mediaRecord(owner, destination)) owner = owner.parentElement;
    if (!owner || owner === card || owners.indexOf(owner) !== -1) return null;
    owners.push(owner);
  }
  var parent = owners[0].parentElement;
  if (!parent || !owners.every(function(owner) { return owner.parentElement === parent; })) return null;
  var peers = Array.from(parent.children).filter(function(node) {
    return !node.matches("script, style, template") && !listCardNodeHidden(node);
  });
  return peers.every(function(peer) { return mediaRecord(peer); }) ? records[0] : null;
}

function listSelectedReferenceContextOwner(card, context) {
  if (!context || !context.referenceOwners || !card.matches("div, section, article, aside")) return null;
  if (context.referenceOwners.has(card)) return context.referenceOwners.get(card);
  var records = context.byCard.get(card);
  var owner = listSelectedUnlabeledReferenceContextOwner(card, records);
  if (owner) context.unlabeledPeerOwners.set(card, owner);
  if (!owner) {
    owner = listSelectedMediaContextOwner(card, records);
    if (owner) context.mediaOwners.set(card, owner);
  }
  if (!owner && records && records.length > 1 && card.querySelector("h1, h2, h3, h4, h5, h6") && records.every(function(record) {
    return record.sourceNode && record.sourceNode.matches("a[href]") && card.contains(record.sourceNode) &&
      !record.sourceNode.closest("h1, h2, h3, h4, h5, h6");
  }) && !card.querySelector("p, blockquote, pre, code, table, figure, img, picture, svg, video, audio, canvas, object, iframe, form, input, button, select, textarea, time, [datetime], [rel~='author']") &&
      !card.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href], h5 a[href], h6 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4, a[href] h5, a[href] h6")) {
    var remainder = card.cloneNode(true);
    remainder.querySelectorAll("a[href], h1, h2, h3, h4, h5, h6, br").forEach(function(node) { node.remove(); });
    if (!normalizeText(remainder.textContent || "")) owner = records[0];
  }
  context.referenceOwners.set(card, owner);
  return owner;
}

function listSelectedReferenceGroupMarkdown(card, context) {
  if (context && context.unlabeledPeerOwners && context.unlabeledPeerOwners.has(card)) {
    var peers = card.cloneNode(true);
    pruneListCardVisibility(card, peers);
    peers.querySelectorAll("a[href]").forEach(function(link) {
      var destination = materializedHttpUrl(link.getAttribute("href"));
      if (destination && listUnlabeledReferencePeer(link)) {
        link.textContent = destination;
        link.after(peers.ownerDocument.createElement("br"));
      }
    });
    return markdownFor(listHtmlWithoutUnsafeDestinations(peers)).trim();
  }
  var html = listHtmlWithoutUnsafeDestinations(card);
  var mediaGroup = !!(context && context.mediaOwners && context.mediaOwners.has(card));
  if (!mediaGroup && (!context || !context.representedHeadings)) return markdownFor(html).trim();
  var clone = document.createElement("div");
  clone.innerHTML = html;
  var selector = "h1, h2, h3, h4, h5, h6";
  if (mediaGroup) {
    clone.querySelectorAll(selector).forEach(function(heading) {
      heading.querySelectorAll("br").forEach(function(lineBreak) {
        lineBreak.replaceWith(document.createTextNode(" "));
      });
    });
    return markdownFor(clone.innerHTML).trim();
  }
  var headings = card.querySelectorAll(selector);
  var copies = clone.querySelectorAll(selector);
  if (headings.length === copies.length) {
    Array.prototype.forEach.call(headings, function(heading, index) {
      if (context.representedHeadings.has(heading) && copies[index].tagName === heading.tagName) copies[index].remove();
    });
  }
  return markdownFor(clone.innerHTML).trim();
}

function listSelectedHeadingContextOwner(card, records) {
  var selector = "h1 a[href], h2 a[href], h3 a[href], h4 a[href], a[href] h1, a[href] h2, a[href] h3, a[href] h4";
  var headings = cardOwnedNodes(card, selector).filter(function(node) {
    var link = node.matches("a[href]") ? node : node.closest("a[href]");
    return !genericListAuthorMetadataNode(link) && !genericListInteractionOwner(link);
  });
  var links = headings.map(function(node) {
    return node.matches("a[href]") ? node : node.closest("a[href]");
  });
  var primaryUrl = links.length && materializedHttpUrl(links[0].getAttribute("href"));
  if (!primaryUrl || !links.every(function(link) {
    var url = materializedHttpUrl(link.getAttribute("href"));
    return url && listCanonicalKey(url) === listCanonicalKey(primaryUrl);
  })) return null;
  var headingLinks = new WeakSet(links);
  return records.find(function(record) {
    return headingLinks.has(record.sourceNode);
  }) || null;
}

function listItemOwnsCardContext(item, primaryRecordKeys) {
  var context = primaryRecordKeys && primaryRecordKeys.recordContext;
  var card = item.card, source = item.sourceNode;
  if (!context || !card || !source || !source.closest || !card.contains(source)) return true;
  var records = context.byCard.get(card);
  if (!records || records.length < 2) return true;
  var heading = source.closest("h1, h2, h3, h4") || source.querySelector("h1, h2, h3, h4");
  if (heading && card.contains(heading)) return true;
  if (!context.headingOwners.has(card)) {
    context.headingOwners.set(card, listSelectedHeadingContextOwner(card, records));
  }
  var owner = context.headingOwners.get(card);
  var ownerUrl = owner && materializedHttpUrl(owner.url || "");
  var itemUrl = materializedHttpUrl(item.url || "");
  return !owner || owner === item || !ownerUrl || !itemUrl ||
    listCanonicalKey(ownerUrl) === listCanonicalKey(itemUrl);
}

function listSeparatelySelectedChildClones(item, card, clone, primaryRecordKeys) {
  var selected = new WeakSet();
  var context = primaryRecordKeys && primaryRecordKeys.recordContext;
  if (!context || !item.sourceNode || !card.contains(item.sourceNode)) return selected;
  var sources = card.querySelectorAll("*");
  var clones = clone.querySelectorAll("*");
  if (sources.length !== clones.length) return selected;
  Array.prototype.forEach.call(sources, function(source, index) {
    if (source.matches("tr, td, th") || source.contains(item.sourceNode)) return;
    var records = context.byCard.get(source);
    var selectedCard = records && (source.matches(genericListCardSelector()) || listSelectedReferenceContextOwner(source, context)) &&
      records.some(function(record) {
        return record !== item && record.sourceNode && source.contains(record.sourceNode);
      });
    var cloned = clones[index];
    if (cloned && cloned.tagName === source.tagName && selectedCard) selected.add(cloned);
  });
  return selected;
}
