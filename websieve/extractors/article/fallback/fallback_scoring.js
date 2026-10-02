  function scoreNode(node) {
    if (!node || cookieChromeNode(node)) return -Infinity;
    if (!fallbackFocalArticleRoot(node) && commentOnlyRoot(node)) return -Infinity;

    if (node.matches("[id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [class*='privacy-center' i], [id*='privacy-center' i]")) return -Infinity;

    var privacyTitle = node.querySelector("#ot-pc-title, #ot-pc-desc, [id^='ot-pc-' i], [class*='ot-pc' i], [class*='ot-accordion' i], [id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [id*='privacy' i], [class*='privacy' i], [id*='cookie' i], [class*='cookie' i], [class*='privacy-center' i], [id*='privacy-center' i]");
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
