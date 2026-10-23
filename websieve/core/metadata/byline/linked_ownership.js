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

function bylineForeignPublicationDestination(value) {
  var href = materializedHttpUrl(value);
  if (!href || localizedAuthorProfilePath(href)) return null;
  var target = href.split("#")[0];
  var pageUrls = [location.href, materializedCanonicalUrl()].filter(Boolean);
  return pageUrls.some(function(url) { return url.split("#")[0] === target; }) ? null : href;
}

function bylineForeignPublicationLink(link) {
  if (!link || link.matches("[rel~='author'], [itemprop~='author']") || elementVisuallyHidden(link)) return null;
  return bylineForeignPublicationDestination(link.getAttribute("href")) ? link : null;
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

function bylinePrincipalPublicationHeading(fields, byline, owner) {
  if (fields.length < 2 || fields.some(function(field) { return !field.matches("h1, h2, h3, h4, h5, h6"); })) return null;
  var rank = fields.reduce(function(minimum, field) {
    return Math.min(minimum, Number(field.tagName.substring(1)));
  }, Infinity);
  var principal = fields.filter(function(field) { return Number(field.tagName.substring(1)) === rank; });
  if (principal.length !== 1) return null;
  var title = principal[0];
  var titleLink = bylineForeignTitleLink(title, byline, owner);
  if (!titleLink) return null;
  var titleUrl = materializedHttpUrl(titleLink.getAttribute("href"));
  var subordinate = fields.some(function(field) {
    if (field === title) return false;
    var link = bylineForeignTitleLink(field, byline, owner);
    return link && materializedHttpUrl(link.getAttribute("href")) !== titleUrl;
  });
  return subordinate ? title : null;
}

function bylineNamedHeadingGroup(node, headings, names) {
  if (headings.length < 2 || names.length !== 1) return false;
  var name = names[0];
  var namedHeading = headings.find(function(heading) {
    return heading.contains(name) && normalizeText(heading.textContent || "") === normalizeText(name.textContent || "");
  });
  if (!namedHeading) return false;
  var namedRank = Number(namedHeading.tagName.substring(1));
  var otherHeadings = headings.filter(function(heading) { return heading !== namedHeading; });
  if (otherHeadings.some(function(heading) {
    var markers = [heading.id, heading.getAttribute("class"), heading.getAttribute("data-testid")];
    return Number(heading.tagName.substring(1)) <= namedRank ||
      heading.matches("[rel~='author'], [itemprop~='author'], [itemprop~='name']") || markers.some(inferredBylineFieldMarker);
  })) return false;
  var text = headings.map(function(heading) { return normalizeText(heading.textContent || ""); }).join(" ");
  return normalizeText(node.textContent || "") === text;
}

function bylinePublicationHeadingField(node) {
  var headings = Array.from(node.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && normalizeText(heading.textContent || "");
  });
  if (!headings.length) return false;
  var names = Array.from(node.querySelectorAll("[itemprop~='name'], [rel~='author']")).filter(function(name) {
    return !elementVisuallyHidden(name);
  });
  if (!node.matches("[rel~='author'], [itemprop~='author']") &&
      (bylineNamedHeadingGroup(node, headings, names) || bylinePrincipalPublicationHeading(headings, node, node))) return true;
  if (!bylineLinkedTitleField(node) || names.length) return false;
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

function bylineUnlinkedPrincipalTitle(owner, byline) {
  var fields = bylineLinkedTitleFields(owner, byline);
  if (!fields.length || fields.some(function(field) { return !field.matches("h1, h2, h3, h4, h5, h6"); })) return null;
  var rank = fields.reduce(function(minimum, field) {
    return Math.min(minimum, Number(field.tagName.substring(1)));
  }, Infinity);
  var principal = fields.filter(function(field) { return Number(field.tagName.substring(1)) === rank; });
  if (principal.length !== 1) return null;
  var title = principal[0];
  return title.closest("a[href]") || title.querySelector("a[href]") ? null : title;
}

function bylineLiteralPublicationDestination(owner) {
  var assignment = owner.getAttribute("onclick") || "";
  var match = assignment.match(/^\s*(?:window\.)?location(?:\.href)?\s*=\s*(["'])([^"'\\\r\n]+)\1\s*;?\s*$/);
  return match ? bylineForeignPublicationDestination(match[2]) : null;
}

function bylineAnchorlessPublication(owner, byline) {
  if (elementVisuallyHidden(owner) || owner.querySelector("a[href]") || !bylineUnlinkedPrincipalTitle(owner, byline)) return false;
  return Array.from(owner.querySelectorAll("p")).some(function(paragraph) {
    return !elementVisuallyHidden(paragraph) && normalizeText(paragraph.textContent || "");
  });
}

function bylineLiteralPublicationNavigation(owner, byline) {
  var destination = bylineLiteralPublicationDestination(owner);
  if (!destination) return null;
  var confirmedLink = Array.from(owner.querySelectorAll("a[href]")).find(function(link) {
    return bylineForeignPublicationLink(link) && materializedHttpUrl(link.getAttribute("href")) === destination;
  });
  if (confirmedLink) return confirmedLink;
  if (!owner.parentElement || !bylineAnchorlessPublication(owner, byline)) return null;
  var independentPeer = Array.from(owner.parentElement.children).some(function(peer) {
    if (peer === owner || peer.tagName !== owner.tagName) return false;
    var peerDestination = bylineLiteralPublicationDestination(peer);
    return peerDestination && peerDestination !== destination && bylineAnchorlessPublication(peer, byline);
  });
  return independentPeer ? owner : null;
}

function bylineCoveringPublicationLink(owner, title, byline) {
  var branch = title;
  while (branch && branch.parentElement !== owner) branch = branch.parentElement;
  if (!branch || !branch.contains(byline)) return null;
  var links = Array.from(owner.children).filter(function(link) {
    if (!link.matches("a[href]") || link.children.length || normalizeText(link.textContent || "")) return false;
    var marker = (link.getAttribute("class") || "").replace(/([a-z0-9])([A-Z])/g, "$1 $2");
    var declaredCover = /(?:^|[\s_:.-])(?:post|article|entry|card)[\s_:.-]+(?:link|overlay)(?:$|[\s_:.-])/i.test(marker) ||
      /(?:^|[\s_:.-])(?:overlay|stretched|cover)[\s_:.-]+link(?:$|[\s_:.-])/i.test(marker);
    return declaredCover && bylineForeignPublicationLink(link);
  });
  return links.length === 1 ? links[0] : null;
}

function unlinkedPublicationBylineOwner(node) {
  var owner = node && node.parentElement;
  while (owner && !owner.matches("html, body, main, [role='main']")) {
    var hasNavigation = owner.hasAttribute("onclick") || Array.from(owner.children).some(function(child) {
      return child.matches("a[href]") && !child.children.length && !normalizeText(child.textContent || "");
    });
    if (hasNavigation && !elementVisuallyHidden(owner)) {
      var title = bylineUnlinkedPrincipalTitle(owner, node);
      if (title && !bylineOutsideTitleRecord(title, node, owner) &&
          (bylineLiteralPublicationNavigation(owner, node) || bylineCoveringPublicationLink(owner, title, node))) return owner;
    }
    owner = owner.parentElement;
  }
  return null;
}

function linkedPublicationBylineOwner(node) {
  var mediaOwner = bylineLinkedMediaPublicationOwner(node);
  if (mediaOwner) return mediaOwner;
  var owner = node && node.parentElement;
  while (owner && !owner.matches("html, body, main, [role='main']")) {
    var fields = bylineLinkedTitleFields(owner, node);
    if (fields.length) {
      var field = fields.length === 1 ? fields[0] : bylinePrincipalPublicationHeading(fields, node, owner);
      if (!field) return null;
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
