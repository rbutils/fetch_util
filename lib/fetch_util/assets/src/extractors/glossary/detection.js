  function glossaryLikePage(metadata) {
    var title = normalizeText((metadata && metadata.title) || document.title).toLowerCase();
    var excerpt = normalizeText((metadata && metadata.excerpt) || "").toLowerCase();
    var path = (location.pathname || "").toLowerCase();
    var page = pageReadableText().slice(0, 2000).toLowerCase();
    var queryPage = !!queryParam("q");
    var metadataScore = definitionReferenceMetadataScore(metadata);

    return /definition of |what does .+ mean\??| pronunciation in english|dictionary|definitions for /.test(title) ||
      /\/(dictionary|definition|definitions|pronunciation)\//.test(path) ||
      /\bpart of speech\b|\bdefinition:\b|\bpronunciation\b/.test(page) ||
      (queryPage && /\b(dictionary|translation|translate|thesaurus|lexicon|s[łl]ownik|t[łl]umaczenie)\b/.test(title + " " + excerpt)) ||
      (metadataScore >= 4 && /\b(definition|definitions|meaning|pronunciation|part of speech|citation|reference)\b/.test(page));
  }

  function glossaryUtilityHeavy(text) {
    var hits = (normalizeText(text || "").match(/browse nearby words|cite this entry|more from merriam-webster|popular in grammar|popular in wordplay|top lookups|numerology|citation/ig) || []).length;
    return hits >= 2;
  }

  function scoreGlossaryNode(node) {
    if (!node) return -Infinity;

    var text = textLength(node);
    if (text < 60 || text > 14000) return -Infinity;

    var normalized = normalizeText(node.textContent || "");
    var hint = (((node.className || "") + " " + (node.id || "")).toLowerCase());
    var headings = node.querySelectorAll("h1, h2, h3").length;
    var definitionish = node.querySelectorAll("dd, dt, dl, [class*='definition'], [class*='sense'], [class*='pron'], [class*='entry'], [class*='meaning']").length;
    var definitionBlocks = node.querySelectorAll("dd, dt, p.desc, dl, .dtText, .sense, .def, .definition, [class*='definition'], [class*='meaning'], [itemprop='description']").length;
    var longDesc = Array.prototype.slice.call(node.querySelectorAll("p.desc, dd, .dtText, .definition, [itemprop='description']")).filter(function(item) {
      var itemText = normalizeText(item.textContent || "");
      return itemText.length >= 40 && itemText.length <= 520 && !glossaryNoiseNode(item);
    }).length;
    var senseNumbered = Array.prototype.slice.call(node.querySelectorAll("p, li, dd, div")).filter(function(item) {
      return /^\s*(?:\d+[.)]|[a-z][.)]|[ivx]+[.)])\s+\S/.test(item.textContent || "");
    }).length;
    var paragraphs = node.querySelectorAll("p, li").length;
    var links = node.querySelectorAll("a[href]").length;
    var linkPenalty = links * (definitionBlocks || longDesc ? 10 : 16);
    var bonus = 0;

    if (/(definition|dictionary|entry|meaning|sense|glossary|lexicon|pronunciation|ipa)/.test(hint)) bonus += 260;
    if (/(source|reference|citation|database)/.test(hint) && (definitionBlocks || longDesc)) bonus += 90;
    if (/\bpart of speech\b|\bdefinition:\b|\bpronunciation\b/.test(normalized.toLowerCase())) bonus += 220;
    if (definitionBlocks >= 2) bonus += 180;
    if (longDesc >= 2) bonus += 260;
    if (senseNumbered >= 2) bonus += 120;
    if (node.matches && node.matches("dl, [class*='definition'], [class*='sense'], [class*='entry'], [itemprop='description']")) bonus += 160;
    if (node.querySelector("h1")) bonus += 120;
    if (glossaryNoiseNode(node)) bonus -= 320;
    if (/\b(top lookups|word of the day|translation|numerology|citation|browse nearby words)\b/i.test(normalized)) bonus -= 180;
    if (/\b(browse nearby words|more from merriam-webster|popular in grammar|popular in wordplay|translation|numerology|citation|quiz)\b/i.test(normalized)) bonus -= 260;
    if (text > 3500) bonus -= 220;
    if (text > 7000) bonus -= 400;

    return text + (definitionish * 80) + (definitionBlocks * 95) + (longDesc * 160) + (paragraphs * 18) + (headings * 35) + bonus - linkPenalty;
  }

  function glossaryCandidateNodes() {
    var nodes = [];

    function push(node) {
      if (node && nodes.indexOf(node) === -1) nodes.push(node);
    }

    [
      "article",
      "main",
      "[role='main']",
      ".entry",
      ".entry-body",
      ".entry-body__el",
      ".di-body",
      ".pr.dictionary",
      ".dictionary",
      "#dictionary-entry-1",
      ".definition",
      ".definitions",
      ".sense",
      ".dtText",
      "section",
      "div",
      "td",
      "table"
    ].forEach(function(selector) {
      document.querySelectorAll(selector).forEach(push);
    });

    document.querySelectorAll("h1, .dtText, .sense, dd, dt, [class*='definition'], [class*='pron'], [itemprop='description']").forEach(function(node) {
      push(node);
      push(node.closest("article, main, [role='main'], section, div, td, table"));
    });

    document.querySelectorAll("section, div, td, table").forEach(function(node) {
      var text = normalizeText(node.textContent || "");
      if (text.length < 40 || text.length > 3200) return;
      if (/\bpart of speech\b|\bdefinition:\b|\bpronunciation\b/.test(text.toLowerCase())) push(node);
    });

    return nodes;
  }
