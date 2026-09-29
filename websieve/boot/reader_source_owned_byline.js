function readerSourceOwnedBylineExtension(content, metadata, contentByline, metadataByline) {
  if (!content || content.contentType !== "article" || content.readerMode || content.sourceOwnedLiveblog === true || content.isolatedLiveblogEntry || !content.html) return null;

  if (content.sourceOwnedFocalArticle === true && content.sourceOwnedArticleBody) {
    var semantic = sourceOwnedSemanticArticleOwnership(metadata || {}).ownership;
    var ownsSelectedBody = semantic && semantic.body.sourceNode.contains(content.sourceOwnedArticleBody);
    var semanticByline = ownsSelectedBody ? readerSourceOwnedSemanticHeaderByline(semantic) : null;
    if (semanticByline) return readerSourceOwnedBylineDecision(semanticByline, content, metadata, contentByline, metadataByline);
  }

  var selected = document.createElement("div");
  selected.innerHTML = content.html;
  Array.from(selected.querySelectorAll("h1")).forEach(function(heading) { heading.remove(); });
  var sourceHeadings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    return !elementSubtreeHidden(heading) && !heading.closest("header, nav, footer, aside, form, [role='navigation']");
  });
  if (sourceHeadings.length !== 1) return null;
  var sourceTitle = normalizeText(sourceHeadings[0].textContent || "");
  var declaredTitle = normalizeText(content.title || metadata.title || "");
  var siteName = normalizeText(content.siteName || metadata.siteName || "");
  if (normalizeText(articleTitleFromOwnedHeading(content.html, declaredTitle, siteName)) !== sourceTitle) return null;
  var evidence = sourceOwnedReaderArticleLeadEvidence(selected.innerHTML, sourceTitle);
  if (!evidence) return null;

  var owner = evidence.heading.parentElement;
  while (owner && owner !== document.body && owner.querySelectorAll("p").length < 3) owner = owner.parentElement;
  if (!owner || owner === document.body || owner.querySelectorAll("h1").length !== 1) return null;
  var leads = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
    return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent) === evidence.lead;
  });
  if (leads.length !== 1) return null;

  var metadataName = readerTextBylineName(metadata && metadata.declaredByline || metadataByline);
  siteName = normalizeText(content.siteName || metadata.siteName || "");
  for (var header = evidence.heading.parentElement; header && owner.contains(header); header = header.parentElement) {
    var dates = sourceOwnedArticleHeaderDateNodes([header]);
    var values = readerSourceOwnedHeaderBylineCandidates(
      header,
      evidence.heading,
      leads[0],
      metadataName,
      dates.length === 1
    );
    if (values.length === 1) return readerSourceOwnedBylineDecision(values[0], content, metadata, contentByline, metadataByline);
    if (values.length > 1) return null;
    if (header === owner) break;
  }
  return null;
}

function readerSourceOwnedBylineDecision(candidate, content, metadata, contentByline, metadataByline) {
  var siteName = normalizeText(content.siteName || metadata.siteName || location.hostname);
  if (readerSourceOwnedBylineIsAuthoritative(contentByline, siteName)) {
    return readerSourceOwnedBylineExtendsExisting(candidate, contentByline) ? candidate : null;
  }

  if (readerSourceOwnedBylineIsAuthoritative(metadataByline, siteName)) {
    return readerSourceOwnedBylineExtendsExisting(candidate, metadataByline) ? candidate : null;
  }

  if (readerSourceOwnedBylineIsAuthoritative(metadata.declaredByline, siteName)) {
    return readerSourceOwnedBylineExtendsExisting(candidate, metadata.declaredByline) ? candidate : null;
  }

  return candidate;
}

function readerSourceOwnedBylineIsAuthoritative(value, siteName) {
  var normalized = normalizeText(value || "");
  if (!normalized) return false;
  var name = normalizeText(readerTextBylineName(normalized) || normalized).toLowerCase();
  var publisher = normalizeText(siteName || "").replace(/^www\./i, "").toLowerCase();
  var host = normalizeText(location.hostname || "").replace(/^www\./i, "").toLowerCase();
  return name !== publisher && name !== host;
}

function readerSourceOwnedBylineExtendsExisting(candidate, existing) {
  var source = normalizeText(readerTextBylineName(candidate) || candidate || "").toLowerCase();
  var current = normalizeText(readerTextBylineName(existing) || existing || "").toLowerCase();
  if (!source || !current) return false;
  if (source === current) return true;
  return source.indexOf(current) === 0 && /[\s:·•|,–—-]/u.test(source.charAt(current.length));
}

