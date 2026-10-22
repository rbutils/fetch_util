function sourceOrderedRepeatedRecordMarkdown(item) {
  var clone = safeDeepClone(item.card, document);
  var title = normalizeText(item.text || "");
  var destination = materializedHttpUrl(item.url || "");
  clone.querySelectorAll("a[href] img[src]").forEach(function(image) {
    if (!materializedHttpUrl(image.getAttribute("src")) ||
        image.matches("[role='presentation'], [role='none'], [aria-hidden='true']") ||
        image.closest("pre, code, kbd, samp") || listImageWithinClosedDisclosure(image)) return;
    var link = image.closest("a[href]");
    var imageDestination = materializedHttpUrl(link.getAttribute("href"));
    if (!destination || !imageDestination || listCanonicalKey(destination) !== listCanonicalKey(imageDestination)) return;
    image.setAttribute("alt", repeatedRecordMediaAltText(normalizeText(image.getAttribute("alt") || ""), title));
  });
  return markdownFor(listHtmlWithoutUnsafeDestinations(clone)).trim();
}

function listImageWithinClosedDisclosure(image) {
  var ancestor = image.parentElement;
  while (ancestor) {
    if (ancestor.matches("details:not([open])")) {
      var summary = Array.from(ancestor.children).find(function(child) {
        return child.localName === "summary";
      });
      if (!summary || !summary.contains(image)) return true;
    }
    ancestor = ancestor.parentElement;
  }
  return false;
}

function listSelectedHeadingImageContext(item, primaryRecordKeys) {
  var card = item.contentCard || item.card;
  var source = item.sourceNode;
  var context = primaryRecordKeys && primaryRecordKeys.recordContext;
  if (!card || !source || !context || !card.contains(source) ||
      !source.matches("a[href]") ||
      card.closest("nav, header, footer, aside, form, button, [role='navigation'], [role='toolbar'], [role='button'], [role='tab'], [role='menuitem']")) return null;
  var heading = source.closest("h1, h2, h3, h4, h5, h6") || source.querySelector("h1, h2, h3, h4, h5, h6");
  var headings = cardOwnedNodes(card, "h1, h2, h3, h4, h5, h6");
  if (!heading || headings.length !== 1 || headings[0] !== heading ||
      !materializedHttpUrl(source.getAttribute("href"))) return null;
  var headingLinks = Array.from(heading.querySelectorAll("a[href]")).filter(function(link) {
    return !listCardNodeHidden(link);
  });
  if (!heading.contains(source)) headingLinks.push(source);
  if (headingLinks.length !== 1 || headingLinks[0] !== source) return null;

  var fallback = normalizeText(item.image || "");
  if (fallback && fallback !== normalizeText(meaningfulMediaText(item.card))) return null;
  var images = cardOwnedNodes(card, "img[src]").filter(function(image) {
    return materializedHttpUrl(image.getAttribute("src")) &&
      !listImageWithinClosedDisclosure(image) &&
      !image.closest("pre, code, kbd, samp, button, nav, form, [role='navigation'], [role='toolbar'], [role='button'], [role='tab'], [role='menuitem']");
  });
  if (!images.length) return null;
  var owners = context.imageContextOwners;
  if (!owners) owners = context.imageContextOwners = new WeakMap();
  var represented = images.filter(function(image) {
    return !owners.has(image) || owners.get(image) === item;
  });
  if (!represented.length) return null;
  represented.forEach(function(image) { owners.set(image, item); });
  return {
    markdown: represented.map(function(image) {
      var markdown = markdownFor(image.outerHTML).trim();
      var link = image.closest("a[href]");
      var destination = link && materializedHttpUrl(link.getAttribute("href"));
      var primary = materializedHttpUrl(item.url || "");
      return destination && (!primary || listCanonicalKey(destination) !== listCanonicalKey(primary)) ?
        "[" + markdown + "](" + destination + ")" : markdown;
    }).join(" "),
    images: represented.map(function(image) {
      return item.supplementalSourceClones && item.supplementalSourceClones.get(image) || image;
    })
  };
}
