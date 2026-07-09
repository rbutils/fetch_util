  function primaryBodyContainerText(selectors) {
    var parts = [];
    selectors.forEach(function(selector) {
      Array.prototype.slice.call(document.querySelectorAll(selector)).forEach(function(node) {
        var text = normalizeText(node.textContent || "");
        if (text.length >= 80 && parts.indexOf(text) === -1) parts.push(text);
      });
    });
    return normalizeText(parts.join("\n\n"));
  }

  function missingPrimaryContent(metadata, content, markdown, body) {
    if (!content || content.contentType !== "article" || content.docsLike) return false;
    if (clearArticleStructure(content, markdown, body)) return false;

    var context = normalizeText([
      location.pathname || "",
      (content && content.title) || "",
      metadata && metadata.title || ""
    ].join(" ")).toLowerCase();
    var html = String((content && content.html) || "").toLowerCase();

    if (/\blyrics?\b/.test(context)) {
      var lyricsText = primaryBodyContainerText(["[data-lyrics-container]", ".lyrics", "[class*='Lyrics__Container']"]);
      if (lyricsText.length < 300) return false;
      if (/data-lyrics-container|lyrics__container|class=["'][^"']*\blyrics\b/i.test(content.html || "")) return false;
      if (/\[(?:verse|chorus|bridge|outro|intro|hook|refrain|pre-chorus|instrumental)\b/i.test(body)) return false;
      if (/\b(song bio|annotation|contributors?|written by|produced by)\b/i.test(body) || body.length < lyricsText.length * 0.75) return true;
    }

    if (/\bpoems?\b/.test(context)) {
      var poemText = primaryBodyContainerText(["[data-poem]", ".poem", "[class*='poem' i]"]);
      if (poemText.length >= 300 && !/data-poem|class=["'][^"']*poem/i.test(content.html || "") && body.length < poemText.length * 0.75) return true;
    }

    return false;
  }

  function clearArticleStructure(content, markdown, body) { if (!content || content.contentType !== "article" || content.docsLike || body.length < 100) return false; var html = String(content.html || ""); var context = normalizeText([content.title || "", body.slice(0, 1000)].join(" ")).toLowerCase(); if (/\blyrics?\b/.test(context) || /\bpoems?\b/.test(context)) return false; var paragraphCount = ((markdown || "").match(/\n\s*\n/g) || []).length; var headingCount = ((markdown || "").match(/^#{1,6}\s+/gm) || []).length; var sentenceCount = (body.match(/[.!?。！？؟।]+/g) || []).length; var pageLang = normalizeText((document.documentElement && document.documentElement.lang) || "").toLowerCase(); var compactLocalizedArticle = body.length < 1500 && ((pageLang && !/^en\b/.test(pageLang)) || (body.match(/[^\x00-\x7F]/g) || []).length > body.length * 0.3); if (hostMatches(/(^|\.)lenta\.ru$/) && /^\/news\/\d{4}\/\d{2}\/\d{2}\//i.test(location.pathname || "")) return (paragraphCount >= 1 || headingCount >= 1) && sentenceCount >= 2; if (compactLocalizedArticle && substantialArticleContent(content) && (paragraphCount >= 1 || headingCount >= 1 || sentenceCount >= 2)) return true; if (body.length >= 700) return false; if (!/<article\b/i.test(html) && !/<main\b/i.test(html)) return false; return (paragraphCount >= 1 || headingCount >= 1) && sentenceCount >= 2; }

  function detailRecordPath(path) {
    if (!path || /\/(?:search|browse|category|categories|tags?|topics?|collections?)\b/.test(path)) return false;

    return /\/(?:drugs?|compounds?|substances?|proteins?|genes?|genomes?|pathways?|assays?|bioassays?|datasets?|records?|entries?|items?|products?|publications?|papers?|articles?|cases?|opinions?|decisions?)\/[a-z0-9_.-]*\d[a-z0-9_.-]*(?:\/|$)/i.test(path);
  }

  function shortNavOnlyMarkdown(markdown) {
    var mdText = normalizeText(markdown || "");
    if (!mdText) return false;

    var linkCount = (mdText.match(/\[([^\]]*)\]\([^)]+\)/g) || []).length;
    var bulletLinkLines = (markdown || "").split(/\n+/).filter(function(line) {
      return /^\s*[-*]\s+\[[^\]]+\]\([^)]+\)\s*$/.test(line);
    }).length;
    var proseWords = mdText.replace(/\[([^\]]*)\]\([^)]+\)/g, "").split(/\s+/).filter(function(w) { return w.length >= 3; }).length;

    return linkCount >= 2 && bulletLinkLines >= 2 && proseWords < linkCount * 2;
  }
