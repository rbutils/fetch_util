  function readTheDocsContent(metadata, info) {
    return docsEngineContent(metadata, info, {
      system: "readthedocs",
      rootSelectors: [
        ".wy-nav-content .rst-content",
        ".rst-content",
        ".wy-nav-content",
        "div[role='main']",
        "main"
      ],
      titleSelectors: [".rst-content h1", ".wy-nav-content h1", "main h1", "h1"],
      fallbackTitle: function(metadata) {
        return metadata.title || document.title;
      },
      preferFragmentTitle: false,
      contentType: function(root, info) { return docsHomepageListLike(root, info) ? "list" : "article"; },
      removeSelectors: "nav, aside, footer, .wy-breadcrumbs, .rst-footer-buttons, .wy-menu, .wy-nav-side, .wy-side-nav-search, .wy-nav-top",
      rewriteRoot: function(root, titleText) {
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
      }
    });
  }

  function sphinxDocsContent(metadata, info) {
    return docsEngineContent(metadata, info, {
      system: "sphinx",
      rootSelectors: ["div.document > div > div.section", "div.document > div.section", ".document", "div.body[role='main']", "div.body", "[role='main']", "main"],
      titleSelectors: [".document h1", "div.body h1", "[role='main'] h1", "main h1"],
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*[—-]\s*[^—-]*documentation$/i, ""); },
      contentType: function(root, info) { return docsHomepageListLike(root, info) ? "list" : "article"; },
      removeSelectors: "a.headerlink, button.copybutton, .toc-backref, .sphinxsidebar, .sphinxsidebarwrapper, [role='navigation'], aside",
      headingSelector: "h1, h2, h3, h4",
      rewriteRoot: function(root) {
        root.querySelectorAll("dt.sig").forEach(function(el) {
          var heading = document.createElement("h3");
          heading.textContent = cleanDocsHeadingText(el.textContent);
          el.replaceWith(heading);
        });
      }
    });
  }
