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

function sourceOwnedPrimaryFeatureSection(section) {
  if (!section || elementSubtreeHidden(section) || sourceOwnershipInChrome(section)) return null;
  var clone = visibilityPrunedClone(section, document);
  if (!clone) return null;
  Array.prototype.forEach.call(clone.querySelectorAll("style, script, noscript"), function(node) {
    node.remove();
  });
  if (clone.querySelector("form, input, select, textarea, button, nav, aside, article, video, audio, iframe, table, blockquote, ul, ol")) return null;

  var headings = Array.prototype.slice.call(clone.querySelectorAll("h3"));
  var paragraphs = Array.prototype.slice.call(clone.querySelectorAll("p"));
  if (headings.length < 3 || paragraphs.length !== headings.length) return null;

  var cards = headings.map(function(heading) {
    for (var owner = heading.parentElement; owner && owner !== clone; owner = owner.parentElement) {
      var ownerHeadings = owner.querySelectorAll("h3");
      var ownerParagraphs = owner.querySelectorAll("p");
      if (ownerHeadings.length === 1 && ownerParagraphs.length === 1 &&
          normalizeText(ownerParagraphs[0].textContent || "").length >= 40) return owner;
    }
    return null;
  });
  if (cards.some(function(card) { return !card; }) || new Set(cards).size !== cards.length) return null;
  if (paragraphs.some(function(paragraph) {
    return !cards.some(function(card) { return card.contains(paragraph); });
  })) return null;
  if (Array.prototype.some.call(clone.querySelectorAll("a[href], img, picture, source, svg, canvas"), function(node) {
    return !cards.some(function(card) { return card.contains(node); });
  })) return null;

  var sectionText = normalizeText(clone.textContent || "");
  var cardText = normalizeText(cards.map(function(card) { return card.textContent || ""; }).join(" "));
  return sectionText && sectionText === cardText ? { clone: clone, text: sectionText } : null;
}

function sourceOwnedPrimaryInterveningSections(primary, calculator) {
  var parent = primary.parentElement;
  if (!parent || calculator.parentElement !== parent) return null;
  var siblings = Array.prototype.slice.call(parent.children);
  var primaryIndex = siblings.indexOf(primary);
  var calculatorIndex = siblings.indexOf(calculator);
  if (primaryIndex < 0 || calculatorIndex <= primaryIndex) return null;

  var sections = [];
  for (var index = primaryIndex + 1; index < calculatorIndex; index += 1) {
    var sibling = siblings[index];
    if (elementSubtreeHidden(sibling) || sourceOwnershipInChrome(sibling)) continue;
    var material = visibilityPrunedClone(sibling, document);
    if (!material) continue;
    Array.prototype.forEach.call(material.querySelectorAll("style, script, noscript"), function(node) {
      node.remove();
    });
    if (!normalizeText(material.textContent || "") &&
        !material.querySelector("h1, h2, h3, h4, h5, h6, a[href], img, picture, video, audio, iframe, table, blockquote, ul, ol, form, input, select, textarea, button")) continue;

    var section = sourceOwnedPrimaryFeatureSection(sibling);
    if (!section) return null;
    sections.push(section.clone);
  }
  return sections;
}

function sourceOwnedPrimarySectionOutput(clone) {
  clone.setAttribute("data-fetchutil-page-overview", "true");
  var output = {
    html: clone.outerHTML,
    markdown: markdownFor(clone.outerHTML),
    text: normalizeText(clone.textContent || "")
  };
  clone.removeAttribute("data-fetchutil-page-overview");
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
  var primaryClone = primaryOwner.clone;
  var primaryText = primaryOwner.text;
  var sourceUrls = primaryOwner.urls;

  var title = normalizeText(content.title || "");
  if (!title) return content;
  var displacedHeadings = Array.prototype.filter.call(document.querySelectorAll("h1"), function(heading) {
    return !primary.contains(heading) && !elementVisuallyHidden(heading) &&
      normalizeText(heading.textContent || "") === title;
  });
  if (displacedHeadings.length !== 1 || !(primary.compareDocumentPosition(displacedHeadings[0]) & 4)) return content;

  var interactiveOwner = displacedHeadings[0].parentElement;
  while (interactiveOwner && interactiveOwner !== document.body &&
      (primary.contains(interactiveOwner) || interactiveOwner.contains(primary) || elementSubtreeHidden(interactiveOwner) ||
       !Array.prototype.some.call(interactiveOwner.querySelectorAll("input, select, textarea, button"), function(control) {
         return !elementSubtreeHidden(control);
       }))) {
    interactiveOwner = interactiveOwner.parentElement;
  }
  if (!interactiveOwner || interactiveOwner === document.body) return content;
  var interactiveHeadings = Array.prototype.filter.call(interactiveOwner.querySelectorAll("h1"), function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (interactiveHeadings.length !== 1 || normalizeText(interactiveHeadings[0].textContent || "") !== title) return content;

  var pageOwner = primary.parentElement;
  var calculator = displacedHeadings[0];
  while (calculator && calculator.parentElement !== pageOwner) calculator = calculator.parentElement;
  if (!calculator || calculator === primary || !calculator.contains(interactiveOwner) ||
      elementSubtreeHidden(calculator)) return content;
  var calculatorHeadings = Array.prototype.filter.call(calculator.querySelectorAll("h1"), function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (calculatorHeadings.length !== 1 || normalizeText(calculatorHeadings[0].textContent || "") !== title) return content;
  var interveningSections = sourceOwnedPrimaryInterveningSections(primary, calculator);
  if (!interveningSections) return content;

  var candidateText = normalizeText(content.textContent || content.markdown || "");
  var leadNodes = Array.prototype.filter.call(primaryClone.querySelectorAll("p, li, blockquote, div"), function(node) {
    if (node.querySelector("h1, h2, h3, h4, h5, h6, a, form, input, select, textarea, button, img, video, audio, iframe")) return false;
    return normalizeText(node.textContent || "").length >= 160;
  });
  var missingLead = leadNodes.find(function(node) {
    return !candidateText.includes(normalizeText(node.textContent || ""));
  });
  var candidateContainer = document.createElement("div");
  candidateContainer.innerHTML = content.html || "";
  var candidateUrls = new Set(Array.prototype.map.call(candidateContainer.querySelectorAll("a[href]"), function(link) {
    return materializedHttpUrl(link.getAttribute("href"));
  }).filter(Boolean));
  var missingPrimaryLink = Array.from(sourceUrls).some(function(url) { return !candidateUrls.has(url); });
  if (!missingLead || !missingPrimaryLink) return content;

  var pageTitle = normalizeText((metadata && metadata.title) || document.title || "");
  var sourceSections = [primaryClone].concat(interveningSections, [visibilityPrunedClone(calculator, document)]);
  if (sourceSections.some(function(section) { return !section; })) return content;
  var sourceOutputs = sourceSections.map(sourceOwnedPrimarySectionOutput);
  var existingMarkdown = content.markdown || markdownFor(content.html || "");
  return Object.assign({}, content, {
    title: pageTitle || content.title,
    excerpt: content.excerpt || normalizeText(missingLead.textContent || ""),
    html: sourceOutputs.map(function(output) { return output.html; }).join("") + (content.html || ""),
    markdown: sourceOutputs.map(function(output) { return output.markdown; }).concat(existingMarkdown).filter(Boolean).join("\n\n"),
    textContent: normalizeText(sourceOutputs.map(function(output) { return output.text; }).concat(content.textContent || "").join(" ")),
    sourceOwnedPrimaryPage: true
  });
}
