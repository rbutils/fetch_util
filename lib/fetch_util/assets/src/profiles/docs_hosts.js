  function nextJsDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)nextjs\.org$/) && !/next\.js/i.test(signature)) return null;
    if (!/^\/docs\//.test(location.pathname)) return null;

    return docsContentBySelectors(metadata, ["main article", "main .prose", "main [data-docs-body]"], {
      titleSelectors: ["main article h1", "main .prose h1", "main h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/\s*[|·-]\s*Next\.js$/i, "")); }
    });
  }

  function reactDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)react\.dev$/) && !/react/i.test(signature)) return null;
    if (!/^\/(reference|learn)\//.test(location.pathname)) return null;

    return docsContentBySelectors(metadata, ["main article", "main [data-pagefind-body]", "main .max-w-4xl article"], {
      titleSelectors: ["main article h1", "main h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/\s*[–-]\s*React$/i, "")); }
    });
  }

  function formatStripeHeadingText(text) {
    text = normalizeText(text || "").replace(/deprecated$/i, " [Deprecated]");
    var match = text.match(/^([a-z0-9_.]+?)(nullable)?\s*(string|integer|object|array|boolean|enum|timestamp|hash|map|float)(expandable)?$/i);
    if (!match) return text.replace(/([a-z])([A-Z][a-z]+)/g, "$1 $2");

    var qualifiers = [];
    if (match[2]) qualifiers.push("nullable");
    qualifiers.push(match[3].toLowerCase());
    if (match[4]) qualifiers.push("expandable");
    return match[1] + " - " + qualifiers.join(" ");
  }

  function stripeApiContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)docs\.stripe\.com$/) && !/stripe/i.test(signature)) return null;
    if (!/^\/api\//.test(location.pathname) && !/api reference/i.test(signature)) return null;

    var primaryTitle = normalizeText((metadata.title || document.title).replace(/\s*[|·-]\s*Stripe API Reference$/i, ""));
    var matchedSection = Array.prototype.slice.call(document.querySelectorAll("main section, article section")).find(function(section) {
      var heading = section.querySelector("h1, h2, h3");
      heading = normalizeText(heading && heading.textContent);
      return heading && primaryTitle && (heading === primaryTitle || heading.indexOf(primaryTitle) === 0);
    });
    // Stripe API pages render multiple sibling <section> elements (intro, object,
    // create, update, retrieve, list, etc.). When the matched section has siblings,
    // use their common parent to capture all sections instead of just the intro.
    var node;
    if (matchedSection) {
      var parent = matchedSection.parentElement;
      var siblingCount = parent ? parent.querySelectorAll(":scope > section").length : 0;
      node = siblingCount > 1 ? parent : matchedSection;
    } else {
      node = document.querySelector("main article, article, main");
    }
    return docsContentForNode(metadata, node, {
      titleSelectors: ["article h1", "main h1"],
      fallbackTitle: primaryTitle,
      rewriteRoot: function(root) {
        removeNodesByText(root, "a, button, span, div, p", /^(ask about this section|copy for llm|view as markdown)$/i);
        root.querySelectorAll("a[href]").forEach(function(el) {
          var href = absoluteUrl(el.getAttribute("href"));
          var text = normalizeText(el.textContent);
          if (href === location.href.split("#")[0] && text === primaryTitle) el.remove();
        });
        // Stripe: remove collapsed/hidden accordion state elements
        // Stripe renders both collapsed summary and expanded detail in the DOM.
        // The collapsed state uses aria-hidden or display:none on some elements.
        root.querySelectorAll("[aria-hidden='true']").forEach(function(el) {
          // Only remove small aria-hidden elements that are accordion summaries
          if (textLength(el) < 2000) el.remove();
        });
        // Remove Stripe's collapsed toggle elements (summary rows that duplicate expanded detail)
        root.querySelectorAll("[class*='collapsed'], [class*='summary'], [class*='unexpanded']").forEach(function(el) {
          // Check if a sibling has the same heading/attribute name (indicating duplication)
          var nameEl = el.querySelector("code, strong, b, [class*='name']");
          var name = normalizeText(nameEl && nameEl.textContent);
          if (!name || name.length > 50) return;
          var sibling = el.nextElementSibling || el.previousElementSibling;
          if (sibling) {
            var sibNameEl = sibling.querySelector("code, strong, b, [class*='name']");
            var sibName = normalizeText(sibNameEl && sibNameEl.textContent);
            if (sibName === name) {
              // Remove the shorter one
              if (textLength(el) < textLength(sibling)) el.remove();
              else sibling.remove();
            }
          }
        });
        root.querySelectorAll("h2, h3, h4, h5, h6").forEach(function(el) {
          var formatted = formatStripeHeadingText(el.textContent);
          if (formatted) el.textContent = formatted;
        });
        // Deduplicate H1 headings (Stripe renders page title + section title as separate H1s)
        var h1s = root.querySelectorAll("h1");
        if (h1s.length > 1) {
          var seen = {};
          h1s.forEach(function(el) {
            var text = normalizeText(el.textContent).toLowerCase().replace(/\s*\[?deprecated\]?\s*$/i, "");
            if (seen[text]) { el.remove(); return; }
            seen[text] = true;
          });
        }
        // Format H1 headings too (for Deprecated badge)
        root.querySelectorAll("h1").forEach(function(el) {
          el.textContent = normalizeText(el.textContent).replace(/deprecated$/i, " [Deprecated]");
        });
      },
      postProcessMarkdown: function(markdown) {
        // Stripe accordion dedup at markdown level: remove bullet-list attribute summaries
        // when the same attribute appears as a heading with full description below.
        // Pattern: "- idstringUnique identifier...\n\n#### idstring\n\nUnique identifier..."
        // Both bullet items and headings glue name+type together (e.g. "idstring").
        var lines = markdown.split("\n");
        var headingNames = {};
        // First pass: collect heading attribute names (#### nameType or #### name - type)
        lines.forEach(function(line) {
          var m = line.match(/^#{2,6}\s+([a-z_][a-z0-9_]*(?:nullable\s*)?(?:string|integer|object|array|boolean|enum|timestamp|hash|map|float)?(?:\s*expandable)?)/i);
          if (m) headingNames[m[1].toLowerCase().replace(/\s+/g, "")] = true;
        });
        // Second pass: remove bullet items that match a heading attribute
        if (Object.keys(headingNames).length > 0) {
          var filtered = lines.filter(function(line) {
            var m = line.match(/^-\s+([a-z_][a-z0-9_]*(?:nullable\s*)?(?:string|integer|object|array|boolean|enum|timestamp|hash|map|float)?(?:\s*expandable)?)/i);
            if (!m) return true;
            var bulletKey = m[1].toLowerCase().replace(/\s+/g, "");
            return !headingNames[bulletKey];
          });
          markdown = filtered.join("\n");
        }
        return markdown;
      }
    });
  }

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

    return docsContentBySelectors(metadata, ["main .markdown-body", "main"], {
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

  function pythonDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)docs\.python\.org$/) && !/python .*documentation/i.test(signature)) return null;
    if (!/\/library\//.test(location.pathname) && !/python .*documentation/i.test(signature)) return null;

    return docsContentBySelectors(metadata, ["div.body[role='main']", "div.body", "[role='main']"], {
      titleSelectors: ["div.body h1", "[role='main'] h1"],
      fallbackTitle: function(metadata) { return normalizeText((metadata.title || document.title).replace(/¶$/, "").replace(/\s*—\s*Python.*$/, "")); },
      rewriteRoot: function(root) {
        root.querySelectorAll("a.headerlink, button.copybutton").forEach(function(el) {
          el.remove();
        });
        cleanDocsHeadings(root, "h1, h2, h3, h4", function(text) { return normalizeText(text).replace(/¶$/, ""); });
        root.querySelectorAll("dt.sig").forEach(function(el) {
          var heading = document.createElement("h3");
          heading.textContent = normalizeText(el.textContent).replace(/¶$/, "");
          el.replaceWith(heading);
        });
      }
    });
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

  function baselinkerDecodedExample(source) {
    var text = String(source || "").replace(/\\\r?\n\s*/g, "");

    try {
      text = JSON.stringify(JSON.parse(text), null, 2);
    } catch (_error) {
      text = text
        .replace(/\\n/g, "\n")
        .replace(/\\r/g, "\r")
        .replace(/\\t/g, "\t")
        .replace(/\\'/g, "'")
        .replace(/\\"/g, '"')
        .replace(/\\\\/g, "\\");
    }

    return text.trim();
  }

  function baselinkerMethodExample(methodName) {
    if (!methodName) return null;

    var pattern = new RegExp("examples\\[['\"]" + escapeRegex(methodName) + "['\"]\\]\\s*=\\s*'([\\s\\S]*?)';");
    var scripts = Array.prototype.slice.call(document.querySelectorAll("script"));

    for (var i = 0; i < scripts.length; i += 1) {
      var scriptText = scripts[i].textContent || "";
      var match = scriptText.match(pattern);
      if (match && match[1]) return baselinkerDecodedExample(match[1]);
    }

    return null;
  }

  function baselinkerDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)api\.baselinker\.com$/) && !/baselinker/i.test(signature)) return null;

    var methodName = queryParam("method");

    // For method pages, extract the visible DOM content (rendered by jQuery SPA)
    // which contains description, input/output parameters, and usage guidance
    var node = firstMatchingNode(["#main", ".main_text", "main"]);
    var result = docsContentForNode(metadata, node, {
      fallbackTitle: methodName || normalizeText((metadata.title || document.title).replace(/\s*-\s*baselinker\.com$/i, "")) || "API documentation",
      rewriteRoot: function(root) {
        // Remove method list navigation and UI chrome
        root.querySelectorAll("nav, aside, footer").forEach(function(el) { el.remove(); });
        removeNodesByText(root, "a, button, div, span", /^(method list|test your request|changelog|copy)$/i);
      }
    });

    // If DOM extraction returned very little content but we have the inline example,
    // build a fallback from the JSON example
    if (methodName && (!result || normalizeText(result.markdown || "").length < 200)) {
      var example = baselinkerMethodExample(methodName);
      if (example) {
        var markdown = [
          "# " + methodName,
          "Baselinker API request example for the `" + methodName + "` method.",
          "```json",
          example,
          "```"
        ].join("\n\n");

        return {
          title: methodName,
          byline: metadata.byline,
          excerpt: "Baselinker API request example for the " + methodName + " method.",
          siteName: metadata.siteName || location.hostname,
          publishedTime: metadata.publishedTime,
          html: "",
          markdown: markdown,
          textContent: normalizeText(markdown),
          readerMode: false,
          contentType: "article"
        };
      }
    }

    return result;
  }

  function rubyApiIndexContent(metadata, title) {
    var seen = {};
    var items = [];

    document.querySelectorAll("a[href*='/o/']").forEach(function(link) {
      if (items.length >= 12) return;

      var href = absoluteUrl(link.getAttribute("href"));
      var label = normalizeText(link.textContent);
      if (!href || !/\/\d+(?:\.\d+)?\/o\//.test(href) || !/^read more$/i.test(label) || seen[href]) return;

      var card = link.parentElement;
      while (card && card !== document.body) {
        var heading = normalizeText((card.querySelector("h2, h3") || {}).textContent || "");
        var description = firstRootText(card, ["p"]);
        if (heading && description) {
          seen[href] = true;
          items.push({ text: heading, url: href, detail: description });
          return;
        }
        card = card.parentElement;
      }
    });

    if (items.length < 3) return null;

    var markdown = ["# " + title, metadata.excerpt, listMarkdown(items)].filter(Boolean).join("\n\n");
    return {
      title: title,
      byline: metadata.byline,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "list"
    };
  }

  function rubyApiContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)rubyapi\.org$/) && !/ruby api/i.test(signature)) return null;

    var title = normalizeText((metadata.title || document.title).replace(/\s*\|\s*Ruby API.*$/i, "")) || "Ruby API";
    if (location.pathname === "/" || /^\/\d+(?:\.\d+)?\/?$/.test(location.pathname)) return rubyApiIndexContent(metadata, title);

    return docsContentBySelectors(metadata, ["main", ".ruby-documentation"], {
      titleSelectors: ["main h1", ".ruby-documentation h1"],
      fallbackTitle: title,
      rewriteRoot: function(root) {
        root.querySelectorAll("form, button").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "h2, h3, p, div, span", /^(type signatures|preview)$/i);
      }
    });
  }
