  function consentWallDominates(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return false;

    var cookiePattern = consentKeywordPattern("i");
    if (!cookiePattern.test(normalized)) return false;

    if (consentKeywordLeadPattern("i").test(normalized)) return true;

    var hits = normalized.match(consentKeywordPattern("gi")) || [];
    if (normalized.length < 5000 && hits.length >= 3) return true;
    // For longer text, check if consent keywords dominate: >= 0.4 hits per 500 chars
    if (hits.length >= 8 && (hits.length / (normalized.length / 500)) >= 0.4) return true;
    return false;
  }

  function shortConsentPrivacyFragment(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized || normalized.length > 220) return false;

    return /^(?:do not sell(?: or share)? my personal information|do not sell(?: or share)?|privacy policy|cookie policy|cookies? policy|terms of (?:service|use)|manage (?:privacy|cookie|consent) preferences|privacy choices|your privacy choices)$/i.test(normalized) ||
      /(?:do not sell(?: or share)? my personal information|privacy policy|cookie policy|terms of (?:service|use)|privacy choices|your privacy choices)/i.test(normalized);
  }

  function subscriptionWallDominates(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return false;

    var pattern = /subscribe to continue|subscription required|sign in to continue reading|log in to continue reading|subscriber-only|purchase short-term access|institutional access|access through your institution|read with a subscription/g;
    if (pattern.test(normalized.slice(0, 600))) return true;

    var hits = normalized.match(pattern) || [];
    return normalized.length < 3000 && hits.length >= 1;
  }

  function visibleLocalizedSubscriptionOffer() {
    return Array.from(document.querySelectorAll("a, button")).some(function(action) {
      if (elementSubtreeHidden(action) || action.closest("aside, nav, footer, blockquote, q, form")) return false;
      var offer = action.closest("div, section");
      var owner = offer && offer.closest("main, article, [role='main']");
      if (!offer || !owner || elementSubtreeHidden(offer) ||
          !/^wybierz\s+prenumeratę(?:\s|[,!.?]|$)/iu.test(normalizeText(offer.textContent))) return false;
      var headings = Array.from(owner.querySelectorAll("h1")).filter(function(heading) {
        return !elementSubtreeHidden(heading) && !sourceOwnershipInChrome(heading);
      });
      if (headings.length !== 1) return false;
      return Array.from(owner.querySelectorAll("[class*='fadeout' i], [class*='restricted' i], [class*='locked' i]")).some(function(boundary) {
        var restricted = Array.from(boundary.classList).some(function(token) {
          return /(?:^|[-_])(?:fadeout|restricted|locked)(?:$|[-_])/i.test(token);
        });
        return restricted && !elementSubtreeHidden(boundary) && !sourceOwnershipInChrome(boundary) &&
          !boundary.closest("aside, nav, footer, blockquote, q, form") &&
          Array.from(boundary.querySelectorAll("p")).some(function(paragraph) {
            return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent);
          }) && (boundary.compareDocumentPosition(offer) & Node.DOCUMENT_POSITION_FOLLOWING);
      });
    });
  }

  // Detect structured data paywall signals (isAccessibleForFree, content_tier meta)
  function paywallSignals() {
    // Check structured data: isAccessibleForFree
    var article = structuredDataNode(["NewsArticle", "Article", "BlogPosting", "WebPage", "LiveBlogPosting", "ReportageNewsArticle"]);
    var sdPaywall = article && (article.isAccessibleForFree === false || article.isAccessibleForFree === "False" || article.isAccessibleForFree === "false");

    // Check meta tags: article:content_tier
    var contentTier = metadataValue("article:content_tier", "property") || metadataValue("article:content_tier", "name");
    var metaPaywall = contentTier && /^(locked|metered|premium)$/i.test(normalizeText(contentTier));

    // Check common paywall DOM indicators
    var domPaywall = visibleLocalizedSubscriptionOffer() || !!document.querySelector(
      "[data-piano-offer], [data-paywall], [class*='paywall' i], [id*='paywall' i], " +
      "[class*='subscribe-wall' i], [class*='premium-wall' i], [class*='piano-offer' i], " +
      "[data-testid*='paywall' i], [class*='metered' i][class*='banner' i]"
    );

    // Detect paywall text patterns in body
    var bodySnippet = normalizeText((document.body && document.body.innerText) || "").slice(0, 6000).toLowerCase();
    var textPaywall = /(for abonnenter|unlock full access|contenu réservé aux abonnés|solo para suscriptores|nur für abonnenten|alleen voor abonnees|solo per abbonati|dostępne dla subskrybentów|только для подписчиков|лише для передплатників|přístupné pouze pro předplatitele|csak előfizetőknek|exklusivt för prenumeranter|kun for abonnenter|vain tilaajille|tik prenumeratoriams|tikai abonentiem|nur für abonnent|nur für abonnenten|contenido exclusivo para suscriptores|réservé aux abonnés|subscriber exclusive|subscribers only|premium content|members only|členský obsah|premium-inhalt)/.test(bodySnippet);

    if (!sdPaywall && !metaPaywall && !domPaywall && !textPaywall) return null;

    return {
      source: sdPaywall ? "structured_data" : metaPaywall ? "meta_tag" : domPaywall ? "dom_element" : "text_pattern",
      contentTier: contentTier ? normalizeText(contentTier).toLowerCase() : (sdPaywall ? "locked" : null)
    };
  }

  function visibleDeclaredPaidBodyRetained(content, metadata, paywall) {
    if (!content || content.contentType !== "article" || !content.html || !metadata ||
        !paywall || paywall.source !== "structured_data" || visibleLocalizedSubscriptionOffer()) return false;
    var declarations = structuredDataNodes().filter(function(node) {
      return nodeTypes(node).some(function(type) {
        return /^(?:Article|NewsArticle|ReportageNewsArticle|AnalysisNewsArticle|OpinionNewsArticle)$/.test(type);
      });
    });
    if (declarations.length !== 1) return false;
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
      return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node);
    });
    if (headings.length !== 1) return false;
    var heading = headings[0];
    var headline = normalizeText(heading.textContent);
    if (headline !== normalizeText(metadata.title) ||
        (declarations[0].headline && headline !== normalizeText(declarations[0].headline))) return false;
    var owner = heading.closest("article, main, [role='main']");
    if (!owner || elementSubtreeHidden(owner)) return false;
    var bodies = Array.from(owner.querySelectorAll("[itemprop='articleBody'], [data-article-body], [data-section='articleBody']")).filter(function(node) {
      return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node);
    });
    if (bodies.length > 1) return false;
    var body = bodies[0] || owner;
    var paragraphs = Array.from(body.querySelectorAll("p")).filter(function(node) {
      return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) &&
        !node.closest("header, blockquote, pre, table") && normalizeText(node.textContent).length >= 80;
    });
    if (paragraphs.length < 3 || paragraphs.map(function(node) { return normalizeText(node.textContent); }).join(" ").length < 1200) return false;
    var continuation = /subscribe to continue|subscription required|sign in to continue reading|log in to continue reading|unlock full access|para seguir leyendo|contin[uú]a leyendo|lee este art[ií]culo completo|solo para suscriptores|contenido exclusivo para suscriptores/i;
    var boundaries = Array.from(owner.querySelectorAll("[data-paywall], [class*='paywall' i], [id*='paywall' i], [class*='subscribe-wall' i], [class*='premium-wall' i], [data-piano-offer]"));
    if (boundaries.some(function(node) {
      if (elementSubtreeHidden(node) || node.closest("blockquote, q, pre, code, aside, nav, footer")) return false;
      return continuation.test(normalizeText(node.textContent)) ||
        !(node.compareDocumentPosition(paragraphs[0]) & Node.DOCUMENT_POSITION_FOLLOWING);
    })) return false;
    if (Array.from(body.querySelectorAll("p, div, section")).some(function(node) {
      return !elementSubtreeHidden(node) && !node.closest("blockquote, q, pre, code, aside, nav, footer") &&
        !node.children.length && continuation.test(normalizeText(node.textContent));
    })) return false;

    var selected = document.createElement("div");
    selected.innerHTML = content.html;
    var declaredBody = declarations[0].articleBody;
    if (declaredBody != null && (typeof declaredBody !== "string" ||
        normalizeText(selected.textContent).indexOf(normalizeText(declaredBody)) === -1)) return false;
    var units = "p, blockquote, pre, table, ul, ol, figure, h2, h3, h4, h5, h6, img, picture, video, audio, iframe, object, embed";
    var source = document.createElement("div");
    Array.from(body.querySelectorAll(units)).forEach(function(node) {
      if (elementSubtreeHidden(node) || sourceOwnershipInChrome(node) || node.closest("header")) return;
      var parentUnit = node.parentElement.closest(units);
      if (parentUnit && body.contains(parentUnit)) return;
      source.appendChild(visibilityPrunedClone(node, document));
    });
    return articleMaterialPreserved(source, selected);
  }

  function visiblePublicArticleBodyRetained(content, paywall) {
    if (!content || content.contentType !== "article" || !paywall || paywall.contentTier !== "premium" || !document.body) return false;
    if (subscriptionWallDominates(document.body.innerText || "")) return false;

    var gates = document.querySelectorAll("[data-paywall], [class*='paywall' i], [id*='paywall' i], [class*='subscribe-wall' i], [class*='premium-wall' i], [data-piano-offer]");
    if (Array.prototype.some.call(gates, function(node) { return !elementSubtreeHidden(node); })) return false;

    var articles = Array.prototype.filter.call(document.querySelectorAll("main article, [role='main'] article"), function(node) {
      return !elementSubtreeHidden(node) && !node.closest("aside, nav, footer, header");
    });
    if (articles.length !== 1) return false;
    if (/\b(?:subscribers? only|members? only|subscription required|premium subscribers?)\b/i.test(articles[0].innerText || "")) return false;

    var body = articles[0].querySelector("[itemprop='articleBody'], [data-article-body]") || articles[0];
    var paragraphs = Array.prototype.map.call(body.querySelectorAll("p"), function(node) {
      if (elementSubtreeHidden(node) || node.closest("aside, nav, footer, header, [class*='related' i]")) return "";
      return normalizeText(node.textContent || "");
    }).filter(function(text) { return text.length >= 40; });
    if (paragraphs.length < 3 || paragraphs.join(" ").length < 300) return false;

    var selected = document.createElement("div");
    selected.innerHTML = content.html || "";
    var extractedText = normalizeText(selected.textContent || content.textContent || "");
    return paragraphs.every(function(text) { return extractedText.indexOf(text) !== -1; });
  }
