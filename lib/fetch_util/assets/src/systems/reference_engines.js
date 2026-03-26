  function rustdocContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "rustdoc") return null;

    var node = firstMatchingNode(["main", ".rustdoc", "body"]);
    return docsContentForNode(metadata, node, {
      titleSelectors: ["main h1", ".rustdoc h1", "h1"],
      fallbackTitle: function() { return metadata.title || document.title; },
      titleFormatter: function(title) {
        return title.replace(/\s+copy item path$/i, "");
      },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, #sidebar, .sidebar, .sub-sidebar-menu, #settings, #help-button, #crate-search, .mobile-topbar, .sidebar-elems, .out-of-band").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, span, p", /^(search|settings|help|copy item path|expand description|show sidebar|hide sidebar|toggle sidebar|source|collapse all|expand all)$/i);
        root.querySelectorAll("a[href]").forEach(function(el) {
          var title = normalizeText(el.getAttribute("title"));
          var text = normalizeText(el.textContent);
          if (/show sidebar|hide sidebar|toggle sidebar/i.test(title) || /^(search|settings|help|source|§)$/i.test(text)) el.remove();
        });
        // Strip srclink/source anchors
        root.querySelectorAll("a.srclink, a.src, a[class*='srclink']").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("h1, h2, h3, h4").forEach(function(el) {
          el.textContent = normalizeText(el.textContent).replace(/\s+copy item path$/i, "").replace(/^§\s*/, "");
        });
      }
    });
  }

  function goPkgDocsSystemContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "go_pkg") return null;

    var node = firstMatchingNode(["#main-content", "main", "body"]);
    return docsContentForNode(metadata, node, {
      titleSelectors: ["#main-content h1", "main h1", "h1"],
      fallbackTitle: function() { return metadata.title || document.title; },
      titleFormatter: function(title) {
        return title.replace(/\s*-\s*Go Packages$/i, "");
      },
      rewriteRoot: function(root) {
        root.querySelectorAll("header, nav, aside, footer, .go-Header, .go-MainHeader, .go-LeftNav, .go-DetailsHeader, .go-Main-aside").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, a, button", /^(jump to \.\.\.|documentation|details|repository|links|versions|licenses|imports|imported by)$/i);
      }
    });
  }
