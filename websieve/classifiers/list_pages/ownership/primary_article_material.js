function sourceOwnedPrimaryOwner(root, heading, pageTitleTerms) {
  for (var owner = heading.parentElement; owner && root.contains(owner); owner = owner.parentElement) {
    var headings = Array.prototype.filter.call(owner.querySelectorAll("h1"), function(candidate) {
      return !elementVisuallyHidden(candidate);
    });
    if (headings.length !== 1 || headings[0] !== heading) continue;
    var clone = visibilityPrunedClone(owner, document);
    var text = normalizeText(clone.textContent || "");
    var lead = text.toLowerCase().slice(0, 900);
    if (text.length < 450 || pageTitleTerms.some(function(term) { return lead.indexOf(term) === -1; })) continue;
    var links = Array.prototype.filter.call(clone.querySelectorAll("a[href]"), function(link) {
      return normalizeText(link.textContent || link.getAttribute("aria-label") || "").length >= 3 &&
        materializedHttpUrl(link.getAttribute("href"));
    });
    var urls = new Set(links.map(function(link) { return materializedHttpUrl(link.getAttribute("href")); }));
    if (urls.size >= 2) return { node: owner, clone: clone, text: text, urls: urls };
  }
  return null;
}

function sourceOwnedPrimaryHasUnownedSibling(root, heading) {
  var branch = heading;
  while (branch && branch.parentElement && branch.parentElement !== root) {
    var parent = branch.parentElement;
    var siblings = Array.prototype.filter.call(parent.children, function(node) { return node !== branch; });
    if (siblings.some(function(node) {
      if (elementSubtreeHidden(node) || sourceOwnershipInChrome(node)) return false;
      var clone = visibilityPrunedClone(node, document);
      return normalizeText(clone.textContent || "").length >= 80 ||
        !!clone.querySelector("h1, h2, h3, h4, h5, h6, a[href], img, picture, video, audio, iframe, table, blockquote, ul, ol");
    })) return true;
    branch = parent;
  }
  return false;
}

