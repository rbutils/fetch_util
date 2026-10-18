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
  return { byCard: byCard, headingOwners: new WeakMap(), referenceOwners: new WeakMap(), selectedSources: selectedSources };
}

function listSelectedReferenceContextOwner(card, context) {
  if (!context || !context.referenceOwners || !card.matches("div, section, article, aside")) return null;
  if (context.referenceOwners.has(card)) return context.referenceOwners.get(card);
  var records = context.byCard.get(card);
  var owner = null;
  if (records && records.length > 1 && records.every(function(record) {
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
  var html = listHtmlWithoutUnsafeDestinations(card);
  if (!context || !context.representedHeadings) return markdownFor(html).trim();
  var clone = document.createElement("div");
  clone.innerHTML = html;
  var selector = "h1, h2, h3, h4, h5, h6";
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
