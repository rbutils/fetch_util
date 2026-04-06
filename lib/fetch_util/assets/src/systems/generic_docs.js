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
        // Convert MkDocs Material admonition boxes to blockquote-style callouts
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
        // Strip <font> tags but keep their text content
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
        // Remove LLM-redirect notices separately with a length guard to avoid nuking wrapper divs
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

  function readmeIoDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "readme") return null;

    // ReadMe.io has two page types: landing pages and article/reference pages.
    // Reference pages (/reference/) use a two-panel layout: .rm-Article (intro header)
    // and .rm-Playground (params, schemas, code examples). We need .rm-ReferenceMain
    // to capture both panels.
    var isRefPage = /\/reference\//i.test(location.pathname) ||
                    document.documentElement.classList.contains("isRefPage");
    var node = firstMatchingNode(isRefPage ? [
      ".rm-ReferenceMain",
      "main .rm-ReferenceMain",
      ".rm-Article",
      "main"
    ] : [
      ".rm-Article",
      "article",
      "main .rm-LandingPage",
      "main .rm-ReferenceMain",
      "main"
    ]);

    return docsArticleContent(metadata, node, {
      title: cleanDocsHeadingText(firstText(["article h1", ".rm-Article h1", "main h1", "h1"]) || (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, "")),
      focusFragment: false,
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, .rm-Sidebar, .hub-sidebar, [class*='Sidebar'], [class*='QuickNav'], [class*='ModalWrapper'], [class*='TableOfContents']").forEach(function(el) {
          el.remove();
        });
        // For reference pages with .rm-ReferenceMain: strip interactive playground chrome
        // while keeping parameter descriptions, schemas, and code examples
        root.querySelectorAll("[class*='LanguagePicker'], [class*='APIAuth'], [class*='TryItNow'], [class*='ResponseSchemaModal']").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(skip to content|skip to main content|on this page|suggest edits|updated .*|log in|sign up|search|api reference|did this page help you\??|retrieving recent requests[\u2026.]*|recent requests|loading[\u2026.]{1,3}|log in to see full request history|try it!?|responses?)$/i);
        // Remove ReadMe.io request-history table skeleton (Time | Status | User Agent)
        root.querySelectorAll("table").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/^\s*(time\s+status\s+user\s*agent)?\s*$/i.test(text) || (text.length < 60 && /time.*status.*user\s*agent/i.test(text))) {
            el.remove();
          }
        });
        root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent);
        });
      }
    });
  }

  function redocDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "redoc") return null;

    var node = firstMatchingNode([
      ".redoc-wrap .api-content",
      ".api-content",
      ".redoc-wrap [role='main']",
      ".redoc-wrap",
      "redoc",
      "main"
    ]);

    var result = docsArticleContent(metadata, node, {
      title: cleanDocsHeadingText(firstText([".api-content h1", ".redoc-wrap h1", "main h1", "h1"]) || (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, "")),
      focusFragment: false,
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, .menu-content, [class*='sidebar'], [class*='SideMenu'], [role='navigation']").forEach(function(el) {
          el.remove();
        });
        // Strip Redoc UI chrome
        removeNodesByText(root, "a, button, div, p, span, li", /^(download|download openapi specification:?|authorize|try it|send api request|copy|expand all|collapse all|payload|loading[\u2026.]{1,3})$/i);

        // Convert ReDoc JSON DOM trees (nested <ul><li><span> structures) into
        // <pre><code> blocks BEFORE we strip tab containers.
        normalizeRedocJsonBlocks(root);

        // For response sample tabs: keep only the first/selected tab panel,
        // strip tab navigation and non-selected panels to reduce output size.
        root.querySelectorAll("[data-rttabs]").forEach(function(tabContainer) {
          // Find the selected/first tab panel with content
          var panels = tabContainer.querySelectorAll("[role='tabpanel']");
          var keptPanel = null;
          for (var i = 0; i < panels.length; i++) {
            if (panels[i].querySelector("pre, code") || normalizeText(panels[i].textContent).length > 20) {
              keptPanel = panels[i];
              break;
            }
          }
          // Remove tab list (status code buttons)
          tabContainer.querySelectorAll("[role='tablist'], [role='tab']").forEach(function(el) {
            el.remove();
          });
          // Remove empty/non-selected panels
          for (var j = 0; j < panels.length; j++) {
            if (panels[j] !== keptPanel) panels[j].remove();
          }
        });

        // Strip remaining select dropdowns
        root.querySelectorAll("select.dropdown-select").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("label").forEach(function(el) {
          if (normalizeText(el.textContent).length <= 120) el.remove();
        });
        root.querySelectorAll("div, section").forEach(function(el) {
          if (!normalizeText(el.textContent) && !el.querySelector("img, svg, pre, code, table, ul, ol")) el.remove();
        });
        root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent).replace(/([\w/+.-]+)(required)$/i, "$1 required");
        });
      }
    });
    return result;
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
      titleSelectors: ["main h1", "article h1"],
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
        root.querySelectorAll("nav, aside, footer, [data-testid='table-of-contents'], [aria-label='Table of contents'], [class*='sidebar'], [class*='toc'], #page-context-menu, #page-context-menu-button").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(copy page|copy for llm|view as markdown|ask ai|ask an ai|on this page|table of contents|search|skip to content|skip to main content|ctrl\+?\s*[a-z]|ctrl\s+[a-z])$/i);
        root.querySelectorAll("#pagination").forEach(function(el) {
          el.remove();
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
        root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent);
        });
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
        root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent);
        });
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
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, ""); },
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
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*[|\-]\s*[^|\-]*$/, ""); },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, .nextra-toc, .nextra-sidebar, .nextra-breadcrumb, .nextra-nav-container").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(copy page|on this page|skip to content|skip to main content|previous|next)$/i);
        root.querySelectorAll("a.subheading-anchor").forEach(function(el) {
          el.remove();
        });
        cleanDocsHeadings(root);
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

  function googleDevsiteContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "google_devsite") return null;

    var node = firstMatchingNode([
      "devsite-content article",
      "devsite-content .devsite-article-body",
      "article[class*='devsite']",
      "main article",
      "main"
    ]);

    var devsiteChromeRe = /\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi;
    var devsiteTitleClean = function(text) {
      return cleanDocsHeadingText((text || "").replace(devsiteChromeRe, "").replace(/\s*[|·]\s*(Google Cloud|Firebase|Android|Chrome).*$/i, ""));
    };

    return docsArticleContent(metadata, node, {
      title: devsiteTitleClean(firstText(["devsite-content h1", "article h1", "main h1"]) || metadata.title || document.title),
      rewriteRoot: function(root) {
        root.querySelectorAll("devsite-header, devsite-toc, devsite-nav, devsite-page-rating, devsite-feedback, devsite-thumb-rating, devsite-bookmark, devsite-feature-tooltip, nav, aside, footer").forEach(function(el) {
          el.remove();
        });
        // Strip "Stay organized with collections Save and categorize content based on your preferences."
        root.querySelectorAll("section, div, p, span, h2, h3, h4").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/stay organized with collections/i.test(text) && /save and categorize content/i.test(text) && text.length < 200) {
            el.remove();
            return;
          }
          // Strip just the chrome text from headings if it got merged in
          if (/^(h[1-6])$/i.test(el.tagName)) {
            el.textContent = normalizeText(el.textContent).replace(devsiteChromeRe, "");
          }
        });
        // Strip license footer
        root.querySelectorAll("div, section, p").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/except as otherwise noted.*creative commons/i.test(text) && text.length < 600) el.remove();
          if (/^(content and samples on this page|except as otherwise noted)/i.test(text) && text.length < 600) el.remove();
        });
        // Strip expandable section toggle text
        removeNodesByText(root, "a, button, span, div", /^(send feedback|view source|give feedback|was this helpful\??|star|more_vert|expand_more|expand_less|content_copy)$/i);
        root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent);
        });
        // Deduplicate H1 headings (Devsite often has both a page header and article heading)
        var h1s = root.querySelectorAll("h1");
        if (h1s.length > 1) {
          // Find the shortest H1 text as the canonical title
          var shortestIdx = 0;
          var shortestLen = normalizeText(h1s[0].textContent).length;
          for (var i = 1; i < h1s.length; i++) {
            var len = normalizeText(h1s[i].textContent).length;
            if (len > 0 && len < shortestLen) { shortestLen = len; shortestIdx = i; }
          }
          var canonicalText = normalizeText(h1s[shortestIdx].textContent).toLowerCase();
          for (var j = 0; j < h1s.length; j++) {
            if (j === shortestIdx) continue;
            var text = normalizeText(h1s[j].textContent).toLowerCase();
            if (text === canonicalText || text.indexOf(canonicalText) === 0 || canonicalText.indexOf(text) === 0) {
              h1s[j].remove();
            }
          }
        }
        // Also strip promotional banners that appear between/near headings
        root.querySelectorAll("section, div, p").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/enterprise edition.*now available|is now available.*learn more/i.test(text) && text.length < 300) el.remove();
        });
      }
    });
  }

  function elasticDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "elastic_docs") return null;

    var node = firstMatchingNode([
      "main article",
      "main [class*='docBody']",
      "article",
      "main"
    ]);

    return docsArticleContent(metadata, node, {
      title: cleanDocsHeadingText(firstText(["main article h1", "article h1", "main h1"]) || (metadata.title || document.title).replace(/\s*\|\s*Elasticsearch.*$/i, "")),
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer").forEach(function(el) {
          el.remove();
        });
        // Strip empty anchor links that appear before heading text (Elastic anchor-ID spans)
        root.querySelectorAll("a[href]").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (!text && el.querySelector("svg, .icon")) el.remove();
          if (!text && !el.querySelector("img") && el.getAttribute("href") && /^#/.test(el.getAttribute("href"))) el.remove();
        });
        // Strip "Hide attributes Show attributes" toggle text
        removeNodesByText(root, "button, a, span, div, p", /^(hide attributes?|show attributes?|hide child attributes?|show child attributes?)$/i);
        root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
          el.textContent = cleanDocsHeadingText(el.textContent);
        });
      }
    });
  }

  function genericDocsSystemContent(metadata) {
    var info = docsSystemInfo(metadata);
    return stlDocsContent(metadata, info) || rustdocContent(metadata, info) || goPkgDocsSystemContent(metadata, info) || googleDevsiteContent(metadata, info) || elasticDocsContent(metadata, info) || readmeIoDocsContent(metadata, info) || redocDocsContent(metadata, info) || mintlifyDocsContent(metadata, info) || gitbookDocsContent(metadata, info) || scalarDocsContent(metadata, info) || fernDocsContent(metadata, info) || nextraDocsContent(metadata, info) || docusaurusDocsContent(metadata, info) || vitePressDocsContent(metadata, info) || rspressDocsContent(metadata, info) || mkdocsMaterialContent(metadata, info) || mdBookContent(metadata, info) || antoraDocsContent(metadata, info) || readTheDocsContent(metadata, info) || sphinxDocsContent(metadata, info);
  }