function sourceOwnedPrimaryCalculatorSibling(primary, sibling) {
  if (!sibling || sibling === primary || elementSubtreeHidden(sibling) ||
      sourceOwnershipArticleChrome(sibling, primary.parentElement)) return false;
  var headings = Array.prototype.filter.call(sibling.querySelectorAll("h1"), function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (headings.length !== 1) return false;
  var fields = Array.prototype.filter.call(sibling.querySelectorAll("input, select, textarea"), function(field) {
    return !elementSubtreeHidden(field) && field.type !== "hidden";
  });
  var actions = Array.prototype.filter.call(sibling.querySelectorAll("button, [role~='button' i], input[type='submit'], input[type='button']"), function(action) {
    return !elementSubtreeHidden(action) && action.type !== "hidden";
  });
  var formOrDistinctControls = !!sibling.querySelector("form") ||
    (fields.some(function(field) { return field.matches("input"); }) &&
     fields.filter(function(field) { return field.matches("select"); }).length >= 2);
  return formOrDistinctControls && fields.length > 0 && actions.length > 0 &&
    (headings[0].compareDocumentPosition(fields[0]) & Node.DOCUMENT_POSITION_FOLLOWING) &&
    (fields[0].compareDocumentPosition(actions[0]) & Node.DOCUMENT_POSITION_FOLLOWING);
}

function sourceOwnedPrimaryContextSibling(sibling, calculator, pageTitleTerms) {
  var clone = visibilityPrunedClone(sibling, document);
  if (!clone || !normalizeText(clone.textContent || "")) return false;
  if (clone.querySelector("article, [role~='article' i], form, input, select, textarea, button, h1")) return false;
  var headings = Array.prototype.filter.call(clone.querySelectorAll("h2, h3, h4"), function(node) {
    return normalizeText(node.textContent || "");
  });
  var paragraphs = Array.prototype.filter.call(clone.querySelectorAll("p"), function(node) {
    return normalizeText(node.textContent || "");
  });
  var triggers = Array.prototype.filter.call(sibling.querySelectorAll("a"), sourceOwnedPrimaryCollapsedTrigger);
  var hasFeature = headings.length >= 2 && (paragraphs.length >= 2 ||
    headings.filter(function(node) { return normalizeText(node.textContent || "").length >= 80; }).length >= 2);
  var hasQuestions = headings.length && triggers.length >= 2 && paragraphs.length;
  // A bare editorial section, a second article, and unrelated controls are not
  // part of this component merely because they share the calculator's parent.
  if (!hasFeature && !hasQuestions) return false;
  if (sibling.compareDocumentPosition(calculator) & Node.DOCUMENT_POSITION_FOLLOWING) return hasFeature;
  if (!pageTitleTerms.some(function(term) {
    return normalizeText(clone.textContent || "").toLowerCase().indexOf(term) !== -1;
  })) return false;
  return hasFeature || hasQuestions;
}

function sourceOwnedPrimaryMediaSibling(sibling, ownedSiblings, pageTitleTerms) {
  var clone = visibilityPrunedClone(sibling, document);
  if (!clone || normalizeText(clone.textContent || "") ||
      clone.querySelector("article, form, input, button, a[href], video, audio, iframe, object, embed")) return false;
  var images = Array.prototype.slice.call(clone.querySelectorAll("img[src]"));
  if (images.length !== 1) return false;
  var url = materializedHttpUrl(images[0].getAttribute("src"));
  if (!url || !pageTitleTerms.some(function(term) { return url.toLowerCase().indexOf(term) !== -1; })) return false;
  var host = new URL(url).hostname;
  return ownedSiblings.some(function(owned) {
    return Array.prototype.some.call(owned.querySelectorAll("img[src]"), function(image) {
      var ownedUrl = materializedHttpUrl(image.getAttribute("src"));
      return ownedUrl && new URL(ownedUrl).hostname === host;
    });
  });
}

function sourceOwnedPrimaryServiceOwner(primary, pageTitleTerms) {
  var owner = primary && primary.parentElement;
  if (!owner || owner === document.body || owner === document.documentElement ||
      owner.matches("html, body, main, [role~='main' i]") || sourceOwnershipInChrome(owner)) return null;
  var children = Array.prototype.slice.call(owner.children);
  var primaryIndex = children.indexOf(primary);
  if (primaryIndex < 0 || children.filter(function(child) { return child === primary; }).length !== 1) return null;
  var calculators = children.filter(function(child, index) {
    return index > primaryIndex && sourceOwnedPrimaryCalculatorSibling(primary, child);
  });
  if (calculators.length !== 1) return null;
  var calculator = calculators[0];
  var contextualSiblings = children.filter(function(child) {
    return child !== primary && child !== calculator && !child.matches("style, script, noscript, template") &&
      !elementSubtreeHidden(child) &&
      !sourceOwnershipArticleChrome(child, owner) &&
      !!normalizeText((visibilityPrunedClone(child, document) || {}).textContent || "");
  });
  if (!contextualSiblings.length || !contextualSiblings.every(function(child) {
    return sourceOwnedPrimaryContextSibling(child, calculator, pageTitleTerms);
  })) return null;
  var ownedSiblings = [primary, calculator].concat(contextualSiblings);
  var otherSiblings = children.filter(function(child) {
    return ownedSiblings.indexOf(child) < 0 && !child.matches("style, script, noscript, template") &&
      !elementSubtreeHidden(child) && !sourceOwnershipArticleChrome(child, owner);
  });
  if (!otherSiblings.every(function(child) {
    return sourceOwnedPrimaryMediaSibling(child, ownedSiblings, pageTitleTerms);
  })) return null;
  return { node: owner, calculator: calculator };
}

function sourceOwnedPrimaryCollapsedTrigger(node) {
  if (!node || node.tagName !== "A" || elementSubtreeHidden(node)) return false;
  var href = (node.getAttribute("href") || "").trim();
  var expanded = node.getAttribute("aria-expanded");
  if (expanded === "true") return false;
  var identity = node.getAttribute("class") || "";
  if (/(?:expander|accordion|collapse|disclosure)/i.test(identity) &&
      (!href || href.charAt(0) === "#" || /^javascript\s*:/i.test(href))) return true;
  if (href.charAt(0) !== "#") return false;
  return expanded === "false" || node.getAttribute("role") === "button" || !!node.getAttribute("aria-controls");
}

function sourceOwnedPrimaryServiceClone(serviceOwner) {
  var sourceClones = new WeakMap();
  var clone = visibilityPrunedClone(serviceOwner.node, document, sourceClones);
  if (!clone) return null;
  Array.prototype.forEach.call(serviceOwner.node.querySelectorAll("a"), function(node) {
    if (!sourceOwnedPrimaryCollapsedTrigger(node)) return;
    var link = sourceClones.get(node);
    if (!link || !clone.contains(link) || !link.parentNode) return;
    var sourceParent = node.parentElement;
    if (sourceParent && /^H[1-6]$/.test(sourceParent.tagName || "")) {
      while (link.firstChild) link.parentNode.insertBefore(link.firstChild, link);
      link.remove();
      return;
    }
    if (sourceParent && /^(?:DIV|SECTION)$/.test(sourceParent.tagName || "")) {
      var label = document.createElement("p");
      while (link.firstChild) label.appendChild(link.firstChild);
      link.parentNode.replaceChild(label, link);
      return;
    }
    while (link.firstChild) link.parentNode.insertBefore(link.firstChild, link);
    link.remove();
  });
  Array.prototype.forEach.call(serviceOwner.node.querySelectorAll("style, script, noscript, template"), function(node) {
    var childClone = sourceClones.get(node);
    if (childClone) childClone.remove();
  });
  Array.prototype.forEach.call(serviceOwner.node.children, function(child) {
    if (!sourceOwnershipArticleChrome(child, serviceOwner.node)) return;
    var childClone = sourceClones.get(child);
    if (childClone) childClone.remove();
  });
  return clone;
}

function sourceOwnedPrimarySectionOutput(clone) {
  var primary = clone.querySelector("[id='primary' i]");
  if (primary) primary.setAttribute("data-fetchutil-source-owned-primary", "");
  var unlabelledMedia = Array.prototype.filter.call(clone.children, function(child) {
    return !normalizeText(child.textContent || "") && !child.querySelector("a[href], input, select, button") &&
      child.querySelectorAll("img[src]").length === 1 &&
      !normalizeText(child.querySelector("img[src]").getAttribute("alt") || "");
  }).map(function(child) { return child.querySelector("img[src]"); });
  unlabelledMedia.forEach(function(image) { image.setAttribute("alt", "Image"); });
  var markdown = markdownFor(clone.outerHTML);
  unlabelledMedia.forEach(function(image) { image.removeAttribute("alt"); });
  if (primary) primary.removeAttribute("data-fetchutil-source-owned-primary");
  var output = {
    html: clone.outerHTML,
    markdown: markdown,
    text: normalizeText(clone.textContent || "")
  };
  return output;
}

function sourceOwnedPrimaryArticleMaterial(content, metadata) {
  if (!content || content.contentType !== "article" || !content.readerMode) return content;
  var selectors = "main, [role~='main' i], [id='primary' i]";
  var roots = Array.prototype.filter.call(document.querySelectorAll(selectors), function(root) {
    return !elementSubtreeHidden(root) && !sourceOwnershipInChrome(root) &&
      !root.closest("header, nav, aside, footer, [role~='navigation' i], [role~='complementary' i]");
  });
  roots = roots.filter(function(root) {
    return !roots.some(function(other) { return other !== root && root.contains(other); });
  });
  if (roots.length !== 1) return content;

  var primary = roots[0];
  if (primary.matches("header, nav, aside, footer") ||
      primary.querySelector("article, [role~='article' i], form, input, select, textarea, button, nav, aside, footer")) return content;
  var headings = Array.prototype.filter.call(primary.querySelectorAll("h1"), function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (headings.length !== 1) return content;

  var pageTitle = normalizeText((metadata && metadata.title) || "");
  if (!pageTitle || pageTitle !== normalizeText(document.title)) return content;
  var siteName = normalizeText((metadata && metadata.siteName) || "");
  if (!siteName) {
    try { siteName = new URL(location.href).hostname; } catch (_error) { siteName = ""; }
  }
  var siteTerms = new Set(siteName.toLowerCase().match(/[\p{L}\p{N}]+/gu) || []);
  var pageTitleTerms = (pageTitle.toLowerCase().match(/[\p{L}\p{N}]+/gu) || []).filter(function(term) {
    return term.length >= 4 && !siteTerms.has(term) && !/^(?:home|news|page|site|the|www)$/.test(term);
  });
  if (!pageTitleTerms.length) return content;
  var primaryOwner = sourceOwnedPrimaryOwner(primary, headings[0], pageTitleTerms);
  if (!primaryOwner || (primaryOwner.node === primary && sourceOwnedPrimaryHasUnownedSibling(primary, headings[0]))) return content;
  var serviceOwner = sourceOwnedPrimaryServiceOwner(primary, pageTitleTerms);
  if (!serviceOwner || !sourceOwnedPrimaryCandidateCovered(content, serviceOwner.node)) return content;
  var serviceClone = sourceOwnedPrimaryServiceClone(serviceOwner);
  if (!serviceClone) return content;
  var title = pageTitle;
  var excerpt = sourceOwnedCompleteArticleLead({
    ownerRoot: serviceOwner.node,
    body: { sourceNode: serviceOwner.node },
    title: title
  });
  if (!excerpt) return content;
  var sourceOutput = sourceOwnedPrimarySectionOutput(serviceClone);
  return Object.assign({}, content, {
    title: title,
    excerpt: excerpt,
    html: sourceOutput.html,
    markdown: sourceOutput.markdown,
    textContent: sourceOutput.text,
    sourceOwnedPrimaryPage: true
  });
}
