function mixedHomepageProductListContent(metadata, products) {
  if (!homepageRootPath() || !products || !products.productListItems) return null;
  var narrative = listContent(metadata, { portalRoot: true });
  var extraction = narrative.listExtraction;
  if (!extraction || extraction.sectionCount || narrative.itemCount < 4 || !extraction.root.querySelector("p")) return null;
  var productKeys = new Set(products.productListItems.map(function(item) { return item.url && listCanonicalKey(item.url); }).filter(Boolean));
  var extraKeys = new Set(extraction.items.map(function(item) { return item.url && listCanonicalKey(item.url); }).filter(function(key) { return key && !productKeys.has(key); }));
  if (extraKeys.size < 4) return null;
  var links = Array.from(extraction.root.querySelectorAll("a[href]"));
  var nodes = Array.from(extraction.root.querySelectorAll("*"));
  var items = extraction.items.slice();
  var represented = new Set(items.map(function(item) { return item.url && listCanonicalKey(item.url); }).filter(Boolean));
  // A mixed root is usable only if it retains every already accepted product.
  var complete = products.productListItems.every(function(product) {
    if (!product.url) return false;
    var key = listCanonicalKey(product.url);
    if (represented.has(key)) return true;
    var link = links.find(function(anchor) {
      var url = materializedHttpUrl(anchor.getAttribute("href"));
      return url && listCanonicalKey(url) === key && anchor.querySelector("img[alt]");
    });
    if (!link) return false;
    items.push(Object.assign({}, product, { sourceNode: link, card: link }));
    represented.add(key);
    return true;
  });
  if (!complete || items.length === extraction.items.length) return null;
  var ranked = items.map(function(item) {
    var node = item.sourceNode || links.find(function(link) {
      var url = materializedHttpUrl(link.getAttribute("href"));
      return item.url && url && listCanonicalKey(url) === listCanonicalKey(item.url);
    }) || item.card;
    return { item: Object.assign({}, item, { sourceNode: node }), position: nodes.indexOf(node) };
  });
  if (ranked.some(function(entry) { return entry.position < 0; })) return null;
  ranked.sort(function(left, right) { return left.position - right.position; });
  extraction.items = ranked.map(function(entry) { return entry.item; });
  extraction.descText = listDescriptionMarkdown(extraction.root, extraction.items);
  extraction.markdown = listMarkdownWithDescription(extraction.descText, extraction.items);
  narrative.markdown = extraction.markdown;
  narrative.textContent = extraction.markdown;
  narrative.itemCount = extraction.items.length;
  narrative.sectionMarkdownWithDescription = sectionedListMarkdownWithDescriptions(
    { regions: [{ node: extraction.root, cards: extraction.items }] },
    listDescriptionParts(extraction.root, extraction.items, { includeInlineProse: true })
  );
  return narrative;
}
