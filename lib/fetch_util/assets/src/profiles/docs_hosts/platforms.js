  function awsDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)docs\.aws\.amazon\.com$/) && !/aws/i.test(signature)) return null;

    return docsContentBySelectors(metadata, ["#main-col-body", "#main-content #main-col-body", "#main-content", "main"], {
      titleSelectors: ["#main-content h1", "#main-col-body h1", "main h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/\s*-\s*AWS.*$/, "")); },
      removeCookiePrefs: true,
      removeMarketingTips: true,
      rewriteRoot: function(root) {
        root.querySelectorAll("awsdocs-language-banner, awsdocs-page-header, awsdocs-filter-selector, .awsdocs-page-header-container, .awsdocs-note.awsdocs-tip").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("section, div, aside").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if (/join serverless experts|builder center|click here to sign up/i.test(text) && text.length < 800) el.remove();
        });
      }
    });
  }

  function mdnDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)developer\.mozilla\.org$/) && !/mdn|mozilla/i.test(signature)) return null;
    if (!/^\/.*\/docs\//.test(location.pathname) && !/^\/en-US\//.test(location.pathname) && !/mdn|mozilla/i.test(signature)) return null;

    return docsContentBySelectors(metadata, ["main article", "article.main-page-content", "main .main-page-content", "main"], {
      titleSelectors: ["main article h1", "article.main-page-content h1", "main h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/\s*-\s*MDN.*$/, "")); },
      removeTryIt: true,
      rewriteRoot: function(root) {
        root.querySelectorAll("section, div, aside").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if ((/^baseline\b/i.test(text) || /this feature is well established and works across many devices/i.test(text)) && text.length < 800) el.remove();
        });
        // Strip empty "Browser compatibility" sections (compat tables are JS-rendered widgets)
        // Also strip other empty documentation sections (e.g., "Examples" with no content)
        root.querySelectorAll("section, div").forEach(function(el) {
          var heading = el.querySelector("h2, h3");
          if (!heading) return;
          var headingText = normalizeText(heading.textContent);
          if (!headingText) return;
          // Check if the section body (minus heading text) is essentially empty
          var text = normalizeText(el.textContent);
          var headingLen = headingText.length;
          if (text.length - headingLen < 30) el.remove();
        });
        // Strip BCD table containers that are empty
        root.querySelectorAll("table.bc-table, [class*='bc-table'], [class*='bcd-table']").forEach(function(el) {
          if (normalizeText(el.textContent).length < 30) el.remove();
        });
      }
    });
  }

  function githubDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)docs\.github\.com$/) && !/github docs/i.test(signature)) return null;

    var root = githubRestOperationsRoot() || firstMatchingNode(["main .markdown-body", "main"]);

    return docsContentForNode(metadata, root, {
      titleSelectors: ["main h1", ".markdown-body h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/\s*-\s*GitHub Docs$/i, "")); },
      rewriteRoot: function(root) {
        root.querySelectorAll("[role='tablist'], ul[class*='SegmentedControl'], .prc-SegmentedControl-SegmentedControl-lqIXp").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, button, a", /^(copy to clipboard|request example|response)$/i);
      }
    });
  }

  function githubRestOperationsRoot() {
    if (!/^\/(?:[a-z]{2}(?:-[A-Z]{2})?\/)?rest\//.test(location.pathname || "")) return null;

    var main = document.querySelector("main#main-content, main");
    if (!main) return null;

    var operationHeadings = Array.prototype.filter.call(main.querySelectorAll("h2, h3"), function(heading) {
      var text = normalizeText(heading.textContent);
      return text && !/^(fine-grained access tokens|parameters|http response status codes|code samples)\b/i.test(text);
    });

    return operationHeadings.length >= 2 ? main : null;
  }

  function hashicorpDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)developer\.hashicorp\.com$/) && !/hashicorp|terraform/i.test(signature)) return null;

    return docsContentBySelectors(metadata, ["main article", "main", "article"], {
      titleSelectors: ["main article h1", "main h1", "article h1"],
      fallbackTitle: function(metadata) { return metadata.title || document.title; },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, .sidebar, [data-testid='side-nav'], [data-testid='breadcrumbs']").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, button, a", /^(on this page|edit this page on github|cookie manager|theme)$/i);
        root.querySelectorAll("details summary").forEach(function(el) {
          var text = compactReferenceText(el.textContent);
          if (text) {
            var heading = document.createElement("h3");
            heading.textContent = text;
            el.replaceWith(heading);
          }
        });
      }
    });
  }

  function dockerDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)docs\.docker\.com$/) && !/docker/i.test(signature)) return null;

    return docsContentBySelectors(metadata, ["main article", "main", "article"], {
      titleSelectors: ["main article h1", "main h1", "article h1"],
      fallbackTitle: function(metadata) { return metadata.title || document.title; },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, .toc, .sidebar, [data-pagefind-ignore]").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, button, a", /^(table of contents|on this page|edit this page|copy page)$/i);
      }
    });
  }

  function grafanaDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)grafana\.com$/) || !/^\/docs\//.test(location.pathname)) return null;
    if (!/grafana/i.test(signature)) return null;

    return docsContentBySelectors(metadata, ["main article", "main", "article"], {
      titleSelectors: ["main article h1", "main h1", "article h1"],
      fallbackTitle: function(metadata) { return (metadata.title || document.title).replace(/\s*\|\s*Grafana.*$/i, ""); },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, aside, footer, [aria-label='breadcrumb'], [data-testid='sidebar'], .toc, .sidebar").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, button, a", /^(on this page|scroll for more|suggest an edit in github|create a github issue|email docs@grafana\.com|help and support|your cookie preferences|got it!)$/i);
        root.querySelectorAll("section, div").forEach(function(el) {
          var text = normalizeText(el.textContent);
          if ((/^is this page helpful\??/i.test(text) || /^was this page helpful\??/i.test(text)) && text.length < 200) el.remove();
          if (/^related resources from grafana labs/i.test(text) && text.length < 2500) el.remove();
        });
      }
    });
  }