function readerSourceOwnedSemanticHeaderByline(ownership) {
  if (!ownership || !ownership.headerContext) return null;
  var roots = sourceOwnedArticleHeaderNodes(ownership.headerContext);
  var dates = sourceOwnedArticleHeaderDateNodes(roots);
  if (dates.length !== 1) return null;
  var selector = "[rel~='author' i], [itemprop~='author' i], [class*='author-name' i], " +
    "[class*='byline' i], [class*='writer' i], [class*='reporter' i]";
  var authors = [];
  var plainBylines = [];
  roots.forEach(function(root) {
    if (root.matches(selector)) authors.push(root);
    authors = authors.concat(Array.from(root.querySelectorAll(selector)));
    if (root.matches("p, address")) plainBylines.push(root);
    plainBylines = plainBylines.concat(Array.from(root.querySelectorAll("p, address")));
  });
  authors = authors.filter(function(node, index) {
    return authors.indexOf(node) === index && !elementSubtreeHidden(node) &&
      !node.closest("nav, aside, footer, form, [role~='navigation' i], [role~='complementary' i]") &&
      !node.querySelector(selector) && normalizeText(node.textContent || "");
  });
  plainBylines = plainBylines.filter(function(node, index) {
    var text = normalizeText(node.textContent || "");
    return plainBylines.indexOf(node) === index && !elementSubtreeHidden(node) &&
      !node.closest("nav, aside, footer, form, [role~='navigation' i], [role~='complementary' i]") &&
      !node.querySelector(selector) && !node.querySelector("a[href], img, picture, svg, video, audio, figure, time") &&
      text && !visiblePublicationDateLike(text);
  });
  if (authors.length && plainBylines.length) return null;
  if (authors.length === 1) {
    return normalizeText(authors[0].textContent || "");
  }
  if (authors.length > 1 && sourceOwnedArticleAuthorsShareGroup(authors, selector)) {
    return authors.map(function(node) { return normalizeText(node.textContent || ""); }).join(" ");
  }
  if (authors.length > 1) return null;
  if (plainBylines.length === 1) return normalizeText(plainBylines[0].textContent || "");
  if (plainBylines.length > 1) return null;

  var current = sourceOwnershipPageUrl(location.href);
  var currentOrigin = current ? new URL(current).origin : "";
  if (!currentOrigin) return null;
  var links = [];
  roots.forEach(function(root) {
    if (root.matches("a[href]")) links.push(root);
    links = links.concat(Array.from(root.querySelectorAll("a[href]")));
  });
  links = links.filter(function(link, index) {
    if (links.indexOf(link) !== index || elementSubtreeHidden(link) || link.closest("h1, h2, h3, h4")) return false;
    var label = normalizeText(link.textContent || "");
    var destination = sourceOwnershipPageUrl(link.getAttribute("href"));
    if (!label || visiblePublicationDateLike(label) || !destination || destination === current) return false;
    return new URL(destination).origin === currentOrigin && roots.some(function(root) {
      for (var block = link.parentElement; block && (block === root || root.contains(block)); block = block.parentElement) {
        if (!block.contains(dates[0])) {
          if (block === root) break;
          continue;
        }
        var localLinks = Array.from(block.querySelectorAll("a[href]")).filter(function(candidate) {
          return !elementSubtreeHidden(candidate) && !candidate.closest("h1, h2, h3, h4");
        });
        if (localLinks.length === 1 && localLinks[0] === link) return true;
        if (block === root) break;
      }
      return false;
    });
  });
  return links.length === 1 ? normalizeText(links[0].textContent || "") : null;
}

function readerSourceOwnedHeaderBylineCandidates(header, heading, lead, metadataName, allowUnmarked) {
  var authorSelector = "[rel~='author' i], [itemprop~='author' i], [class*='author-name' i], " +
    "[class*='byline' i], [class*='writer' i], [class*='reporter' i]";
  var candidates = Array.from(header.querySelectorAll("p, address, div, span")).filter(function(node) {
    if (elementSubtreeHidden(node) || sourceOwnershipInChrome(node) || node === heading || node === lead ||
        node.contains(heading) || node.contains(lead) || node.querySelector("h1, h2, h3, h4, a[href], img, video, audio, iframe, figure, table, button, input")) return false;
    if (!(heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        !(node.compareDocumentPosition(lead) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    var text = normalizeText(node.textContent || "");
    if (!text || visiblePublicationDateLike(text)) return false;
    var marked = node.matches(authorSelector);
    var metadataPrefix = metadataName && text.toLowerCase().indexOf(metadataName.toLowerCase()) === 0 &&
      /[\s:·•|,–—-]/u.test(text.charAt(metadataName.length));
    return marked || metadataPrefix || (allowUnmarked && node.matches("p, address"));
  });
  var groupedAuthors = candidates.filter(function(node) {
    return node.matches(authorSelector) && !node.querySelector(authorSelector);
  });
  if (groupedAuthors.length > 1 && sourceOwnedArticleAuthorsShareGroup(groupedAuthors, authorSelector)) {
    return [groupedAuthors.map(function(node) { return normalizeText(node.textContent || ""); }).join(" ")];
  }
  return candidates.filter(function(node) {
    return !candidates.some(function(other) {
      return other !== node && node.contains(other) && normalizeText(node.textContent || "").indexOf(normalizeText(other.textContent || "")) === 0;
    });
  }).map(function(node) { return normalizeText(node.textContent || ""); });
}

function normalizeLocalizedPublicationDigits(value) {
  var text = String(value || "");
  if (!text.trim()) return null;
  return text.replace(/[\u0660-\u0669\u06f0-\u06f9]/g, function(digit) {
    var code = digit.charCodeAt(0);
    return String(code >= 0x06f0 ? code - 0x06f0 : code - 0x0660);
  });
}
