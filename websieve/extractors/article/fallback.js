  function scoreNode(node) {
    if (!node || cookieChromeNode(node)) return -Infinity;
    if (!fallbackFocalArticleRoot(node) && commentOnlyRoot(node)) return -Infinity;

    if (node.matches("[id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [class*='privacy-center' i], [id*='privacy-center' i], [data-nosnippet='true']")) return -Infinity;

    var privacyTitle = node.querySelector("#ot-pc-title, #ot-pc-desc, [id^='ot-pc-' i], [class*='ot-pc' i], [class*='ot-accordion' i], [id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [id*='privacy' i], [class*='privacy' i], [id*='cookie' i], [class*='cookie' i], [class*='privacy-center' i], [id*='privacy-center' i], [data-nosnippet='true']");
    var privacyText = normalizeText((privacyTitle && privacyTitle.textContent) || node.textContent || "").slice(0, 500);
    if (privacyTitle && (cookieNoticeText(privacyText) || utilityHeadingText(privacyText))) return -Infinity;

    var normalizedText = normalizeText(node.textContent || "");
    var nonLatinArticleText = /[\u0370-\u03FF\u0400-\u04FF\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\u0900-\u097F\u0980-\u09FF\u0E00-\u0E7F\u3040-\u30FF\u3400-\u4DBF\u4E00-\u9FFF]/.test(normalizedText);
    var text = normalizedText.length;

    if (typeof window !== "undefined" && window.getComputedStyle) {
      try {
        var style = window.getComputedStyle(node);
        if (style && (style.display === "none" || style.visibility === "hidden")) return -Infinity;
      } catch (e) {}
    }

    var paragraphs = node.querySelectorAll("p").length;
    var headings = node.querySelectorAll("h1, h2, h3").length;
    var proseNodes = node.querySelectorAll("p, li, blockquote, figure, table").length;
    var minTextLength = nonLatinArticleText && (paragraphs >= 2 || headings >= 1 || proseNodes >= 3) ? 180 : 280;
    if (text < minTextLength) return -Infinity;
    var links = Array.prototype.reduce.call(node.querySelectorAll("a"), function(total, link) {
      return total + textLength(link);
    }, 0);
    var density = text > 0 ? links / text : 0;
    var utilityNodes = node.querySelectorAll("nav, aside, footer, [role='navigation'], [role='complementary'], [class*='comment' i], [id*='comment' i], [class*='related' i], [id*='related' i], [class*='recommend' i], [id*='recommend' i], [class*='newsletter' i], [id*='newsletter' i], [class*='subscribe' i], [id*='subscribe' i], [class*='share' i], [id*='share' i]").length;
    var hint = ((node.className || "") + " " + (node.id || "")).toLowerCase();
    var bonus = 0;
    var strongArticleStructure = text >= 500 && (paragraphs >= 2 || headings >= 4 || proseNodes >= 4);
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);
    var textToLinkRatio = text / Math.max(links, 1);
    var ratioBonus = Math.min(300, Math.round(textToLinkRatio / 4));
    var utilityPenalty = utilityNodes > proseNodes ? Math.min(900, (utilityNodes - proseNodes) * 90) : 0;
    var densityPenalty = Math.round(density * (proseNodes >= 4 ? 240 : 400));

    if (/(article|content|entry|main|post|story|body|definition|meaning|sense|glossary|lexicon|pronunciation|answer|articulo|artículo|noticia|conteudo|conteúdo|contenido|corpo|texto|berita|haber|nyheter|nieuws|aktualnosci|aktualności)/.test(hint)) bonus += 180;
    if (nonLatinArticleText && (paragraphs >= 2 || headings >= 1)) bonus += 140;
    if (/(comment|footer|nav|share|promo|related|sidebar|browse|translation|numerology|citation|quiz|cookie|privacy|subscription)/.test(hint)) bonus -= 220;
    if (!strongArticleStructure && promotionalRailNode(node, normalizedText, density)) bonus -= 4200;
    if (!strongArticleStructure && mixedArticleRailWrapper(node, normalizedText)) bonus -= 9000;
    if (!weatherPage && text < 1800 && weatherWidgetText(normalizedText)) return -Infinity;
    if (text < 1800 && legalFooterText(normalizedText) && (paragraphs < 4 || headings < 3)) return -Infinity;
    if (text < 2200 && /(discover more|newspapers|tourist destinations|travel guides?|travelogues)/i.test(normalizedText) && (paragraphs < 5 || headings < 4)) return -Infinity;

    return text + (paragraphs * 70) + (headings * 30) + bonus + ratioBonus - densityPenalty - utilityPenalty;
  }

  function fallbackContent() {
    if (commentOnlyRoot(document.body) && !fallbackFocalArticleRoot(document.body)) return nonArticleContent();
    var legalProvision = legalProvisionContent();
    if (legalProvision) return legalProvision;

    var selectors = genericArticleSelectors();
    var candidates = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        candidates.push(node);
      });
    });

    var best = candidates.reduce(function(current, node) {
      var scoringNode = cleanClone(node);
      cleanupGenericArticleRoot(scoringNode);
      var score = scoreNode(scoringNode);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    var node = best && best.score > -Infinity ? best.node : document.body;
    var clone = cleanClone(node);
    var comments = fallbackFocalArticleRoot(clone) ? fallbackCommentMarkup(document) : "";
    prepareFallbackInlineProse(clone);
    cleanupGenericArticleRoot(clone);
    prepareFallbackInlineProse(clone);
    cleanupFallbackArticleChrome(clone);
    if (comments) clone.insertAdjacentHTML("beforeend", comments);
    var text = normalizeText(clone.textContent);

    return {
      title: document.title,
      byline: null,
      excerpt: text.slice(0, 280) || null,
      siteName: location.hostname,
      publishedTime: null,
      html: clone.innerHTML,
      textContent: text,
      readerMode: false,
      contentType: "article"
    };
  }

  function fallbackFocalArticleRoot(root) {
    var heading = root && root.querySelector && root.querySelector("h1, h2, [itemprop='headline']");
    var title = normalizeText((heading && heading.textContent) || "");
    var body = root && root.querySelectorAll ? Array.prototype.filter.call(root.querySelectorAll("p, [itemprop='articleBody']"), function(node) {
      return !node.closest("#comments, .comments, .comment-list, [class*='comment' i], [id*='comment' i]");
    }).map(function(node) { return normalizeText(node.textContent); }).join(" ") : "";
    return !!title && body.length >= 40;
  }

  function commentOnlyRoot(root) {
    if (!root || !root.querySelector) return false;
    var comments = root.querySelectorAll("#comments, .comments, .comments-area, .comment-list, .comments-section, #disqus_thread, [class*='comment' i]");
    if (!comments.length) return false;
    var total = normalizeText(root.textContent || "").length;
    var commentText = Array.prototype.reduce.call(comments, function(length, node) {
      return Math.max(length, normalizeText(node.textContent || "").length);
    }, 0);
    return commentText > 0 && commentText >= total * 0.7;
  }

  function fallbackCommentMarkup(root) {
    var containers = [];
    root.querySelectorAll("#comments, .comments, .comments-area, .comment-list, .comments-section, #disqus_thread, [class*='comment' i]").forEach(function(node) {
      if (!node.querySelector("p, li, [class*='body' i]") || normalizeText(node.textContent || "").length < 40) return;
      if (!containers.some(function(parent) { return parent.contains(node); })) containers.push(node);
    });
    return containers.map(function(node) { return node.outerHTML; }).join("");
  }

  function prepareFallbackInlineProse(root) {
    root.querySelectorAll("p span, li span, blockquote span, p font, li font, blockquote font").forEach(function(node) {
      if (node.querySelector("p, li, blockquote, div, ul, ol, table, pre")) return;
      node.replaceWith.apply(node, Array.prototype.slice.call(node.childNodes));
    });
  }

  function cleanupFallbackArticleChrome(root) {
    root.querySelectorAll(".comment-thread, [class*='comment-thread' i], .widget, [class*='widget' i], .views-element-container, [class~='comment'], .date-header").forEach(function(node) {
      var text = normalizeText(node.textContent || "");
      if (!text || text.length < 100 || !node.querySelector("p, article, section, ul, ol, table")) node.remove();
    });
  }

  function nonArticleContent() {
    return {
      title: document.title,
      byline: null,
      excerpt: null,
      siteName: location.hostname,
      publishedTime: null,
      html: "",
      textContent: "",
      markdown: "",
      readerMode: false,
      contentType: "list",
      items: []
    };
  }

  function weatherWidgetText(text) {
    var normalized = normalizeText(text || "");
    if (!normalized) return false;
    if (!/(ve[ðd]ursp[áa]|weather forecast|forecast for the next|forecast for)/i.test(normalized)) return false;

    var weatherHits = normalized.match(/\b(ve[ðd]ursp[áa]|hiti|[úu]rkoma|vindur|frost|rigning|sk[ýy]ja[ðd]|temperature|precipitation|wind|rain|snow|storm)\b/ig) || [];
    return weatherHits.length >= 4;
  }

  function preferFallbackContent(primary, fallback) {
    if (!primary) return fallback;
    if (!fallback || !primary.readerMode) return primary;

    var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output");
    var primaryText = normalizeText(primary.markdown || primary.textContent || "");
    if (mediaWikiLike && primaryText.length >= 800) return primary;

    var fallbackText = normalizeText(fallback.markdown || fallback.textContent || "");
    var primaryRoot = document.createElement("div");
    var fallbackRoot = document.createElement("div");
    primaryRoot.innerHTML = primary.html || "";
    fallbackRoot.innerHTML = fallback.html || "";
    var primaryParagraphs = primaryRoot.querySelectorAll("p, li").length;
    var fallbackParagraphs = fallbackRoot.querySelectorAll("p, li").length;
    var fallbackLinkText = Array.prototype.reduce.call(fallbackRoot.querySelectorAll("a[href]"), function(total, link) {
      return total + textLength(link);
    }, 0);
    var fallbackLinkDensity = fallbackText.length > 0 ? fallbackLinkText / fallbackText.length : 0;
    var adLikePrimary = /\b(oglas|advertisement|sponsored|ad)\b/i.test(primaryText.slice(0, 160));
    var footerLikePrimary = legalFooterText(primaryText);
    var weatherLikePrimary = weatherWidgetText(primaryText);
    var weatherPage = /(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);

    if (!fallbackText) return primary;
    if (fallback.legalProvision) return fallback;
    if (primaryText.length < 4000 &&
        fallbackText.length >= Math.max(1800, primaryText.length * 3) &&
        fallbackParagraphs >= Math.max(8, primaryParagraphs + 5) &&
        fallbackLinkDensity < 0.28) {
      return fallback;
    }
    if (substantialArticleContent(primary)) return primary;

    if (weatherLikePrimary && !weatherPage && fallbackText.length >= Math.max(900, primaryText.length * 2)) {
      return fallback;
    }

    if (promotionalRailContent(primary) && substantialArticleContent(fallback) && fallbackText.length >= 1200 && fallbackLinkDensity < 0.25) {
      return fallback;
    }

    if (footerLikePrimary && fallbackText.length >= Math.max(1000, primaryText.length * 2)) {
      return fallback;
    }

    if (substantialArticleContent(fallback) &&
        (primaryText.length < 240 || adLikePrimary) &&
        fallbackText.length >= Math.max(600, primaryText.length * 3)) {
      return fallback;
    }

    return primary;
  }

  function promotionalRailNode(node, text, linkDensity) {
    var hint = ((node.className || "") + " " + (node.id || "")).toLowerCase();
    if (!/(sidebar|rail|aside|promo|cta|recent|popular|related)/.test(hint) && !/\b(recent posts?|popular posts?|latest posts?|related posts?|get started for free|start (?:your )?free trial|try .* for free)\b/i.test(text)) return false;
    if (node.querySelectorAll("p").length >= 8 && linkDensity < 0.18 && !/(sidebar|rail|aside)/.test(hint)) return false;
    return linkDensity >= 0.18 || node.querySelectorAll("a[href]").length >= 4;
  }

  function mixedArticleRailWrapper(node, text) {
    if (!/\b(recent posts?|popular posts?|latest posts?|related posts?|get started for free|start (?:your )?free trial|try .* for free)\b/i.test(text)) return false;
    if (node.matches && node.matches("article, [itemprop='articleBody']")) return false;

    return Array.prototype.some.call(node.querySelectorAll("article, [itemprop='articleBody'], [class*='article' i], [class*='content' i], [class*='post' i]"), function(child) {
      if (child === node || child.querySelectorAll("a[href]").length >= 4) return false;
      return textLength(child) >= 1200 && child.querySelectorAll("p").length >= 5;
    });
  }

  function promotionalRailContent(content) {
    if (!content || content.contentType !== "article") return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || content.markdown || "");
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;

    return promotionalRailNode(root, text, linkDensity);
  }
