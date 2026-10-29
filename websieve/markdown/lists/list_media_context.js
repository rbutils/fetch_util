function pruneSourceOrderedRecordControls(root) {
  root.querySelectorAll("span").forEach(function(node) {
    if (!root.contains(node) || node.closest("p, h1, h2, h3, h4, h5, h6, pre, code, kbd, samp") ||
        Array.from(node.querySelectorAll("*")).some(function(child) { return child.localName !== "span"; })) return;
    var text = normalizeText(node.textContent);
    if (!node.children.length) {
      var filtered = stripGenericListControlPhrases(text);
      if (filtered !== text) {
        if (filtered) node.textContent = filtered;
        else node.remove();
        return;
      }
    }
    var structured = Array.from(node.childNodes).map(function(child) { return child.textContent || ""; }).join(" ");
    if (genericListControlText(text) || genericListControlMetadataSegment(text) ||
        genericListControlMetadataSegment(structured)) node.remove();
  });
}

function listRecordCloneWithTimeDeclarations(card) {
  var clone = safeDeepClone(card, document);
  var sourceClones = new WeakMap();
  mapDomCloneElements(card, clone, sourceClones);
  materializeListTimeDeclarations(card, clone, sourceClones, cardOwnedNodes(card, "time[datetime]"));
  return clone;
}

function sourceOrderedRepeatedRecordMarkdown(item) {
  var clone = listRecordCloneWithTimeDeclarations(item.card);
  pruneSourceOrderedRecordControls(clone);
  var title = normalizeText(item.text || "");
  var destination = materializedHttpUrl(item.url || "");
  clone.querySelectorAll("a[href] img[src]").forEach(function(image) {
    if (!materializedHttpUrl(image.getAttribute("src")) ||
        image.matches("[role='presentation'], [role='none'], [aria-hidden='true']") ||
        image.closest("pre, code, kbd, samp") || listNodeWithinClosedDisclosure(image)) return;
    var link = image.closest("a[href]");
    var imageDestination = materializedHttpUrl(link.getAttribute("href"));
    if (!destination || !imageDestination || listCanonicalKey(destination) !== listCanonicalKey(imageDestination)) return;
    image.setAttribute("alt", repeatedRecordMediaAltText(normalizeText(image.getAttribute("alt") || ""), title));
  });
  return markdownFor(listHtmlWithoutUnsafeDestinations(clone)).trim();
}

function listTimeDeclarationVisible(root, time) {
  if (listCardNodeHidden(time) || listNodeWithinClosedDisclosure(time) ||
      time.closest("pre, code, kbd, samp, button, nav, [role='navigation'], [role='toolbar'], [role='button'], [role='tab'], [role='menuitem']")) return false;
  var form = time.closest("form, [role='form']");
  return !form || !root.contains(form);
}

function materializeListTimeDeclarations(root, clone, sourceClones, times) {
  times.forEach(function(time) {
    if (!listTimeDeclarationVisible(root, time)) return;
    var target = sourceClones.get(time);
    if (!target || target.localName !== "time" || !clone.contains(target) ||
        target.getAttribute("datetime") !== time.getAttribute("datetime")) return;
    var value = normalizeText(time.getAttribute("datetime") || "");
    var label = normalizeText(target.textContent);
    if (!value || label.indexOf(value) !== -1) return;
    target.appendChild(target.ownerDocument.createTextNode(label ? " (" + value + ")" : value));
  });
}

function listTimeMetadataContext(root, time, value) {
  if (!time || !time.matches("time[datetime]") ||
      normalizeText(time.getAttribute("datetime")) !== normalizeText(value) ||
      !listTimeDeclarationVisible(root, time)) return value;
  var authoredBlock = time.closest("p, h1, h2, h3, h4, h5, h6, blockquote");
  if (authoredBlock && root.contains(authoredBlock)) return value;
  var sourceClones = new WeakMap();
  var clone = visibilityPrunedClone(time, document, sourceClones);
  if (!clone) return value;
  materializeListTimeDeclarations(root, clone, sourceClones, [time]);
  return markdownFor(listHtmlWithoutUnsafeDestinations(clone)).trim() || value;
}

function listNodeWithinClosedDisclosure(node) {
  var ancestor = node.parentElement;
  while (ancestor) {
    if (ancestor.matches("details:not([open])")) {
      var summary = Array.from(ancestor.children).find(function(child) {
        return child.localName === "summary";
      });
      if (!summary || !summary.contains(node)) return true;
    }
    ancestor = ancestor.parentElement;
  }
  return false;
}

function listLinkedImageReferenceMarkdown(link, includeDestination, sourceRoot) {
  var excluded = "pre, code, kbd, samp, button, nav, form, [role='navigation'], [role='toolbar'], [role='button'], [role='tab'], [role='menuitem']";
  if (!link || !link.matches || !link.matches("a[href]") ||
      !materializedHttpUrl(link.getAttribute("href")) || normalizeText(link.textContent) ||
      normalizeText(link.getAttribute("aria-label")) || link.hasAttribute("id") || link.hasAttribute("name") ||
      link.closest(excluded) || sourceRoot && sourceRoot.closest(excluded) ||
      listCardNodeHidden(link) || listNodeWithinClosedDisclosure(link) ||
      link.querySelector("[id], a[name], pre, code, kbd, samp, button, input, select, textarea, picture, svg, video, audio, canvas, iframe, object, embed, math, script, style, template")) return "";
  var images = Array.from(link.querySelectorAll("img[src]"));
  if (!images.length || images.some(function(image) {
    return !materializedHttpUrl(image.getAttribute("src")) || image.closest(excluded) ||
      listCardNodeHidden(image) || listNodeWithinClosedDisclosure(image);
  })) return "";
  return singleBlockMaterializedHtml(materializedHtml(includeDestination ? link.outerHTML : link.innerHTML, false), true);
}

function listSelectedRecordImageContext(item, primaryRecordKeys) {
  var card = item.contentCard || item.card;
  var source = item.sourceNode;
  var context = primaryRecordKeys && primaryRecordKeys.recordContext;
  if (!card || !source || !context || !card.contains(source) ||
      !source.matches("a[href]") ||
      card.closest("nav, header, footer, aside, form, button, [role='navigation'], [role='toolbar'], [role='button'], [role='tab'], [role='menuitem']")) return null;
  var heading = source.closest("h1, h2, h3, h4, h5, h6") || source.querySelector("h1, h2, h3, h4, h5, h6");
  var headings = cardOwnedNodes(card, "h1, h2, h3, h4, h5, h6");
  var destination = materializedHttpUrl(source.getAttribute("href"));
  var primary = materializedHttpUrl(item.url || "");
  if (!destination || !primary || listCanonicalKey(destination) !== listCanonicalKey(primary)) return null;
  var linkedCover = !headings.length && !!normalizeText(source.textContent) && !!source.querySelector("img[src]");
  if (!linkedCover) {
    if (!heading || headings.length !== 1 || headings[0] !== heading) return null;
    var headingLinks = Array.from(heading.querySelectorAll("a[href]")).filter(function(link) {
      return !listCardNodeHidden(link);
    });
    if (!heading.contains(source)) headingLinks.push(source);
    if (headingLinks.length !== 1 || headingLinks[0] !== source) return null;
  }

  var fallback = normalizeText(item.image || "");
  if (fallback && fallback !== normalizeText(meaningfulMediaText(item.card))) return null;
  var images = cardOwnedNodes(card, "img[src]").filter(function(image) {
    return (!linkedCover || source.contains(image)) && materializedHttpUrl(image.getAttribute("src")) &&
      !listNodeWithinClosedDisclosure(image) &&
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
