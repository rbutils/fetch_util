  function fallbackArticleExcerpt(root, text, metadata) {
    var renderedText = normalizeText(text || "");
    var repeatedHeadlineLead = fallbackRepeatedHeadlineExcerpt(root, renderedText, metadata);
    if (repeatedHeadlineLead) return repeatedHeadlineLead;
    function ownedParagraph(node) {
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
    }

    var paragraph = root && Array.prototype.find.call(root.querySelectorAll("p, [itemprop~='description']"), ownedParagraph);
    var excerpt = normalizeText((paragraph && paragraph.textContent) || renderedText);
    if (paragraph && Array.from(excerpt).length < 280 &&
        !paragraph.closest("[itemprop~='description'], [class*='summary' i], [class*='standfirst' i], [class*='excerpt' i]")) {
      var continuation = paragraph.nextElementSibling;
      if (continuation && continuation.matches("p") && ownedParagraph(continuation)) {
        excerpt = normalizeText(excerpt + " " + continuation.textContent);
      }
    }
    return Array.from(excerpt).slice(0, 280).join("") || null;
  }

  function fallbackRepeatedHeadlineExcerpt(root, renderedText, metadata) {
    if (!root || !root.matches || !root.matches("article") || !metadata || !metadata.siteName) return null;
    var headline = articleTitleFromOwnedExternalHeading(root.innerHTML, document.title, metadata.siteName);
    if (headline === normalizeText(document.title || "") || renderedText.indexOf(headline) !== 0) return null;

    var paragraphs = Array.prototype.slice.call(root.querySelectorAll("p"));
    if (paragraphs.length < 3 || normalizeText(paragraphs[0].textContent || "") !== headline) return null;
    var prose = paragraphs.slice(1).filter(function(paragraph) {
      return !paragraph.closest("aside, nav, footer, form, menu, [role='complementary']") &&
        !paragraph.querySelector("button, input, select, textarea") &&
        !fallbackExcerptChromeOwner(root, paragraph) && !articleIntroFurniture(paragraph, root);
    }).map(function(paragraph) { return normalizeText(paragraph.textContent || ""); }).filter(Boolean);
    if (prose.length < 2) return null;
    var lead = normalizeText(prose.join(" "));
    return Array.from(lead).length >= 80 ? Array.from(lead).slice(0, 280).join("") : null;
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
