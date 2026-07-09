  function vitePressDocsContent(metadata, info) {
    return docsEngineContent(metadata, info, {
      system: "vitepress",
      rootSelectors: [
        ".VPDoc .vp-doc",
        ".VPContentDoc .vt-doc",
        "#VPContent .VPDoc",
        "#VPContent .VPContentDoc",
        "#VPContent article",
        ".vp-doc",
        ".vt-doc",
        "main"
      ],
      titleSelectors: ["#VPContent h1", ".VPDoc h1", ".VPContentDoc h1", ".vp-doc h1", ".vt-doc h1", "main h1"],
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*\|\s*[^|]*$/, ""); },
      removeSelectors: COMMON_DOCS_CHROME_SELECTOR + ", .VPDocFooter, .VPContentDocFooter, .VPDocAsideOutline, .aside, .pager-link, .prev-next, .outline-link",
      removeTextPattern: /^(skip to content|skip to main content|on this page|return to top|edit this page|previous page|next page|ads via carbon)$/i,
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
        root.querySelectorAll("div, p, span").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (text && text.length < 300 && /^are you an llm\b/i.test(text)) el.remove();
        });
        root.querySelectorAll("a[href], img").forEach(function(el) {
          var href = absoluteUrl(el.getAttribute && el.getAttribute("href"));
          var src = absoluteUrl(el.getAttribute && el.getAttribute("src"));
          if ((href && /carbonads|srv\.carbonads\.net/i.test(href)) || (src && /carbonads|srv\.carbonads\.net/i.test(src))) {
            var container = el.closest("div, p, section, aside, a") || el;
            if (container) container.remove();
          }
        });
      }
    });
  }

  function fernDocsContent(metadata, info) {
    return docsEngineContent(metadata, info, {
      system: "fern",
      rootSelectors: [
        ".fern-layout-reference article",
        ".fern-layout-overview article",
        "article .fern-prose",
        "article",
        "main"
      ],
      titleSelectors: [".fern-page-heading", "article h1", "main h1"],
      fallbackTitle: docsFallbackTitleWithoutTrailingBrand,
      removeSelectors: COMMON_DOCS_CHROME_SELECTOR + ", #fern-sidebar, .fern-breadcrumb, .fern-page-actions, .toc-mobile, .fern-header-tabs, .fern-api-playground, .fern-endpoint-panel",
      removeTextPattern: /^(copy page|on this page|table of contents|previous|next)$/i
    });
  }

  function nextDocsContent(metadata, info) {
    return docsEngineContent(metadata, info, {
      system: "next",
      rootSelectors: [
        "main article",
        "main .prose",
        "main [data-docs-body]",
        "main [data-pagefind-body]",
        "main"
      ],
      titleSelectors: ["main article h1", "main .prose h1", "main h1", "h1"],
      fallbackTitle: docsFallbackTitleWithoutTrailingBrand,
      removeSelectors: COMMON_DOCS_CHROME_SELECTOR + ", header, footer, nav, aside, [class*='sidebar' i], [class*='toc' i], [class*='breadcrumb' i]",
      removeTextPattern: /^(skip to content|skip to main content|on this page|edit this page|previous|next|search)$/i,
      contentType: function(root, info) { return docsHomepageListLike(root, info) ? "list" : "article"; }
    });
  }

  function nextraDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "nextra") return null;

    return docsContentBySelectors(metadata, [
      "article.nextra-content main",
      ".nextra-content main",
      "main[data-pagefind-body='true']",
      ".nextra-content",
      "main"
    ], {
      titleSelectors: ["main h1", ".nextra-content h1", "h1"],
      fallbackTitle: docsFallbackTitleWithoutTrailingBrand,
      contentType: docsHomepageListLike(document.querySelector("main"), info) ? "list" : "article",
      rewriteRoot: function(root) {
        root.querySelectorAll(".nextra-cards, .not-prose").forEach(function(el) {
          el.classList.remove("not-prose");
        });
        root.querySelectorAll("a.nextra-card[href]").forEach(function(card) {
          var title = normalizeText(card.getAttribute("title") || card.querySelector("[title]") && card.querySelector("[title]").getAttribute("title") || card.textContent);
          var description = normalizeText(Array.prototype.slice.call(card.querySelectorAll("p")).map(function(p) { return p.textContent; }).join(" "));
          var href = card.getAttribute("href");
          if (!title || !href) return;

          var section = document.createElement("section");
          var list = document.createElement("ul");
          var item = document.createElement("li");
          var link = document.createElement("a");
          link.setAttribute("href", href);
          link.textContent = title;
          item.appendChild(link);
          list.appendChild(item);
          section.appendChild(list);
          if (description && description !== title) {
            var paragraph = document.createElement("p");
            paragraph.textContent = description;
            section.appendChild(paragraph);
          }
          card.replaceWith(section);
        });
        removeAll(root, COMMON_DOCS_CHROME_SELECTOR + ", .nextra-toc, .nextra-sidebar, .nextra-breadcrumb, .nextra-nav-container");
        removeNodesByText(root, "a, button, div, p, span, li", /^(copy page|on this page|skip to content|skip to main content|previous|next)$/i);
        root.querySelectorAll("a.subheading-anchor").forEach(function(el) {
          el.remove();
        });
        cleanDocsHeadings(root);
      },
      postProcessMarkdown: function(markdown, root) {
        if (!root || !root.querySelector(".nextra-cards")) return markdown;

        var lines = [];
        root.querySelectorAll(".nextra-cards a[href]").forEach(function(link) {
          var text = normalizeText(link.textContent || link.getAttribute("title"));
          var href = absoluteUrl(link.getAttribute("href"));
          if (!text || !href || markdown.indexOf(href) !== -1) return;
          lines.push("- [" + text + "](" + href + ")");
        });
        if (!lines.length) return markdown;

        return (markdown || "").trim() + "\n\n## Pages\n\n" + lines.join("\n");
      }
    });
  }

  function rspressDocsContent(metadata, info) {
    return docsEngineContent(metadata, info, {
      system: "rspress",
      rootSelectors: [
        ".rspress-doc",
        "main .rp-doc",
        "main article",
        "main"
      ],
      titleSelectors: ["main h1", "article h1", ".rspress-doc h1"],
      fallbackTitle: function(metadata) {
        return (metadata.title || document.title).replace(/\s*[-|]\s*[^-|]*$/, "");
      },
      preferFragmentTitle: false,
      removeSelectors: COMMON_DOCS_CHROME_SELECTOR + ", .rp-nav, .rp-sidebar, .rp-toc, .rp-doc-footer, .rp-breadcrumb, .rp-pagination",
      removeTextPattern: /^(skip to main content|on this page|edit this page|previous page|next page|back to top)$/i,
      rewriteRoot: function(root) {
        root.querySelectorAll("a.rp-header-anchor, .rp-header-anchor").forEach(function(el) {
          el.remove();
        });
      },
      headingFormatter: function(text) {
        return cleanDocsHeadingText(text).replace(/^#\s*/, "");
      }
    });
  }
