  function stlDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || (info.system !== "stldocs" && info.system !== "starlight")) return null;

    var selectors = [
      "main .stldocs-content",
      "main .stldocs-resource-content",
      "main .stl-content-panel",
      "main article",
      "main [data-pagefind-body]",
      "main .sl-markdown-content",
      "main .content-panel",
      "main"
    ];
    var node = selectors.map(function(selector) {
      return Array.prototype.slice.call(document.querySelectorAll(selector));
    }).flat().sort(function(a, b) {
      function score(el) {
        var methodCount = el.querySelectorAll("[class*='stldocs-method-summary'], [class*='method-summary']").length;
        var routeCount = el.querySelectorAll("[class*='stldocs-method-route'], [class*='method-route']").length;
        var descCount = el.querySelectorAll("[class*='resource-description']").length;
        var propertyCount = el.querySelectorAll(".stldocs-property").length;
        var starlightBody = info.system === "starlight" && (el.matches(".sl-markdown-content, [data-pagefind-body]") || el.querySelector(".sl-markdown-content, [data-pagefind-body]"));
        var headingBody = info.system === "starlight" && el.querySelector("h1, h2") && el.querySelector("p, pre, code, ul, ol");
        var promoCard = info.system === "starlight" && el.matches("article.card, .card") && !el.querySelector("h1, h2");
        return (methodCount * 1000) + (routeCount * 200) + (propertyCount * 80) + (descCount * 50) + (starlightBody ? 5000 : 0) + (headingBody ? 800 : 0) - (promoCard ? 1200 : 0) + normalizeText(el.textContent).length;
      }

      return score(b) - score(a);
    })[0] || null;

    var summaryNode = cleanClone(node || document.body);
    cleanupAgentRoot(summaryNode);
    cleanupDocsRoot(summaryNode, {});
    var title = firstText(["main h1", "main article h1"]) || normalizeText(metadata.title || document.title);
    var methods = stlSectionSummary(summaryNode);
    var schemas = stlSchemaSummary(summaryNode, title);

    if (methods.length || schemas.length) {
      var description = stlResourceDescription(summaryNode, metadata, title);
      if (methods.length >= 6) {
        schemas = schemas.slice(0, 2).map(function(item) {
          return {
            declaration: item.declaration,
            description: item.description,
            fields: item.fields.slice(0, 3)
          };
        });
      }

      var markdownParts = [];
      if (title) markdownParts.push("# " + title);
      if (description) markdownParts.push(description);
      if (methods.length) markdownParts.push(stlMethodsMarkdown(methods));
      if (schemas.length) markdownParts.push(stlSchemasMarkdown(schemas));

      return {
        title: title || metadata.title,
        byline: null,
        excerpt: description || metadata.excerpt,
        siteName: metadata.siteName || location.hostname,
        publishedTime: null,
        html: "",
        markdown: markdownParts.filter(Boolean).join("\n\n").trim(),
        textContent: normalizeText(markdownParts.join(" ")),
        docsLike: true,
        readerMode: false,
        contentType: "article"
      };
    }

    return docsArticleContent(metadata, node, {
      title: firstText(["main h1", "main article h1"]) || normalizeText(metadata.title || document.title),
      rewriteRoot: function(root) {
        root.querySelectorAll("#starlight__sidebar, starlight-menu-button, [class*='stldocs-sidebar'], [class*='stldocs-sidebar-entry'], [class*='stldocs-expander'], [class*='sidebar-pane'], [class*='sidebar-content'], [class*='sidebar-accordion'], [class*='table-of-contents'], .stldocs-breadcrumbs, .stl-ui-dropdown, .discord, aside").forEach(function(el) {
          el.remove();
        });
        if (info.system === "starlight" && root.querySelector("h1, h2")) {
          root.querySelectorAll("article.card, .card").forEach(function(el) {
            var text = normalizeText(el.textContent);
            if (el.closest(".landing-card, .card--fullwidth") || el.querySelector(".title, .body")) return;
            if (text && text.length <= 600 && !el.querySelector("h1, h2, h3, h4, h5, h6")) el.remove();
          });
        }
        removeNodesByText(root, "div, p, span, button, a", /^(on this page|table of contents|copy page|edit page|expand|collapse|api reference)$/i);
        root.querySelectorAll("h1").forEach(function(el, index) {
          if (index > 0) el.remove();
        });
        root.querySelectorAll("h2, h3, h4, h5, h6, p, div, span").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/expand collapse/i.test(text)) el.remove();
          if (/^[A-Z][a-z]+(?:[A-Z][a-z]+){1,}$/.test(text) && text.length < 40) el.remove();
        });
      }
    });
  }

  function stlResourceDescription(root, metadata, title) {
    var selectors = [
      ".stldocs-resource-description",
      "[class*='resource-description']",
      ".stldocs-resource-content > p",
      ".stldocs-markdown > p",
      ".sl-markdown-content > p",
      "p"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = Array.prototype.slice.call(root.querySelectorAll(selectors[i]));

      for (var j = 0; j < nodes.length; j += 1) {
        var node = nodes[j];
        if (node.closest(".stldocs-property, [class*='stldocs-method-summary'], [class*='method-summary'], .stldocs-properties, [class*='resource-content-properties']")) continue;

        var text = compactReferenceText(normalizeText(node.textContent));
        if (!text || text === title || text.length < 20) continue;
        if (/^(models?\s*expand\s*collapse|api reference)$/i.test(text)) continue;

        return text;
      }
    }

    var fallback = compactReferenceText(normalizeText(metadata && metadata.excerpt));
    if (!fallback || fallback === title) return null;
    if (/^api reference for .* endpoints?$/i.test(fallback)) return null;
    return fallback;
  }
