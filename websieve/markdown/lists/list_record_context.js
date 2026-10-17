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
  return { byCard: byCard, headingOwners: new WeakMap(), selectedSources: selectedSources };
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
    if (!source.matches(genericListCardSelector()) || source.matches("tr, td, th") ||
        source.contains(item.sourceNode)) return;
    var records = context.byCard.get(source);
    var cloned = clones[index];
    if (cloned && cloned.tagName === source.tagName && records && records.some(function(record) {
      return record !== item && record.sourceNode && source.contains(record.sourceNode);
    })) selected.add(cloned);
  });
  return selected;
}
