  function railsGuidesContent(metadata) {
    var signature = docsHostSignature(metadata).toLowerCase();
    if (!hostMatches(/(^|\.)(guides|edgeguides)\.rubyonrails\.org$/) && !/ruby on rails guides/.test(signature)) return null;

    var node = firstMatchingNode(["#main", "main article", "main", "article"]);
    if (!node) return null;
    var guideSummary = firstRootText(node, ["p"]);

    var content = docsContentForNode(metadata, node, {
      titleSelectors: ["#main h1", "main h1", "article h1"],
      fallbackTitle: function() {
        return (metadata.title || document.title).replace(/\s*[—-]\s*Ruby on Rails Guides$/i, "");
      },
      rewriteRoot: function(root) {
        root.querySelectorAll("#topNav, #feature, #subCol, #subColWrap, #guides, #guides-index, .guides-index, .guide-index, .chapter, .chapter-list, .sidebar, aside, nav, header").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, p, div, span", /^(skip to main content|skip to article body)$/i);
        removeNodesByText(root, "h2, h3", /^chapters$/i);
        root.querySelectorAll("ol, ul").forEach(function(el) {
          if (tocLikeNode(el)) el.remove();
        });
      }
    });

    if (!content) return null;

    var intro = normalizeText(guideSummary || content.excerpt);
    if (intro && content.markdown.indexOf(intro) === -1) {
      var body = content.markdown;
      if (markdownStartsWithTitle(body, content.title)) body = body.split("\n\n").slice(1).join("\n\n");
      content.markdown = ["# " + content.title, intro, body].filter(Boolean).join("\n\n");
      content.textContent = normalizeText(content.markdown);
    }

    return content;
  }

  function rdocDocsContent(metadata) {
    var signature = docsHostSignature(metadata).toLowerCase();
    var isMediaWiki = !!document.querySelector("body.mediawiki, #mw-content-text, .mw-parser-output, meta[name='generator'][content^='MediaWiki']");
    var rdocLike = hostMatches(/(^|\.)(api\.rubyonrails\.org|ruby-doc\.org)$/) || /rdoc documentation/.test(signature) || (!isMediaWiki && !!document.querySelector("#class-metadata, #bodyContent"));
    if (!rdocLike) return null;
    if (/documenting the ruby language/i.test(metadata.title || document.title) && !document.querySelector("#class-metadata, #bodyContent, main h1")) return null;

    var node = firstMatchingNode(["#bodyContent", "#content", "#main", "main"]);
    if (!node) return null;

    return docsContentForNode(metadata, node, {
      titleSelectors: ["#bodyContent h1", "#content h1", "#main h1", "main h1"],
      fallbackTitle: function() { return metadata.title || document.title; },
      titleFormatter: function(title) {
        return title.replace(/\s*-\s*RDoc Documentation$/i, "").replace(/^(class|module)\s+/i, "");
      },
      rewriteRoot: function(root) {
        root.querySelectorAll("form, nav, header, #class-metadata, .method-source-code, .source_code, .filetree, .panel, .search-section, .quicksearch, aside").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, span, div, p", /^(skip to content|skip to search|search|menu|index)$/i);
        removeNodesByText(root, "h2, h3", /^(home|what(?:’|')?s here)$/i);
        root.querySelectorAll("h1").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("ul, ol, div, section").forEach(function(el) {
          if (tocLikeNode(el)) el.remove();
        });
        root.querySelectorAll("a").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/^(¶|↑)$/.test(text)) el.remove();
        });
        root.querySelectorAll("h1, h2, h3, h4").forEach(function(el) {
          el.textContent = normalizeText(el.textContent).replace(/[¶↑]/g, "").replace(/\s+</g, " < ");
        });
      }
    });
  }

  function railsApiContent(metadata) {
    var signature = docsHostSignature(metadata).toLowerCase();
    if (!hostMatches(/(^|\.)api\.rubyonrails\.org$/) && !/rubyonrails|activerecord::|actioncontroller::/.test(signature)) return null;
    return rdocDocsContent(metadata);
  }

  function registerRailsRdocProfiles() {
    registerHostAwareProfile(true, railsGuidesContent);
    registerHostAwareProfile(true, rdocDocsContent);
    registerHostAwareProfile(true, railsApiContent);
  }
