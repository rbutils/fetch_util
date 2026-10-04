  function fallbackArticleExcerpt(root, text, metadata, completeParagraph, sourceOwnership, sourceClones) {
    var renderedText = normalizeText(text || "");
    var ownedSummary = fallbackSourceOwnedSummary(root, renderedText, sourceOwnership, sourceClones);
    if (ownedSummary) return ownedSummary;
    var repeatedHeadlineLead = fallbackRepeatedHeadlineExcerpt(root, renderedText, metadata, completeParagraph);
    if (repeatedHeadlineLead) return repeatedHeadlineLead;
    var selectedArticleLead = fallbackSelectedArticleLead(root, renderedText, sourceOwnership, sourceClones, metadata);
    if (selectedArticleLead) return selectedArticleLead;
    function ownedParagraph(node) {
      var value = normalizeText(node.textContent || "");
      var characters = Array.from(value).length;
      var minimum = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(value) ? 40 : 80;
      if (characters < minimum) return false;
      var headings = document.querySelectorAll("h1");
      if (headings.length === 1 && normalizeText(headings[0].textContent || "") === value) return false;
      if (node.matches("[itemprop~='description']") && node.querySelector("p, [itemprop~='description']")) return false;
      if (node.closest("address, nav, footer, aside, form, menu, time, [role='banner'], [role='navigation'], [role='complementary'], [role='menu'], [role='toolbar'], [role='contentinfo'], [role='search']") || sourceOwnedPublicationField(node)) return false;
      if (node.closest("header") && !fallbackExplicitHeaderLead(node)) return false;
      if (node.closest("[itemprop~='author'], [itemprop~='creator']")) return false;
      if (articleIntroFurniture(node, root)) return false;
      if (node.querySelector("button, input, select, textarea")) return false;
      if (fallbackExcerptChromeOwner(root, node)) return false;
      return !renderedText || renderedText.indexOf(value) >= 0;
    }

    var paragraph = root && Array.prototype.find.call(root.querySelectorAll("p, [itemprop~='description']"), ownedParagraph);
    var excerpt = normalizeText((paragraph && paragraph.textContent) || renderedText);
    if (completeParagraph && paragraph) {
      var continuation = paragraph.nextElementSibling;
      if (continuation && continuation.matches("p") && continuation.parentElement === paragraph.parentElement &&
          ownedParagraph(continuation)) {
        excerpt = sourceOwnedIntroParagraphText(paragraph, continuation);
      }
      return excerpt;
    }
    if (paragraph && Array.from(excerpt).length < 280 &&
        !paragraph.closest("[itemprop~='description'], [class*='summary' i], [class*='standfirst' i], [class*='excerpt' i]")) {
      var continuation = paragraph.nextElementSibling;
      if (continuation && continuation.matches("p") && ownedParagraph(continuation)) {
        excerpt = normalizeText(excerpt + " " + continuation.textContent);
      }
    }
    return Array.from(excerpt).slice(0, 280).join("") || null;
  }

  function fallbackSourceOwnedSummary(root, renderedText, sourceOwnership, sourceClones) {
    if (!root || !document.body || !renderedText || root.nodeType !== 1 || !sourceOwnership) return null;
    var proof = sourceOwnership.proof;
    if (["canonical-article-metadata", "same-owner-source-headline", "same-owner-source-headline-and-media"].indexOf(proof) === -1) return null;
    var owner = sourceOwnership.node;
    var headerRoot = sourceOwnership.ownerRoot || owner;
    var heading = sourceOwnership.heading;
    var sourceRoot = sourceOwnership.body && sourceOwnership.body.sourceNode || owner;
    if (!owner || !headerRoot || !heading || !sourceRoot || owner.nodeType !== 1 ||
        !owner.contains(heading) || !headerRoot.contains(heading) ||
        (sourceRoot !== owner && !owner.contains(sourceRoot))) return null;

    var ownerHeadings = Array.prototype.filter.call(headerRoot.querySelectorAll("h1, [itemprop~='headline' i]"), function(node) {
      return !elementVisuallyHidden(node);
    });
    if (ownerHeadings.length !== 1 || ownerHeadings[0] !== heading) return null;

    var summaries = Array.prototype.filter.call(sourceRoot.querySelectorAll(
      "[itemprop~='description' i], [class~='summary' i], [class~='standfirst' i], [class~='excerpt' i], [data-article-summary]"
    ), function(node) {
      var nestedArticle = node.closest("article");
      var ownerArticle = owner.matches("article") ? owner : owner.closest("article");
      return !elementSubtreeHidden(node) &&
        !node.querySelector("p, button, input, select, textarea") &&
        !node.closest("header, address, nav, footer, aside, blockquote, figure, figcaption, form, menu, " +
          "[role~='navigation' i], [role~='complementary' i], [role~='toolbar' i], " +
          "[itemprop~='author' i], [itemprop~='creator' i], [class*='byline' i], [class*='author' i], " +
          "[class*='related' i], [class*='recommend' i], [class*='sidebar' i], [class*='comment' i]") &&
        (!nestedArticle || nestedArticle === ownerArticle) &&
        !fallbackExcerptChromeOwner(sourceRoot, node);
    });
    if (summaries.length !== 1) return null;

    var sourceSummary = summaries[0];
    if (!(heading.compareDocumentPosition(sourceSummary) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
    var renderedSummary = sourceClones && sourceClones.get(sourceSummary);
    if (sourceClones) {
      if (!renderedSummary || (root !== renderedSummary && !root.contains(renderedSummary))) return null;
    } else if (root !== sourceSummary && !root.contains(sourceSummary)) {
      return null;
    }

    var summary = normalizeText(sourceSummary.textContent || "");
    if (!summary || summary === normalizeText(heading.textContent || "") ||
        normalizeText(renderedSummary ? renderedSummary.textContent || "" : sourceSummary.textContent || "") !== summary ||
        renderedText.indexOf(summary) === -1) return null;
    return summary;
  }

  function fallbackOwnedMediaExcerpt(renderedRoot, renderedText, ownership, sourceClones) {
    var summary = fallbackSourceOwnedSummary(renderedRoot, renderedText, ownership, sourceClones);
    if (summary) return summary;
    var root = ownership.media.closest("article") || ownership.node;
    var paragraphs = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
      var mapped = sourceClones && sourceClones.get(paragraph);
      return !elementSubtreeHidden(paragraph) && paragraph.closest("article") === root.closest("article") &&
        mapped && (renderedRoot === mapped || renderedRoot.contains(mapped)) &&
        !paragraph.closest("nav, aside, footer, form, menu, figure, figcaption, [role='complementary'], " +
          "[class*='related' i], [class*='recommend' i], [class*='sidebar' i]") &&
        !paragraph.querySelector("button, input, select, textarea") &&
        !sourceOwnedPublicationField(paragraph) && !fallbackExcerptChromeOwner(root, paragraph);
    });
    var lead = paragraphs[0];
    return lead ? normalizeText(lead.textContent || "") || null : null;
  }

  function sourceOwnedPublicationField(node) {
    if (!node || node.nodeType !== 1) return false;
    if (node.matches("time[datetime], [itemprop~='datePublished' i]")) return true;
    if (node.localName !== "p" || !Array.from(node.classList).some(function(token) {
      return /(?:^|[-_])(?:date|published|publication)(?:$|[-_])/i.test(token);
    })) return false;
    var value = normalizeText(node.textContent || "");
    var date = "(?:\\d{4}[-/]\\d{1,2}[-/]\\d{1,2}|\\d{1,2}[-/]\\d{1,2}[-/]\\d{2,4}|" +
      "[A-Za-z]{3,9}\\.? \\d{1,2},? \\d{4}|\\d{1,2} [A-Za-z]{3,9} \\d{4})";
    return new RegExp("^(?:(?:published|updated|posted|publication date|date)(?: on)?\\s*[:：-]?\\s*)?" +
      date + "(?:[,.;]\\s*(?:visit|read|click|follow)\\b[^.!?]*)?[.!?]?$", "i").test(value);
  }

  function sourceOwnedCompleteArticleLead(ownership) {
    if (!ownership || !ownership.ownerRoot || !ownership.body || !ownership.body.sourceNode ||
        !ownership.ownerRoot.contains(ownership.body.sourceNode)) return null;
    var root = ownership.body.primarySourceNode || ownership.body.sourceNode;
    var paragraphs = Array.from(root.querySelectorAll("p")).filter(function(paragraph) {
      var nestedArticle = paragraph.closest("article");
      var value = normalizeText(paragraph.textContent || "");
      return value && /\p{L}/u.test(value) && !elementSubtreeHidden(paragraph) &&
        (!nestedArticle || nestedArticle === root || !root.contains(nestedArticle)) &&
        !paragraph.closest("header, address, nav, footer, aside, form, figure, figcaption, menu, time, " +
          "[role~='navigation' i], [role~='complementary' i], " +
          "[itemprop~='author' i], [itemprop~='creator' i], " +
          "[class*='byline' i], [class*='author' i], [class*='credit' i], [class*='caption' i], " +
          "[class*='related' i], [class*='sidebar' i], [class*='recommend' i]") &&
        !paragraph.querySelector("button, input, select, textarea") &&
        !sourceOwnedPublicationField(paragraph) && !fallbackExcerptChromeOwner(root, paragraph) &&
        !articleIntroFurniture(paragraph, root);
    });
    if (!paragraphs.length) return null;
    var lead = normalizeText(paragraphs[0].textContent || "");
    if (lead === normalizeText(ownership.title || "")) {
      paragraphs.shift();
      if (!paragraphs.length) return null;
      lead = normalizeText(paragraphs[0].textContent || "");
    }
    var next = paragraphs[1];
    if (next && !fallbackExcerptChromeOwner(root, next) && !articleIntroFurniture(next, root)) {
      lead = sourceOwnedIntroParagraphText(paragraphs[0], next);
    }
    return lead;
  }

  function sourceOwnedIntroParagraphText(first, next) {
    var lead = normalizeText(first.textContent || "");
    var continuation = normalizeText(next.textContent || "");
    if (!lead || !continuation || !/\p{L}/u.test(continuation) ||
        first.parentElement !== next.parentElement || first.nextElementSibling !== next ||
        elementSubtreeHidden(first) || elementSubtreeHidden(next) ||
        next.closest("aside, nav, footer, form, figure, figcaption, [role='complementary']") ||
        fallbackExcerptChromeOwner(first.parentElement, next) || articleIntroFurniture(next, first.parentElement) ||
        next.querySelector("button, input, select, textarea") ||
        first.querySelector("a[href]") ||
        !/[\p{L}\p{N}][.!?。！？]["'”’]?$/u.test(lead) ||
        (lead.match(/[.!?。！？]/gu) || []).length !== 1) return lead;
    var cjk = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u;
    return cjk.test(lead) === cjk.test(continuation) ? normalizeText(lead + " " + continuation) : lead;
  }

  function sourceOwnedArticleHeaderLead(ownership) {
    var headers = sourceOwnedArticleHeaderNodes(ownership.headerContext);
    if (!headers.length && ownership.ownerRoot && ownership.heading &&
        ownership.ownerRoot.contains(ownership.heading)) {
      headers = Array.from(ownership.ownerRoot.querySelectorAll("header")).filter(function(header) {
        return header.contains(ownership.heading) && !sourceOwnershipInChrome(header);
      });
    }
    var leads = headers.flatMap(function(header) {
      return Array.from(header.querySelectorAll("p")).filter(function(paragraph) {
        return !elementSubtreeHidden(paragraph) && fallbackExplicitHeaderLead(paragraph) &&
          !fallbackExcerptChromeOwner(header, paragraph) &&
          !paragraph.closest("aside, nav, footer, form, figure, figcaption, [role='complementary']") &&
          !paragraph.querySelector("aside, nav, footer, form, figure, figcaption, article, button, input, select, textarea") &&
          paragraph.closest("article") === ownership.heading.closest("article");
      });
    });
    if (leads.length !== 1) return null;
    var visible = visibilityPrunedClone(leads[0], document);
    return visible ? normalizeText(visible.textContent || "") || null : null;
  }

  function fallbackRepeatedHeadlineExcerpt(root, renderedText, metadata, completeParagraph) {
    if (!root || !root.matches || !root.matches("article") || !metadata || !metadata.siteName) return null;
    var headline = articleTitleFromOwnedExternalHeading(root.innerHTML, document.title, metadata.siteName);
    if (headline === normalizeText(document.title || "") || renderedText.indexOf(headline) !== 0) return null;

    var paragraphs = Array.prototype.slice.call(root.querySelectorAll("p"));
    if (paragraphs.length < 3 || normalizeText(paragraphs[0].textContent || "") !== headline) return null;
    var prose = paragraphs.slice(1).filter(function(paragraph) {
      return !paragraph.closest("aside, nav, footer, form, menu, time, [role='complementary']") &&
        !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "") &&
        !paragraph.querySelector("button, input, select, textarea") &&
        !sourceOwnedPublicationField(paragraph) && !fallbackExcerptChromeOwner(root, paragraph) &&
        !articleIntroFurniture(paragraph, root);
    });
    if (prose.length < 2) return null;
    if (completeParagraph) {
      var first = prose.find(function(paragraph) {
        var value = normalizeText(paragraph.textContent || "");
        var minimum = /[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(value) ? 40 : 80;
        return Array.from(value).length >= minimum;
      });
      var firstIndex = prose.indexOf(first);
      var next = prose[firstIndex + 1];
      return first && next ? sourceOwnedIntroParagraphText(first, next) :
        first && normalizeText(first.textContent || "") || null;
    }
    var lead = normalizeText(prose.map(function(paragraph) { return paragraph.textContent || ""; }).join(" "));
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
      var hints = [current.id || "", className, current.getAttribute("role") || "", current.getAttribute("aria-label") || "",
        current.getAttribute("data-component") || "", current.getAttribute("data-testid") || ""]
        .join(" ").replace(/([a-z\d])([A-Z])/g, "$1 $2");
      var tokens = hints.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
      var semanticContentOwner = current.matches("article, main, [role='main']");
      if (tokens.some(function(token) {
        var chrome = ["author", "byline", "credit", "caption", "comment", "comments", "related", "recommended", "recommendation", "recommendations", "share", "promo", "advertisement", "newsletter", "subscription", "paywall", "reporter", "contributor", "navigation", "breadcrumb", "footer", "header", "masthead", "branding", "sidebar", "menu", "toolbar", "search"].indexOf(token) >= 0;
        var consent = ["cookie", "consent", "privacy", "gdpr", "ccpa"].indexOf(token) >= 0;
        var ownedMixedSidebarBody = token === "sidebar" &&
          typeof sourceOwnedMixedSidebarLayoutBody === "function" && sourceOwnedMixedSidebarLayoutBody(node, current);
        return (chrome && !ownedMixedSidebarBody) || (consent && !semanticContentOwner);
      })) return true;
      if (current.matches("[itemprop~='author'], [itemprop~='creator']")) return true;
      current = current.parentElement;
    }
    return false;
  }
