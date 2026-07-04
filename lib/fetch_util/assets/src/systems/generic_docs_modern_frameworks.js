  function vitePressDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "vitepress") return null;

    return docsContentBySelectors(metadata, [
      ".VPDoc .vp-doc",
      ".VPContentDoc .vt-doc",
      "#VPContent .VPDoc",
      "#VPContent .VPContentDoc",
      "#VPContent article",
      ".vp-doc",
      ".vt-doc",
      "main"
    ], {
      titleSelectors: ["#VPContent h1", ".VPDoc h1", ".VPContentDoc h1", ".vp-doc h1", ".vt-doc h1", "main h1"],
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*\|\s*[^|]*$/, ""); },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, .VPDocFooter, .VPContentDocFooter, .VPDocAsideOutline, .aside, .edit-link, .pager-link, .prev-next, .outline-link").forEach(function(el) {
          el.remove();
        });
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
        removeNodesByText(root, "a, button, div, p, span, li", /^(skip to content|skip to main content|on this page|return to top|edit this page|previous page|next page|ads via carbon)$/i);
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
        cleanDocsHeadings(root);
      }
    });
  }

  function fernDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "fern") return null;

    return docsContentBySelectors(metadata, [
      ".fern-layout-reference article",
      ".fern-layout-overview article",
      "article .fern-prose",
      "article",
      "main"
    ], {
      titleSelectors: [".fern-page-heading", "article h1", "main h1"],
      fallbackTitle: docsFallbackTitleWithoutTrailingBrand,
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, #fern-sidebar, .fern-breadcrumb, .fern-page-actions, .toc-mobile, .fern-header-tabs, .fern-api-playground, .fern-endpoint-panel").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(copy page|on this page|table of contents|previous|next)$/i);
        cleanDocsHeadings(root);
      }
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
        root.querySelectorAll("nav, aside, footer, .nextra-toc, .nextra-sidebar, .nextra-breadcrumb, .nextra-nav-container").forEach(function(el) {
          el.remove();
        });
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
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "rspress") return null;

    var titleText = docsTitleText(metadata, ["main h1", "article h1", ".rspress-doc h1"], function(metadata) {
      return (metadata.title || document.title).replace(/\s*[-|]\s*[^-|]*$/, "");
    });
    if (titleText) titleText = titleText.replace(/^#\s*/, "");

    return docsContentBySelectors(metadata, [
      ".rspress-doc",
      "main .rp-doc",
      "main article",
      "main"
    ], {
      title: titleText,
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, .rp-nav, .rp-sidebar, .rp-toc, .rp-doc-footer, .rp-breadcrumb, .rp-pagination").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(skip to main content|on this page|edit this page|previous page|next page|back to top)$/i);
        root.querySelectorAll("a.rp-header-anchor, .rp-header-anchor").forEach(function(el) {
          el.remove();
        });
        cleanDocsHeadings(root, null, function(text) {
          return cleanDocsHeadingText(text).replace(/^#\s*/, "");
        });
      }
    });
  }
