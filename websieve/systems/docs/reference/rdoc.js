function rdocSystemPresent(generator, signature) {
  if (document.querySelector("body.mediawiki, #mw-content-text, .mw-parser-output, meta[name='generator'][content^='MediaWiki']")) return false;
  if (/rdoc/i.test(generator || "") || /rdoc documentation/i.test(signature || "")) return true;
  var metadata = document.querySelector("#class-metadata");
  if (metadata && !elementSubtreeHidden(metadata)) return true;
  var body = document.querySelector("#bodyContent");
  if (!body || elementSubtreeHidden(body)) return false;
  if (sdocReferenceIdentity(body)) return true;
  return Array.prototype.some.call(body.querySelectorAll("h1, h2"), function(heading) {
    return !elementSubtreeHidden(heading) && /^(?:class|module)\s+[A-Z][\w:]*(?:\s*<\s*[A-Z][\w:]*)?(?:\s*[¶↑])*$/i.test(normalizeText(heading.textContent));
  });
}

function sdocReferenceIdentity(body) {
  var tree = document.querySelector("meta[name='data-tree-keys']");
  if (!body || !tree || !document.querySelector("meta[name='data-rel-prefix']") ||
      document.querySelectorAll("#bodyContent").length !== 1 || !body.querySelector("#content .description")) return false;
  var keys;
  try { keys = JSON.parse(tree.getAttribute("content") || ""); } catch (_error) { return false; }
  if (!Array.isArray(keys) || !keys.length || !keys.every(function(key) { return typeof key === "string" && /^[A-Z]\w*$/.test(key); })) return false;
  var identity = keys.join("::");
  var declared = document.querySelector("meta[property='og:title']");
  return normalizeText(document.title) === identity || (declared &&
    normalizeText(declared.getAttribute("content") || declared.getAttribute("value")) === identity) ? identity : null;
}

function rdocDocsContent(metadata, info) {
  var referenceName = !location.hash && sdocReferenceIdentity(document.querySelector("#bodyContent"));
  return docsEngineContent(metadata, info, {
    system: "rdoc",
    rootSelectors: ["#bodyContent", "#content", "#main", "main"],
    titleSelectors: referenceName ? [] : ["#bodyContent h1", "#content h1", "#main h1", "main h1"],
    preferFragmentTitle: referenceName ? false : undefined,
    fallbackTitle: function() { return referenceName || metadata.title || document.title; },
    titleFormatter: function(title) {
      return title.replace(/\s*(?:-|\u2013|\u2014)\s*RDoc Documentation$/i, "").replace(/^(class|module)\s+/i, "");
    },
    removeSelectors: "form, nav, header, #class-metadata, .filetree, .search-section, .quicksearch, aside",
    rewriteRoot: function(root) {
      removeNodesByText(root, "a, span, div, p", /^(skip to content|skip to search|search|menu|index)$/i);
      removeNodesByText(root, "h2, h3", /^(home|what(?:’|')?s here)$/i);
      root.querySelectorAll("ul, ol, div, section").forEach(function(node) {
        if (tocLikeNode(node)) node.remove();
      });
      root.querySelectorAll("a").forEach(function(node) {
        if (/^(¶|↑)$/.test(normalizeText(node.textContent))) node.remove();
      });
    },
    headingFormatter: function(title) {
      return cleanDocsHeadingText(title).replace(/[¶↑]/g, "").replace(/\s+</g, " < ");
    }
  });
}
