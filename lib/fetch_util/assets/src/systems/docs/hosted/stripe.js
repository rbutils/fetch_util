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
