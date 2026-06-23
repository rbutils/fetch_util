  function readTheDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "readthedocs") return null;

    var titleText = docsTitleText(metadata, [".rst-content h1", ".wy-nav-content h1", "main h1", "h1"], function(metadata) {
      return metadata.title || document.title;
    });

    return docsContentBySelectors(metadata, [
      ".wy-nav-content .rst-content",
      ".rst-content",
      ".wy-nav-content",
      "div[role='main']",
      "main"
    ], {
      title: titleText,
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, .wy-breadcrumbs, .rst-footer-buttons, .wy-menu, .wy-nav-side, .wy-side-nav-search, .wy-nav-top").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("a.headerlink").forEach(function(el) {
          el.remove();
        });
        var seenTitle = false;
        root.querySelectorAll("h1").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent);
          if (normalizeText(el.textContent) === normalizeText(titleText)) {
            if (seenTitle) {
              el.remove();
              return;
            }
            seenTitle = true;
          }
        });
        root.querySelectorAll("h2, h3, h4, h5, h6").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent);
        });
      }
    });
  }

  function sphinxDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "sphinx") return null;

    return docsContentBySelectors(metadata, ["div.body[role='main']", "div.body", "[role='main']", "main"], {
      titleSelectors: ["div.body h1", "[role='main'] h1", "main h1"],
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*[—-]\s*[^—-]*documentation$/i, ""); },
      rewriteRoot: function(root) {
        root.querySelectorAll("a.headerlink, button.copybutton, .toc-backref, .sphinxsidebar, .sphinxsidebarwrapper, aside").forEach(function(el) {
          el.remove();
        });
        cleanDocsHeadings(root, "h1, h2, h3, h4");
        root.querySelectorAll("dt.sig").forEach(function(el) {
          var heading = document.createElement("h3");
          heading.textContent = cleanDocsHeadingText(el.textContent);
          el.replaceWith(heading);
        });
      }
    });
  }
