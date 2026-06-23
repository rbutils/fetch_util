  function mkdocsMaterialContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "mkdocs") return null;

    return docsContentBySelectors(metadata, [
      "main .md-content__inner",
      "main .md-content",
      "article.md-content__inner",
      "main article",
      "main"
    ], {
      titleSelectors: ["main h1", "article h1"],
      fallbackTitle: function(metadata) { return normalizeText(metadata.title || document.title); },
      rewriteRoot: function(root) {
        root.querySelectorAll(".md-source-file, .md-content__button, .md-feedback, .mdx-badge, .md-nav, .md-sidebar, aside").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, button, a", /^(table of contents|view source|edit this page)$/i);
        root.querySelectorAll(".admonition, details.note, details.tip, details.warning, details.info, details.danger, details.example, details.question, details.abstract, details.success, details.failure, details.bug, details.quote").forEach(function(el) {
          var titleEl = el.querySelector(".admonition-title, summary");
          var admonitionType = normalizeText((titleEl && titleEl.textContent) || "Note").toUpperCase();
          if (titleEl) titleEl.remove();
          var content = normalizeText(el.textContent);
          if (content) {
            var bq = document.createElement("blockquote");
            bq.innerHTML = "<p><strong>" + admonitionType + ":</strong> " + content + "</p>";
            el.replaceWith(bq);
          }
        });
        root.querySelectorAll("font").forEach(function(el) {
          el.replaceWith(document.createTextNode(el.textContent));
        });
      }
    });
  }

  function mdBookContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "mdbook") return null;

    return docsContentBySelectors(metadata, [
      "#content main",
      "#content",
      "main"
    ], {
      titleSelectors: ["#content main h1", "#content h1", "main h1"],
      fallbackTitle: function(metadata) {
        return normalizeText((metadata.title || document.title).replace(/\s*-\s*The Rust Programming Language$/i, ""));
      },
      rewriteRoot: function(root) {
        root.querySelectorAll("#sidebar, #sidebar-toggle, nav.sidebar, #menu-bar, #menu-bar-hover-placeholder, .nav-wrapper, .nav-chapters, .chapter, #sidebar-resize-handle, .mobile-nav-chapters").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, span", /^(print this book|light|rust|coal|navy|ayu|change theme|toggle table of contents|keyboard shortcuts)$/i);
      }
    });
  }

  function docusaurusDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "docusaurus") return null;

    return docsContentBySelectors(metadata, [
      "main article",
      "main .theme-doc-markdown",
      "article .theme-doc-markdown",
      "main [class*='docItemContainer']",
      "main"
    ], {
      titleSelectors: ["main h1", "article h1", ".theme-doc-markdown h1"],
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, ""); },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, .theme-doc-breadcrumbs, .theme-doc-toc-desktop, .theme-doc-toc-mobile, .pagination-nav, .theme-edit-this-page, .theme-last-updated").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(skip to main content|on this page|edit this page|copy for llm|view as markdown|ask ai|search)$/i);
        cleanDocsHeadings(root);
      }
    });
  }

  function mintlifyDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "mintlify") return null;

    return docsContentBySelectors(metadata, [
      "#content-area",
      "[id='content-area']",
      "main article",
      "main",
      "article"
    ], {
      titleSelectors: ["main h1", "article h1", "h1"],
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, ""); },
      rewriteRoot: function(root) {
        var firstHeading = root.querySelector("h1");
        if (firstHeading) {
          var sibling = root.firstElementChild;
          while (sibling && sibling !== firstHeading) {
            var next = sibling.nextElementSibling;
            if (sibling.contains(firstHeading)) break;
            sibling.remove();
            sibling = next;
          }
        }
        root.querySelectorAll("nav, aside, .menu, .sidebar, footer, .pagination, .table-of-contents, .theme-toggle, [data-testid='table-of-contents'], [aria-label='Table of contents'], [class*='sidebar'], [class*='toc'], #page-context-menu, #page-context-menu-button, #pagination").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(copy page|copy for llm|view as markdown|ask ai|ask an ai|on this page|table of contents|search|skip to content|skip to main content|ctrl\+?\s*[a-z]|ctrl\s+[a-z])$/i);
        root.querySelectorAll("div, aside, p, span").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/^api reference sidebar$/i.test(text)) el.remove();
        });
        root.querySelectorAll(".eyebrow").forEach(function(el) {
          if (normalizeText(el.textContent).length <= 40) el.remove();
        });
        cleanDocsHeadings(root);
      }
    });
  }

  function gitbookDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "gitbook") return null;

    var node = firstMatchingNode([
      "main [class*='whitespace-pre-wrap']",
      "main .space-y-5",
      "main",
      "article",
      "[role='main']"
    ]);

    return docsArticleContent(metadata, node, {
      title: cleanDocsHeadingText(firstText(["main header h1", "main h1", "h1"]) || (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, "").replace(/\s*\|.*$/, "")),
      focusFragment: false,
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, header, [class*='sidebar'], [class*='Sidebar'], [class*='TableOfContents'], [class*='toc'], [class*='navigation']").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(copy page|copy for llm|copy page as markdown|open in chatgpt|open in claude|connect to cursor|view as markdown|powered by gitbook|was this page helpful\??|previous|next|last updated|on this page|table of contents|ask or search|search|skip to content|skip to main content)$/i);
        cleanDocsHeadings(root);
      }
    });
  }

  function scalarDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "scalar") return null;

    var node = firstMatchingNode([
      ".scalar-api-reference section",
      ".scalar-api-reference [class*='content']",
      ".scalar-api-reference main",
      ".scalar-api-reference",
      ".scalar-app",
      "main"
    ]);

    return docsArticleContent(metadata, node, {
      title: cleanDocsHeadingText(firstText([".scalar-api-reference h1", "main h1", "h1"]) || (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, "")),
      focusFragment: false,
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, [class*='sidebar'], [class*='Sidebar'], [class*='search'], [class*='Search']").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(skip to content|search|try it|send request|copy|download openapi spec|client libraries)$/i);
        cleanDocsHeadings(root);
      }
    });
  }
