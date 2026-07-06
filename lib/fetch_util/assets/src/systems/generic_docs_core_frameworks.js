  function docsFallbackTitleWithoutTrailingBrand(metadata) {
    return (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, "");
  }

  function mkdocsReferenceNavList() {
    if (!/\/(?:reference|api)\/?$/i.test(location.pathname || "")) return null;

    var current = location.href.replace(/#.*$/, "").replace(/\/$/, "") + "/";
    var active = Array.prototype.slice.call(document.querySelectorAll(".md-nav__link[href]")).find(function(link) {
      return absoluteUrl(link.getAttribute("href")).replace(/#.*$/, "").replace(/\/$/, "") + "/" === current;
    });
    var section = active && active.closest(".md-nav__item--nested, .md-nav__item--section, .md-nav__item");
    var nav = section && section.querySelector("nav.md-nav");
    if (!nav) return null;

    var seen = {};
    var links = [];
    nav.querySelectorAll("a[href]").forEach(function(link) {
      var href = absoluteUrl(link.getAttribute("href"));
      var cleanHref = href.replace(/#.*$/, "").replace(/\/$/, "") + "/";
      var text = normalizeText(link.textContent);
      if (!text || cleanHref === current || seen[cleanHref]) return;
      seen[cleanHref] = true;
      links.push({ title: text, href: href });
    });
    if (links.length < 3) return null;

    var wrapper = document.createElement("section");
    var heading = document.createElement("h2");
    var list = document.createElement("ul");
    heading.textContent = "Reference Pages";
    wrapper.appendChild(heading);
    links.slice(0, 50).forEach(function(item) {
      var li = document.createElement("li");
      var a = document.createElement("a");
      a.href = item.href;
      a.textContent = item.title;
      li.appendChild(a);
      list.appendChild(li);
    });
    wrapper.appendChild(list);
    return wrapper;
  }

  function mkdocsReferenceNavMarkdown(section) {
    if (!section) return "";

    var items = Array.prototype.slice.call(section.querySelectorAll("a[href]")).map(function(link) {
      return "- [" + normalizeText(link.textContent) + "](" + link.href + ")";
    }).filter(Boolean);
    return items.length ? "## Reference Pages\n\n" + items.join("\n") : "";
  }

  function mkdocsMaterialContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "mkdocs") return null;
    var referenceNavMarkdown = "";

    return docsContentBySelectors(metadata, [
      "main .md-content__inner",
      "main .md-content",
      "article.md-content__inner",
      "main article",
      "main"
    ], {
      titleSelectors: ["main h1", "article h1"],
      fallbackTitle: function(metadata) { return normalizeText(metadata.title || document.title); },
      postProcessMarkdown: function(markdown) {
        if (!referenceNavMarkdown || /## Reference Pages[\s\S]*\n\s*-\s+\[/.test(markdown)) return markdown;
        markdown = markdown.replace(/\n*## Reference Pages\s*$/i, "");
        return [markdown, referenceNavMarkdown].filter(Boolean).join("\n\n");
      },
      rewriteRoot: function(root) {
        var referenceNav = mkdocsReferenceNavList();
        referenceNavMarkdown = mkdocsReferenceNavMarkdown(referenceNav);
        if (referenceNav && root.querySelectorAll("a[href]").length < 4) root.appendChild(referenceNav);
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
    return docsEngineContent(metadata, info, {
      system: "mdbook",
      rootSelectors: [
        "#content main",
        "#content",
        "main"
      ],
      titleSelectors: ["#content main h1", "#content h1", "main h1"],
      fallbackTitle: function(metadata) {
        return normalizeText((metadata.title || document.title).replace(/\s*-\s*The Rust Programming Language$/i, ""));
      },
      removeSelectors: "#sidebar, #sidebar-toggle, nav.sidebar, #menu-bar, #menu-bar-hover-placeholder, .nav-wrapper, .nav-chapters, .chapter, #sidebar-resize-handle, .mobile-nav-chapters",
      removeTextSelector: "a, button, div, span",
      removeTextPattern: /^(print this book|light|rust|coal|navy|ayu|change theme|toggle table of contents|keyboard shortcuts)$/i,
      headingFormatter: false
    });
  }

  function docusaurusDocsContent(metadata, info) {
    return docsEngineContent(metadata, info, {
      system: "docusaurus",
      rootSelectors: [
        "main article",
        "main .theme-doc-markdown",
        "article .theme-doc-markdown",
        "main [class*='docItemContainer']",
        "main"
      ],
      titleSelectors: ["main h1", "article h1", ".theme-doc-markdown h1"],
      fallbackTitle: docsFallbackTitleWithoutTrailingBrand,
      removeSelectors: "nav, aside, footer, .theme-doc-breadcrumbs, .theme-doc-toc-desktop, .theme-doc-toc-mobile, .pagination-nav, .theme-edit-this-page, .theme-last-updated",
      removeTextPattern: /^(skip to main content|on this page|edit this page|copy for llm|view as markdown|ask ai|search)$/i
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
      fallbackTitle: docsFallbackTitleWithoutTrailingBrand,
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
      title: cleanDocsHeadingText(firstText(["main header h1", "main h1", "h1"]) || docsFallbackTitleWithoutTrailingBrand(metadata).replace(/\s*\|.*$/, "")),
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
      title: cleanDocsHeadingText(firstText([".scalar-api-reference h1", "main h1", "h1"]) || docsFallbackTitleWithoutTrailingBrand(metadata)),
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
