function removeNodesByText(root, selector, pattern) {
  root.querySelectorAll(selector).forEach(function(el) {
    var text = normalizeText(el.textContent);
    if (text && pattern.test(text) && !codeContentNode(el)) el.remove();
  });
}

function samePageFragmentLink(href) {
  if (!href) return false;

  var current = location.href.split("#")[0] + "#";
  return href === "#" || href.indexOf("#") === 0 || href.indexOf(current) === 0;
}

function authoredReciprocalReferenceLink(link, targets, sourceIds) {
  var id = link.getAttribute("id");
  var href = link.getAttribute("href");
  if (!id || sourceIds.get(id) !== 1 || targets.get(id) !== link || !samePageFragmentLink(href) ||
      link.closest("nav, aside, pre, code, h1, h2, h3, h4, h5, h6")) return false;
  var targetId;
  try { targetId = decodeURIComponent(href.slice(href.indexOf("#") + 1)); } catch (_error) { return false; }
  if (!targetId || sourceIds.get(targetId) !== 1 || targetId === id) return false;
  var target = targets.get(targetId);
  if (!target || target.tagName !== "A" || target.closest("nav, aside, pre, code, h1, h2, h3, h4, h5, h6")) return false;
  var reverse = target.getAttribute("href");
  if (!samePageFragmentLink(reverse)) return false;
  var reverseId;
  try { reverseId = decodeURIComponent(reverse.slice(reverse.indexOf("#") + 1)); } catch (_error) { return false; }
  if (reverseId !== id) return false;
  var noteSelector = "[role='doc-footnote'], [role='doc-endnote'], " +
    "div[class*='footnote' i], section[class*='footnote' i], li[class*='footnote' i], " +
    "div[class*='endnote' i], section[class*='endnote' i], li[class*='endnote' i]";
  var note = link.closest(noteSelector) || target.closest(noteSelector);
  if (!note || !normalizeText(note.textContent.replace(link.textContent, "").replace(target.textContent, ""))) return false;
  var reference = note.contains(link) ? target : link;
  var prose = reference.closest("p, li, dd, td, th, blockquote");
  return !!(prose && !note.contains(prose) && normalizeText(prose.textContent.replace(reference.textContent, "")));
}

function tocLikeNode(node) {
  if (node.querySelector("p, pre, code, table, dl")) return false;
  var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
  if (links.length < 4 || links.length > 30) return false;

  var fragmentLinks = links.filter(function(link) {
    return samePageFragmentLink(link.getAttribute("href"));
  }).length;
  var text = normalizeText(node.textContent);

  return fragmentLinks >= 4 && fragmentLinks >= Math.ceil(links.length * 0.8) && text.length < 900;
}

function breadcrumbLikeNode(node) {
  if (node.closest && node.closest(".landing-card, .card--fullwidth")) return false;

  var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
  if (links.length < 2 || links.length > 8) return false;

  var text = normalizeText(node.textContent);
  if (!text || text.length > 220) return false;

  // Short labels alone do not make an authored resource list navigation.
  if (node.querySelector("p, strong, b, h1, h2, h3, h4, h5, h6, ul, ol, pre, code, table, button, input, select, textarea")) return false;
  var walker = node.ownerDocument.createTreeWalker(node, NodeFilter.SHOW_TEXT);
  var separator = false;
  while (walker.nextNode()) {
    var source = walker.currentNode;
    if (source.parentElement.closest("a[href]")) continue;
    var value = normalizeText(source.nodeValue);
    if (!value) continue;
    if (!/^[\s/>\u203a\u00bb\u2192]+$/.test(value)) return false;
    separator = true;
  }
  if (!separator) return false;

  var current = new URL(location.href);
  var currentPath = current.pathname.replace(/\/+$/, "") || "/";
  var previousPath = null;
  return links.every(function(link, index) {
    var label = normalizeText(link.textContent);
    var href = materializedHttpUrl(link.getAttribute("href"));
    if (!label || label.length >= 40 || !href) return false;
    var target = new URL(href);
    var path = target.pathname.replace(/\/+$/, "") || "/";
    if (target.origin !== current.origin || target.search || target.hash) return false;
    if (index === 0 && path !== "/") return false;
    if (index > 0 && (path === previousPath || (previousPath !== "/" && path.indexOf(previousPath + "/") !== 0))) return false;
    if (path !== "/" && path !== currentPath && currentPath.indexOf(path + "/") !== 0) return false;
    previousPath = path;
    return true;
  });
}

