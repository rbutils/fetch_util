function rdocSystemPresent(generator, signature) {
  if (document.querySelector("body.mediawiki, #mw-content-text, .mw-parser-output, meta[name='generator'][content^='MediaWiki']")) return false;
  if (/rdoc/i.test(generator || "") || /rdoc documentation/i.test(signature || "")) return true;
  var metadata = document.querySelector("#class-metadata");
  if (metadata && !elementSubtreeHidden(metadata)) return true;
  var body = document.querySelector("#bodyContent");
  if (!body || elementSubtreeHidden(body)) return false;
  return Array.prototype.some.call(body.querySelectorAll("h1, h2"), function(heading) {
    return !elementSubtreeHidden(heading) && /^(?:class|module)\s+[A-Z][\w:]*(?:\s*<\s*[A-Z][\w:]*)?(?:\s*[¶↑])*$/i.test(normalizeText(heading.textContent));
  });
}

function rdocDocsContent(metadata, info) {
  return docsEngineContent(metadata, info, {
    system: "rdoc",
    rootSelectors: ["#bodyContent", "#content", "#main", "main"],
    titleSelectors: ["#bodyContent h1", "#content h1", "#main h1", "main h1"],
    fallbackTitle: function() { return metadata.title || document.title; },
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
