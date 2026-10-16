  function generatedReferencePreparationEligible() {
    return !location.hash && !!document.querySelector("meta[name='generator'][content*='mkdocs' i]") &&
      !!document.querySelector("link[rel~='canonical' i][href]") &&
      !!document.querySelector("main article.md-content__inner.md-typeset pre") &&
      !!document.querySelector("main article.md-content__inner.md-typeset dl dt a[href] code");
  }

  function generatedReferenceDeclarationsAgree() {
    var declarations = structuredDataNodes();
    if (!declarations.length) return true;
    if (declarations.length !== 1) return false;
    var site = declarations[0];
    var types = [].concat(site["@type"] || []);
    return types.length === 1 && /^(?:https?:\/\/schema\.org\/)?WebSite$/.test(types[0]) &&
      typeof site.name === "string" && !!normalizeText(site.name) && typeof site.url === "string" &&
      sourceOwnershipPageUrl(site.url) === new URL(location.href).origin;
  }

  function generatedReferencePreparationChrome(node) {
    return !!node.closest("header, nav, aside, footer, form, menu, button, [role='banner'], " +
      "[role='navigation'], [role='complementary'], [role='menu'], a.md-skip");
  }

  function generatedReferenceTailFacts(context) {
    var tail = context && context.root.lastElementChild;
    if (!tail || !tail.matches("aside.md-source-file") || elementSubtreeHidden(tail)) return [];
    var facts = Array.from(tail.children);
    if (!facts.length || !facts.every(function(fact) {
      var label = fact.querySelector(".md-icon[title]");
      return fact.matches(".md-source-file__fact") && normalizeText(fact.textContent) &&
        label && normalizeText(label.getAttribute("title")) && !elementSubtreeHidden(fact) &&
        !fact.querySelector("form, button, input, textarea, select, nav, pre, table, dl");
    })) return [];
    return facts.map(function(fact) {
      var clone = safeDeepClone(fact, document);
      clone.removeAttribute("class");
      return clone;
    });
  }

  function generatedReferenceOwnsPhysicalMaterial(root) {
    var nodes = document.querySelectorAll("p, h1, h2, h3, h4, h5, h6, pre, dl, table, figure, video, audio, iframe");
    if (!Array.prototype.every.call(nodes, function(node) {
      return root.contains(node) || generatedReferencePreparationChrome(node) || elementSubtreeHidden(node);
    })) return false;
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    var text;
    while ((text = walker.nextNode())) {
      var parent = text.parentElement;
      if (!parent || root.contains(parent) || generatedReferencePreparationChrome(parent) ||
          parent.closest("script, style, noscript, template") || !normalizeText(text.nodeValue)) continue;
      if (!elementSubtreeHidden(parent)) return false;
    }
    return true;
  }

  function generatedReferencePreparationContext(metadata) {
    if (!generatedReferencePreparationEligible() || !generatedReferenceDeclarationsAgree()) return null;
    var generators = document.querySelectorAll("meta[name='generator'][content]");
    if (!Array.prototype.every.call(generators, function(node) {
      return /\bmkdocs(?:\b|-)/i.test(node.getAttribute("content") || "");
    })) return null;
    var current = sourceOwnershipPageUrl(location.href);
    var canonicals = document.querySelectorAll("link[rel~='canonical' i][href]");
    if (!current || !Array.prototype.every.call(canonicals, function(node) {
      return sourceOwnershipPageUrl(node.getAttribute("href")) === current;
    })) return null;
    if (Array.prototype.some.call(document.querySelectorAll("meta[property='og:url'][content]"), function(node) {
      return sourceOwnershipPageUrl(node.getAttribute("content")) !== current;
    }) || Array.prototype.some.call(document.querySelectorAll("meta[property='og:type'][content]"), function(node) {
      return /article|blog|discussion/i.test(node.getAttribute("content") || "");
    })) return null;
    if (Array.prototype.some.call(document.querySelectorAll("[itemscope][itemtype]"), function(node) {
      return node.getAttribute("itemtype").split(/\s+/).some(function(type) {
        return /(?:Article|BlogPosting|DiscussionForumPosting)\/?$/i.test(type);
      });
    })) return null;
    var mains = document.querySelectorAll("main, [role='main']");
    var articles = document.querySelectorAll("article, [role='article']");
    var selectedRoots = document.querySelectorAll("main .md-content__inner");
    if (mains.length !== 1 || articles.length !== 1 || selectedRoots.length !== 1) return null;
    var root = selectedRoots[0];
    if (root !== articles[0] || !root.matches("article.md-content__inner.md-typeset") ||
        !mains[0].contains(root) || root.matches(".hentry") || root.querySelector("[itemprop~='articleBody']") ||
        elementSubtreeHidden(root)) return null;
    var headings = root.querySelectorAll("h1");
    if (headings.length !== 1 || elementSubtreeHidden(headings[0]) ||
        !/\b(?:reference|manual|documentation|handbook|tutorial|specification|api)\b/i.test(headings[0].textContent)) return null;
    var selectors = ["p", "h2, h3", "pre", "dl > dt a[href] code", "dl > dd"];
    if (!selectors.every(function(selector) {
      return Array.prototype.some.call(root.querySelectorAll(selector), function(node) {
        return normalizeText(node.textContent) && !physicalTechnicalOwnerChrome(node, root) && !elementSubtreeHidden(node);
      });
    }) || !generatedReferenceOwnsPhysicalMaterial(root)) return null;
    var info = docsSystemInfo(metadata);
    return info && info.system === "mkdocs" ? { root: root, framework: "mkdocs", info: info } : null;
  }
