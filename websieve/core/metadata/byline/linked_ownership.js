function bylineLinkedTitleField(node) {
  if (node.matches("h1, h2, h3, h4, h5, h6, [itemprop~='headline']")) return true;
  var marker = [node.getAttribute("class"), node.getAttribute("data-testid")].join(" ")
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2");
  return /(?:^|[\s_:.-])(?:title|headline|subject)(?:$|[\s_:.-])/i.test(marker);
}

function bylineLinkedTitleFields(owner, byline) {
  var selector = "h1, h2, h3, h4, h5, h6, [itemprop~='headline'], " +
    "[class*='title' i], [class*='headline' i], [class*='subject' i], [data-testid*='title' i]";
  return Array.from(owner.querySelectorAll(selector)).filter(function(field) {
    if (field.contains(byline) || byline.contains(field) || elementVisuallyHidden(field) ||
        !normalizeText(field.textContent || "") || !bylineLinkedTitleField(field)) return false;
    var heading = field.closest("h1, h2, h3, h4, h5, h6");
    if (heading && heading !== field) return false;
    if (!heading && field.querySelector("h1, h2, h3, h4, h5, h6")) return false;
    return true;
  });
}

function bylineForeignPublicationLink(link) {
  if (!link || link.matches("[rel~='author'], [itemprop~='author']") || elementVisuallyHidden(link)) return null;
  var href = materializedHttpUrl(link.getAttribute("href"));
  if (!href || localizedAuthorProfilePath(href)) return null;
  var target = href.split("#")[0];
  var pageUrls = [location.href, materializedCanonicalUrl()].filter(Boolean);
  return pageUrls.some(function(url) { return url.split("#")[0] === target; }) ? null : link;
}

function bylineForeignTitleLink(field, byline, owner) {
  var link = field.matches("a[href]") ? field : field.closest("a[href]") || field.querySelector("a[href]");
  if (!bylineForeignPublicationLink(link) || (!owner.contains(link) && !link.contains(owner))) return null;
  var titleOnly = normalizeText(link.textContent || "") === normalizeText(field.textContent || "");
  return titleOnly || (link.contains(field) && link.contains(byline)) ? link : null;
}

function bylineSharesPublicationLink(byline, titleLink, owner) {
  var link = byline.closest("a[href]");
  return bylineForeignPublicationLink(link) && (owner.contains(link) || link.contains(owner)) &&
    materializedHttpUrl(link.getAttribute("href")) === materializedHttpUrl(titleLink.getAttribute("href"));
}

function bylinePublicationHeadingField(node) {
  if (!bylineLinkedTitleField(node)) return false;
  var names = Array.from(node.querySelectorAll("[itemprop~='name'], [rel~='author']"));
  if (names.some(function(name) { return !elementVisuallyHidden(name); })) return false;
  var headings = Array.from(node.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && normalizeText(heading.textContent || "");
  });
  if (!headings.length) return false;
  var headingText = headings.map(function(heading) { return normalizeText(heading.textContent || ""); }).join(" ");
  if (normalizeText(node.textContent || "") === headingText) return true;
  return Array.from(node.querySelectorAll("a[href]")).some(function(link) {
    return bylineForeignPublicationLink(link) && normalizeText(link.textContent || "") &&
      headings.every(function(heading) { return !heading.contains(link); });
  });
}

function bylineOutsideTitleRecord(field, byline, owner) {
  var boundary = field.matches("article, [role='listitem'], [itemtype*='Article' i]") ? field : field.parentElement;
  while (boundary && boundary !== owner) {
    if (boundary.matches("article, li, [role='listitem'], [itemtype*='Article' i]") && !boundary.contains(byline)) return true;
    boundary = boundary.parentElement;
  }
  return false;
}

function linkedPublicationBylineOwner(node) {
  var owner = node && node.parentElement;
  while (owner && !owner.matches("html, body, main, [role='main']")) {
    var fields = bylineLinkedTitleFields(owner, node);
    if (fields.length) {
      if (fields.length !== 1) return null;
      var field = fields[0];
      var link = bylineForeignTitleLink(field, node, owner);
      if (!link || bylineOutsideTitleRecord(field, node, owner)) return null;
      var afterTitle = !!(field.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
      return afterTitle || bylineSharesPublicationLink(node, link, owner) ||
        owner.matches("article, li, [role='listitem'], [itemtype*='Article' i]") ? owner : null;
    }
    owner = owner.parentElement;
  }
  return null;
}

function sourceOwnedProfileByline(selectors) {
  for (var i = 0; i < selectors.length; i += 1) {
    var nodes = document.querySelectorAll(selectors[i]);
    for (var j = 0; j < nodes.length; j += 1) {
      var node = nodes[j];
      if (elementVisuallyHidden(node) || !articleBylineNode(node)) continue;
      var value = normalizeText(normalizedHeadingText(node));
      if (value) return value;
    }
  }
  return null;
}
