function nativeDisclosureRecordArticles(group) {
  if (!group.open) return [];
  var articles = Array.from(group.querySelectorAll("article")).filter(function(article) {
    return article.closest("details") === group && !elementSubtreeHidden(article);
  });
  if (!articles.length || articles.some(function(article) {
    if (article.parentElement.closest("article") || commentRecordMarker(article) ||
        article.closest(VISIBLE_COMMENT_THREAD_SELECTOR) ||
        article.querySelector("form, input, select, textarea, button")) return true;
    var paragraphs = Array.from(article.querySelectorAll("p")).filter(function(paragraph) {
      return paragraph.closest("article") === article && !elementSubtreeHidden(paragraph) &&
        !!normalizeText(paragraph.textContent || "");
    });
    return paragraphs.length < 2;
  })) return null;
  return articles;
}

function nativeDisclosureBareReferences(root) {
  var elements = [root].concat(Array.from(root.querySelectorAll("*")));
  if (elements.some(function(node) {
    return !node.matches("div, section, aside, a, span, i, b, em, strong, small, s, u, br");
  })) return false;
  var links = root.matches("a") ? [root] : Array.from(root.querySelectorAll("a"));
  if (!links.length || links.some(function(link) {
    return !materializedHttpUrl(link.getAttribute("href")) || !normalizeText(link.textContent || "");
  })) return false;
  var walker = root.ownerDocument.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  var text;
  while ((text = walker.nextNode())) {
    if (normalizeText(text.nodeValue || "") && !text.parentElement.closest("a")) return false;
  }
  return true;
}

function nativeDisclosureTrailingResources(root) {
  var resources = [];
  function visit(node) {
    if (node === root || node.matches("script, style, noscript, template") || disclosureCatalogChrome(node) ||
        elementSubtreeHidden(node)) return;
    if (node.contains(root)) {
      Array.from(node.children).forEach(visit);
      return;
    }
    if (!(root.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING)) return;
    var clone = visibilityPrunedClone(node, document);
    if (!clone) return;
    try {
      if (nativeDisclosureBareReferences(clone)) resources.push(node);
    } finally { clone.replaceChildren(); }
  }
  Array.from(document.body.children).forEach(visit);
  return resources;
}

function nativeDisclosureRecordIndexContext() {
  if (!document.body || !document.querySelector("main details > summary") ||
      document.querySelector("[itemprop~='articleBody'], script[type='application/ld+json'], [itemscope][itemtype]")) return null;
  var types = Array.from(document.querySelectorAll("meta[property='og:type' i]"));
  if (!types.length || types.some(function(node) {
    return normalizeText(node.content || "").toLowerCase() !== "website";
  })) return null;
  var current = datedReferenceDocumentUrl(location.href);
  var canonicals = document.querySelectorAll("link[rel~='canonical' i][href]");
  if (!current || canonicals.length !== 1 ||
      datedReferenceDocumentUrl(canonicals[0].getAttribute("href")) !== current ||
      Array.from(document.querySelectorAll("meta[property='og:url' i]")).some(function(node) {
        return datedReferenceDocumentUrl(node.content) !== current;
      })) return null;

  var chrome = "nav, aside, header, footer, menu, form, [role='navigation'], [role='dialog']";
  var mains = Array.from(document.querySelectorAll("main, [role~='main' i]")).filter(function(node) {
    return !node.closest(chrome) && !elementSubtreeHidden(node);
  });
  var roots = mains.filter(function(node) {
    return !mains.some(function(other) { return other !== node && other.contains(node); });
  });
  if (roots.length !== 1) return null;
  var root = roots[0];
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
    return !node.closest(chrome) && !elementSubtreeHidden(node);
  });
  if (headings.length !== 1 || !root.contains(headings[0]) || headings[0].closest("article, details")) return null;
  var title = normalizedHeadingText(headings[0]);
  var declaredTitles = [document.title].concat(Array.from(document.querySelectorAll("meta[property='og:title' i]")).map(function(node) {
    return node.content;
  }));
  if (!title || declaredTitles.some(function(value) { return !canonicalDataTableTitleAgrees(title, value); }) ||
      nodeHasShadowContent(root)) return null;

  var groups = Array.from(root.querySelectorAll("details")).filter(function(group) {
    return !group.parentElement.closest("details, article") && !group.closest(chrome) && !elementSubtreeHidden(group);
  });
  if (groups.length < 2) return null;
  var records = [];
  for (var index = 0; index < groups.length; index += 1) {
    var group = groups[index];
    var summary = group.firstElementChild;
    if (!summary || summary.tagName !== "SUMMARY" || !normalizeText(summary.textContent || "") ||
        elementSubtreeHidden(summary)) return null;
    var owned = nativeDisclosureRecordArticles(group);
    if (!owned) return null;
    records = records.concat(owned);
  }
  if (records.length < 2) return null;
  var visibleArticles = Array.from(root.querySelectorAll("article")).filter(function(article) {
    return !article.closest("details:not([open])") && !elementSubtreeHidden(article);
  });
  if (visibleArticles.length !== records.length || visibleArticles.some(function(article) {
    return records.indexOf(article) === -1;
  })) return null;
  var trailingResources = nativeDisclosureTrailingResources(root);
  if (disclosureCatalogOutsideMaterial(root, trailingResources)) return null;
  return {root: root, title: title, nativeRecordDisclosures: true, trailingResources: trailingResources};
}

function retainNativeDisclosureState(root) {
  root.querySelectorAll("details:not([open])").forEach(function(details) {
    var summary = details.firstElementChild;
    if (!summary || summary.tagName !== "SUMMARY") return;
    Array.from(details.childNodes).forEach(function(child) {
      if (child !== summary) child.remove();
    });
  });
}
