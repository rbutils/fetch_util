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

  function cleanGlossaryExcerpt(text) {
    return normalizeText(text || "")
      .replace(/\s*see (?:the )?full definition\b.*$/i, "")
      .replace(/\s*opens in new tab\.?$/i, "")
      .replace(/\s*[|:-]\s*(?:merriam-webster|definitions?\.net|dictionary(?:\.com)?|diki)\b.*$/i, "")
      .trim();
  }

  function glossaryMetadataContent(metadata) {
    var excerpt = cleanGlossaryExcerpt((metadata && metadata.excerpt) || "");
    if (!excerpt || excerpt.length < 16) return null;

    var title = firstText(["main h1", "article h1", "h1"]) || normalizeText((metadata && metadata.title) || document.title);
    return articleContentFromParts({
      title: title || (metadata && metadata.title) || document.title,
      description: excerpt,
      siteName: (metadata && metadata.siteName) || location.hostname
    });
  }

  function glossaryUtilityHeavy(text) {
    var hits = (normalizeText(text || "").match(/browse nearby words|cite this entry|more from merriam-webster|popular in grammar|popular in wordplay|top lookups|numerology|citation/ig) || []).length;
    return hits >= 2;
  }

  function glossaryDefinitionKey(text) {
    return normalizeText(text || "")
      .toLowerCase()
      .replace(/^[\s#>*-]*(?:\d+[.)]|[a-z][.)]|[ivx]+[.)])\s*/i, "")
      .replace(/^definition\s*[:.-]\s*/i, "")
      .replace(/^[^:]{1,40}:\s+/, "")
      .replace(/\b(?:source|references?|citation|cite this entry)\b.*$/i, "")
      .replace(/[^a-z0-9]+/g, " ")
      .trim()
      .slice(0, 240);
  }

  function glossaryNeedsMetadataFallback(text, metadata) {
    var excerpt = cleanGlossaryExcerpt((metadata && metadata.excerpt) || "").toLowerCase();
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return true;
    if (glossaryUtilityHeavy(normalized)) return true;
    if (!excerpt || excerpt.length < 18) return false;

    return normalized.indexOf(excerpt) === -1 && normalized.length < Math.max(260, excerpt.length * 3);
  }

  function glossaryNoiseNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var heading = normalizeText((node.querySelector("h2, h3, h4, strong") || {}).textContent || "");
    var text = normalizeText(node.textContent || "");
    var attrs = normalizeText([(node.id || ""), (node.className || "")].join(" ")).toLowerCase();

    if (audioFallbackText(text)) return true;
    if (utilityHeadingText(heading)) return true;
    if (/^(love words\? need even more definitions|top lookups|add to chrome|add to firefox)$/i.test(text)) return true;
    if (/^discuss these .+ definitions with the community/i.test(text)) return true;
    if (/subscribe for ad-free|word of the day|browse definitions\.net|popular in grammar|popular in wordplay/i.test(text)) return true;
    if (/(cookie|privacy|consent)/.test(attrs) && text.length < 2400) return true;

    return false;
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

  function pruneDuplicateGlossaryDefinitions(root) {
    var seen = {};

    root.querySelectorAll("p.desc, dd, .dtText, .sense, .def, .definition, [class*='definition'], [class*='meaning'], [itemprop='description']").forEach(function(node) {
      var text = normalizeText(node.textContent || "");
      var key = glossaryDefinitionKey(text);
      if (!key || key.length < 16) return;
      if (seen[key]) {
        node.remove();
        return;
      }
      seen[key] = true;
    });
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

  function glossaryStructuredContent(metadata) {
    var title = firstText(["main h1", "article h1", "h1"]) || normalizeText((metadata && metadata.title) || document.title);
    var headword = firstText(["main h1", "article h1", "h1"]);
    var pairedDefinitions = [];

    function compactDefinition(text) {
      text = normalizeText(text || "");
      if (!text) return null;
      if (text.length <= 320) return text;

      var sentences = text.match(/[^.!?]+[.!?]+/g) || [];
      var compact = "";
      for (var i = 0; i < sentences.length; i += 1) {
        var next = normalizeText((compact ? compact + " " : "") + sentences[i]);
        if (next.length > 220) break;
        compact = next;
        if (compact.length >= 90) break;
      }

      return compact || text.slice(0, 217) + "...";
    }

    document.querySelectorAll("p.desc").forEach(function(node) {
      var text = compactDefinition(node.textContent || "");
      if (!text || text.length < 12 || utilityHeadingText(text)) return;

      var termNode = node.parentElement && node.parentElement.querySelector("p.term");
      var term = normalizeText(termNode && termNode.textContent);
      if (term && text.toLowerCase().indexOf(term.toLowerCase()) === -1) text = term + ": " + text;
      if (pairedDefinitions.map(glossaryDefinitionKey).indexOf(glossaryDefinitionKey(text)) === -1) pairedDefinitions.push(text);
    });

    var partsOfSpeech = manyTexts([".fl", "[data-fl]", ".partOfSpeech", "[class*='part-of-speech']"], 4).filter(function(text) {
      return text && text.length <= 40 && !utilityHeadingText(text);
    });
    var pronunciations = manyTexts([".prs .pr", ".ipa", "[class*='ipa']", ".pron", "[class*='pron-us']", "[class*='pron-uk']"], 8).filter(function(text) {
      return text && text.length <= 120 && !audioFallbackText(text) && !utilityHeadingText(text) && !/how to pronounce|how to say|listen to the pronunciation/i.test(text);
    });
    var definitions = pairedDefinitions.concat(manyTexts(["p.desc", ".dtText", ".sense .dtText", ".sense", ".def", ".definition", "[class*='definition']", "li[class*='meaning'] > span", "li[class*='definition'] > span", "li[class*='sense'] > span", "[class*='meaning']", "dd", "[itemprop='description']"], 10).map(compactDefinition)).filter(function(text) {
      return text && text.length >= 12 && text.length <= 320 && !utilityHeadingText(text) && !/dictionary definitions page includes all the possible meanings|how to pronounce|how to say|translation|numerology|citation|top lookups/i.test(text);
    }).filter(function(text, index, items) {
      var key = glossaryDefinitionKey(text);
      if (!key || key.length < 10) return items.indexOf(text) === index;
      return items.map(glossaryDefinitionKey).indexOf(key) === index;
    });

    if (!definitions.length && !pronunciations.length) return null;

    var sections = ["# " + title];
    if (headword && title.toLowerCase().indexOf(headword.toLowerCase()) === -1) sections.push("## " + headword);
    if (partsOfSpeech.length) sections.push(partsOfSpeech.join(" | "));
    if (pronunciations.length) sections.push(pronunciations.slice(0, 4).join("\n"));
    definitions.slice(0, 6).forEach(function(text) {
      sections.push(text);
    });

    var markdown = cleanupMarkdownNoise(sections.filter(Boolean).join("\n\n"));
    var text = normalizeText(markdown);
    if (text.length < 40) return null;

    return {
      title: title || (metadata && metadata.title) || document.title,
      byline: null,
      excerpt: definitions[0] || text.slice(0, 280) || null,
      siteName: (metadata && metadata.siteName) || location.hostname,
      publishedTime: null,
      html: "",
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article"
    };
  }

  function glossaryContent(metadata) {
    if (!glossaryLikePage(metadata)) return null;

    var structured = glossaryStructuredContent(metadata);
    if (structured) return structured;
    var metadataFallback = glossaryMetadataContent(metadata);

    var best = glossaryCandidateNodes().reduce(function(current, node) {
      var score = scoreGlossaryNode(node);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    if (!best || best.score < 260) return metadataFallback;

    var root = cleanClone(best.node);
    root.querySelectorAll("section, div, aside, form, table, ul, ol, p, li, span").forEach(function(el) {
      if (glossaryNoiseNode(el)) el.remove();
    });
    pruneDuplicateGlossaryDefinitions(root);
    cleanupAgentRoot(root);

    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    var text = normalizeText(markdown);
    if (text.length < 40) return metadataFallback;

    var title = firstText(["h1"]) || normalizeText((metadata && metadata.title) || document.title);
    if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;
    markdown = cleanupMarkdownNoise(markdown);
    text = normalizeText(markdown);

    if (glossaryNeedsMetadataFallback(text, metadata) && metadataFallback) return metadataFallback;

    return {
      title: title || (metadata && metadata.title) || document.title,
      byline: null,
      excerpt: text.slice(0, 280) || null,
      siteName: (metadata && metadata.siteName) || location.hostname,
      publishedTime: null,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article"
    };
  }