function cleanDocsHeadingText(text) {
  return normalizeText((text || "")
    .replace(/[\u200B\u200C\u200D\uFEFF]/g, "")
    // Strip LLM action button text concatenated to titles (Redocly, Fern, GitBook, etc.)
    // These appear as a trailing cluster: "...titleCopyCopy for LLMOpen in ChatGPT..."
    .replace(/\s*(?:Copy\s*(?:for\s+LLMs?|page(?:\s+as\s+Markdown)?(?:\s+for\s+LLMs?)?)|View\s+as\s+Markdown|Open\s+(?:this\s+page\s+as\s+Markdown|in\s+(?:ChatGPT|Claude|Cursor))|Get\s+insights\s+from\s+(?:ChatGPT|Claude)|Connect\s+to\s+Cursor|Ask\s+AI|Download\s+OpenAPI\s+spec(?:ification)?)\s*/gi, "")
  ).replace(/\s+copy item path$/i, "").replace(/[¶#\uF0C1\uF0C6\uF08E\uF14C]+$/, "").replace(/\s*Copy$/i, "");
}

function docsHomepagePath() {
  var path = (location.pathname || "").replace(/\/+(?:index\.html?)?$/i, "");
  return path === "" || path === "/";
}

function stripDocsTextNodePattern(root, pattern) {
  var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  var nodes = [];

  while (walker.nextNode()) nodes.push(walker.currentNode);
  nodes.forEach(function(node) {
    if (node.parentElement.closest("pre, code, kbd, samp") && codeContentNode(node.parentElement)) return;
    var updated = node.nodeValue.replace(pattern, " ");
    if (updated !== node.nodeValue) node.nodeValue = updated;
  });
}

function docsHomepageListLike(root, info) {
  if (!docsHomepagePath() || !info) return false;
  if (!/^(docusaurus|nextra|next|sphinx|readthedocs)$/i.test(info.system || "")) return false;

  var pageText = normalizeText((document.body && document.body.textContent) || "");
  var rootText = normalizeText((root && root.textContent) || "");
  var landingCards = document.querySelectorAll(".card, [class*='card' i], [class*='feature' i], [class*='tile' i], [class*='landing' i]").length;
  var docsShellLinks = document.querySelectorAll("header a[href], nav a[href], aside a[href], [class*='sidebar' i] a[href], [class*='navbar' i] a[href]").length;

  if (landingCards >= 3) return true;
  if (/\b(?:get started|getting started|quick start|api|reference|guides?|tutorials?)\s*\|\s*/i.test(rootText)) return true;
  return docsShellLinks >= 8 && pageText.length >= 1000 && rootText.length >= 300;
}

function cleanupDocsRoot(root, options) {
  options = options || {};

  removeNodesByText(root, "a, button, span, div, p, li", /^(copy page|copy for llm|copy page as markdown|copy page as markdown for llms?|view as markdown|open this page as markdown|open in (?:chatgpt|claude|cursor)|get insights from (?:chatgpt|claude)|connect to cursor|download openapi spec(?:ification)?|ask about this section|ask ai|copy link|copy permalink|send feedback|edit this page|report feedback|pdf|rss|focus mode|skip to main content|skip to content|copy item path|view source|view on github|report a problem with this content|open menu|open sidebar|search|settings|help|search or ask copilot|expand description|show more|show less|expand|collapse|javascripttypescript|typescriptjavascript)$/i);
  removeNodesByText(root, "h2, h3, h4, h5, p, div, span, li", /^(on this page|in this article|table of contents|last updated.*|api preferences|select language:.*|breadcrumbs?)$/i);

  // Strip "Feedback" sections and "Last modified" / "Was this page helpful?" footers (common in Hugo docs)
  root.querySelectorAll("section, div").forEach(function(el) {
    var text = normalizeText(el.textContent);
    if (!text) return;
    if (/^feedback\b/i.test(text) && text.length < 500 && el.querySelectorAll("a, button").length >= 1) {
      el.remove();
      return;
    }
    if (/^(was this page helpful|is this page helpful)\??$/i.test(text.split("\n")[0]) && text.length < 300) {
      el.remove();
      return;
    }
  });
  removeNodesByText(root, "p, div, span", /^last modified\s/i);

  // Strip newsletter / subscribe footer sections (common in docs sites like Bring, etc.)
  root.querySelectorAll("section, div, aside, form").forEach(function(el) {
    var text = normalizeText(el.textContent);
    if (!text) return;
    var heading = el.querySelector("h2, h3, h4");
    if (heading && /^(subscribe|newsletter|stay up[- ]to[- ]date|get (?:the )?latest|sign up for (?:our )?(?:newsletter|updates)|mailing list)$/i.test(normalizeText(heading.textContent)) && text.length < 800) {
      el.remove();
      return;
    }
  });
  removeNodesByText(root, "p, div, span, a", /^(privacy\s*policy|terms\s+(?:of\s+(?:service|use)|and\s+conditions)|powered by [a-z]+)$/i);

  root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
    var text = cleanDocsHeadingText(el.textContent);
    setDocsHeadingText(el, text);
  });

  root.querySelectorAll("nav, [aria-label*='breadcrumb' i], ol[aria-label*='breadcrumb' i]").forEach(function(el) {
    el.remove();
  });

  var referenceTargets = new Map();
  var sourceReferenceIds = new Map();
  document.querySelectorAll("[id]").forEach(function(el) {
    var id = el.getAttribute("id");
    sourceReferenceIds.set(id, (sourceReferenceIds.get(id) || 0) + 1);
  });
  root.querySelectorAll("[id]").forEach(function(el) {
    var id = el.getAttribute("id");
    referenceTargets.set(id, referenceTargets.has(id) ? null : el);
  });
  root.querySelectorAll("a[href]").forEach(function(el) {
    var text = normalizeText(el.textContent);
    if (!text && el.closest("pre, code") && (el.getAttribute("id") || el.getAttribute("name"))) return;
    var title = normalizeText(el.getAttribute("title"));
    // Method signatures can be headings wrapped by their own fragment link.
    // Removing that link would remove the heading, not just its permalink.
    var wrappedHeading = el.querySelector("h1, h2, h3, h4, h5, h6");
    if (wrappedHeading && normalizeText(wrappedHeading.textContent)) return;
    if (el.closest("dt, h1, h2, h3, h4, h5, h6") && text &&
        !/^(?:¶|↑|#|\uF0C1|\uF0C6|\uF08E|\uF14C)$/.test(text)) return;
    var prose = el.closest("p, li, dd, td, th");
    if (prose && !/^(?:¶|↑|#)$/.test(text) &&
        normalizeText(prose.textContent.replace(el.textContent, ""))) return;
    if (authoredReciprocalReferenceLink(el, referenceTargets, sourceReferenceIds)) return;
    if (samePageFragmentLink(el.getAttribute("href")) && (!text || text.length < 40 || /link for this heading/i.test(title) || /^skip to (?:main )?content$/i.test(text))) el.remove();
  });

  root.querySelectorAll("section, div, ul, ol").forEach(function(el) {
    var text = normalizeText(el.textContent);
    if (!text) return;
    if (/^on this page\b/i.test(text) && text.length < 1200) {
      el.remove();
      return;
    }
    if (tocLikeNode(el) || breadcrumbLikeNode(el)) el.remove();
  });

  if (options.removeTryIt) {
    root.querySelectorAll("section, div").forEach(function(el) {
      var text = normalizeText(el.textContent);
      var heading = el.querySelector("h2, h3, h4");
      if ((heading && /^try it$/i.test(normalizeText(heading.textContent))) || (/^try it\b/i.test(text) && text.length < 600)) el.remove();
    });
    removeNodesByText(root, "h2, h3, h4", /^try it$/i);
  }

  if (options.removeCookiePrefs) {
    removeNodesByText(root, "h1, h2, h3, p, div, span", /^(select your cookie preferences|customize cookie preferences|unable to save cookie preferences)$/i);
  }

  if (options.removeMarketingTips) {
    root.querySelectorAll("section, div, aside").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (/\b(tip|note)\b/i.test(text) && /(workshop|builder center|sign up|training|studio)/i.test(text) && text.length < 600) {
        el.remove();
      }
    });
  }

  return root;
}

function firstRootText(root, selectors) {
  for (var i = 0; i < selectors.length; i += 1) {
    var nodes = root.querySelectorAll(selectors[i]);
    for (var j = 0; j < nodes.length; j += 1) {
      var text = normalizeText(nodes[j].textContent);
      if (text) return text;
    }
  }

  return null;
}

function docsScopedDescendants(root, selector, boundarySelector) {
  return Array.prototype.slice.call(root.querySelectorAll(selector)).filter(function(node) {
    var current = node.parentElement;

    while (current && current !== root) {
      if (current.matches && current.matches(boundarySelector)) return false;
      current = current.parentElement;
    }

    return true;
  });
}

function docsScopedFirstText(root, selectors, boundarySelector) {
  for (var i = 0; i < selectors.length; i += 1) {
    var nodes = docsScopedDescendants(root, selectors[i], boundarySelector);
    for (var j = 0; j < nodes.length; j += 1) {
      var text = normalizeText(nodes[j].textContent);
      if (text) return text;
    }
  }

  return "";
}
