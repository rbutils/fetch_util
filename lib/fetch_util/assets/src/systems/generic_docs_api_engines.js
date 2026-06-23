  function readmeIoDocsContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "readme") return null;

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
        root.querySelectorAll("[class*='LanguagePicker'], [class*='APIAuth'], [class*='TryItNow'], [class*='ResponseSchemaModal']").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, p, span, li", /^(skip to content|skip to main content|on this page|suggest edits|updated .*|log in|sign up|search|api reference|did this page help you\??|retrieving recent requests[\u2026.]*|recent requests|loading[\u2026.]{1,3}|log in to see full request history|try it!?|responses?)$/i);
        root.querySelectorAll("table").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/^\s*(time\s+status\s+user\s*agent)?\s*$/i.test(text) || (text.length < 60 && /time.*status.*user\s*agent/i.test(text))) {
            el.remove();
          }
        });
        cleanDocsHeadings(root);
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
        removeNodesByText(root, "a, button, div, p, span, li", /^(download|download openapi specification:?|authorize|try it|send api request|copy|expand all|collapse all|payload|loading[\u2026.]{1,3})$/i);
        normalizeRedocJsonBlocks(root);
        root.querySelectorAll("[data-rttabs]").forEach(function(tabContainer) {
          var panels = tabContainer.querySelectorAll("[role='tabpanel']");
          var keptPanel = null;
          for (var i = 0; i < panels.length; i++) {
            if (panels[i].querySelector("pre, code") || normalizeText(panels[i].textContent).length > 20) {
              keptPanel = panels[i];
              break;
            }
          }
          tabContainer.querySelectorAll("[role='tablist'], [role='tab']").forEach(function(el) {
            el.remove();
          });
          for (var j = 0; j < panels.length; j++) {
            if (panels[j] !== keptPanel) panels[j].remove();
          }
        });
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
        root.querySelectorAll("section, div, p, span, h2, h3, h4").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/stay organized with collections/i.test(text) && /save and categorize content/i.test(text) && text.length < 200) {
            el.remove();
            return;
          }
          if (/^(h[1-6])$/i.test(el.tagName)) {
            el.textContent = normalizeText(el.textContent).replace(devsiteChromeRe, "");
          }
        });
        root.querySelectorAll("div, section, p").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/except as otherwise noted.*creative commons/i.test(text) && text.length < 600) el.remove();
          if (/^(content and samples on this page|except as otherwise noted)/i.test(text) && text.length < 600) el.remove();
        });
        removeNodesByText(root, "a, button, span, div", /^(send feedback|view source|give feedback|was this helpful\??|star|more_vert|expand_more|expand_less|content_copy)$/i);
        cleanDocsHeadings(root);
        var h1s = root.querySelectorAll("h1");
        if (h1s.length > 1) {
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
        root.querySelectorAll("a[href]").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (!text && el.querySelector("svg, .icon")) el.remove();
          if (!text && !el.querySelector("img") && el.getAttribute("href") && /^#/.test(el.getAttribute("href"))) el.remove();
        });
        removeNodesByText(root, "button, a, span, div, p", /^(hide attributes?|show attributes?|hide child attributes?|show child attributes?)$/i);
        cleanDocsHeadings(root);
      }
    });
  }
