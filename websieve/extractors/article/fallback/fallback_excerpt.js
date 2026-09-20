  function fallbackArticleExcerpt(root, text) {
    var renderedText = normalizeText(text || "");
    var paragraph = root && Array.prototype.find.call(root.querySelectorAll("p, [itemprop~='description']"), function(node) {
      var value = normalizeText(node.textContent || "");
      if (Array.from(value).length < 80) return false;
      if (node.matches("[itemprop~='description']") && node.querySelector("p, [itemprop~='description']")) return false;
      if (node.closest("address, nav, footer, aside, form, menu, [role='banner'], [role='navigation'], [role='complementary'], [role='menu'], [role='toolbar'], [role='contentinfo'], [role='search']")) return false;
      if (node.closest("header") && !fallbackExplicitHeaderLead(node)) return false;
      if (node.closest("[itemprop~='author'], [itemprop~='creator']")) return false;
      if (articleIntroFurniture(node, root)) return false;
      if (node.querySelector("button, input, select, textarea")) return false;
      if (fallbackExcerptChromeOwner(root, node)) return false;
      return !renderedText || renderedText.indexOf(value) >= 0;
    });
    var excerpt = normalizeText((paragraph && paragraph.textContent) || renderedText);
    return Array.from(excerpt).slice(0, 280).join("") || null;
  }

  function fallbackExplicitHeaderLead(node) {
    var header = node.closest("header");
    if (!header || !header.closest("article, main, [role='main']")) return false;

    var current = node;
    while (current) {
      if (current === header) {
        if (!articleIntroClass(header) && !header.matches("[itemprop~='description']")) break;
        var substantial = Array.prototype.filter.call(header.querySelectorAll("p"), function(paragraph) {
          return Array.from(normalizeText(paragraph.textContent || "")).length >= 80;
        });
        return substantial.length === 1 && substantial[0] === node;
      }
      if (articleIntroClass(current) || current.matches("[itemprop~='description']")) return true;
      current = current.parentElement;
    }
    return false;
  }

  function fallbackExcerptChromeOwner(root, node) {
    var current = node;
    while (current && current.nodeType === 1) {
      if (current === root && current.matches("article, main, [role='main'], body")) break;
      var className = typeof current.className === "string" ? current.className : "";
      var hints = [current.id || "", className, current.getAttribute("aria-label") || "",
        current.getAttribute("data-component") || "", current.getAttribute("data-testid") || ""]
        .join(" ").replace(/([a-z\d])([A-Z])/g, "$1 $2");
      var tokens = hints.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
      var semanticContentOwner = current.matches("article, main, [role='main']");
      if (tokens.some(function(token) {
        var chrome = ["author", "byline", "credit", "caption", "comment", "comments", "related", "recommended", "recommendation", "recommendations", "share", "promo", "advertisement", "newsletter", "subscription", "paywall", "reporter", "contributor", "navigation", "breadcrumb", "footer", "header", "masthead", "branding", "sidebar", "menu", "toolbar", "search"].indexOf(token) >= 0;
        var consent = ["cookie", "consent", "privacy", "gdpr", "ccpa"].indexOf(token) >= 0;
        return chrome || (consent && !semanticContentOwner);
      })) return true;
      if (current.matches("[itemprop~='author'], [itemprop~='creator']")) return true;
      current = current.parentElement;
    }
    return false;
  }
