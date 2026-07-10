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

  function glossaryStructuredContent(metadata) {
    var title = firstText(["main h1", "article h1", "h1"]) || normalizeText((metadata && metadata.title) || document.title);
    var headword = firstText([".headword", "strong.headword", ".hword", "main h1", "article h1", "h1"]) || safeDecodeURI((location.pathname || "").split("/").filter(Boolean).pop() || "");
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

    function pushDefinition(items, text) {
      text = compactDefinition(text);
      if (!text || text.length < 12 || utilityHeadingText(text)) return;
      if (/dictionary definitions page includes all the possible meanings|how to pronounce|how to say|translation|numerology|citation|top lookups|examples? of .* in a sentence/i.test(text)) return;

      var key = glossaryDefinitionKey(text);
      if (!key || key.length < 10) {
        if (items.indexOf(text) === -1) items.push(text);
        return;
      }
      if (items.map(glossaryDefinitionKey).indexOf(key) === -1) items.push(text);
    }

    function cleanDefinitionListItem(node) {
      var clone = cleanClone(node);
      clone.querySelectorAll(".wikt-quote-container, .HQToggle, .nyms-toggle, .citation-whole, .use-with-mention, ul, dl, table, figure").forEach(function(child) {
        child.remove();
      });
      cleanupAgentRoot(clone);
      return normalizeText(clone.textContent || "").replace(/^[:;]\s*/, "");
    }

    function orderedSenseDefinitions() {
      var definitions = [];
      var headwordLines = Array.prototype.slice.call(document.querySelectorAll(".headword-line, p:has(.headword), p:has(strong.headword)"));

      headwordLines.some(function(line) {
        var node = line.parentElement;
        while (node && node.nextElementSibling) {
          node = node.nextElementSibling;
          if (/^(h2|h3|h4)$/i.test(node.tagName || "")) break;
          if ((node.tagName || "").toLowerCase() !== "ol") continue;

          Array.prototype.slice.call(node.children).forEach(function(item) {
            if ((item.tagName || "").toLowerCase() === "li") pushDefinition(definitions, cleanDefinitionListItem(item));
          });
          return definitions.length >= 2;
        }
        return false;
      });

      return definitions;
    }

    function dtTextDefinitions() {
      var definitions = [];
      document.querySelectorAll("#dictionary-entry-1 .dtText, .entry-word-section-container .dtText, .sense .dtText").forEach(function(node) {
        pushDefinition(definitions, normalizeText(node.textContent || "").replace(/^[:;]\s*/, ""));
      });
      return definitions;
    }

    function retainedGlossaryBodyMarkdown(leadMarkdown) {
      var leadText = normalizeText(leadMarkdown || "").toLowerCase();
      var combined = document.createElement("div");
      var combinedSources = [];
      document.querySelectorAll("[id*='dictionary-entry'], [class*='example'], [class*='etymolog'], [class*='first-known'], [class*='word-history']").forEach(function(node) {
        var text = normalizeText(node.textContent || "");
        if (text.length < 30) return;
        if (combinedSources.some(function(parent) { return parent.contains(node); })) return;
        combinedSources = combinedSources.filter(function(child) { return !node.contains(child); });
        combinedSources.push(node);
      });
      combinedSources.forEach(function(node) { combined.appendChild(node.cloneNode(true)); });
      var sources = [];
      [
        combined.childNodes.length ? combined : null,
        document.querySelector("main"),
        document.querySelector("#mw-content-text .mw-parser-output"),
        document.querySelector("#dictionary-entry-1"),
        document.querySelector("article"),
        document.querySelector("[role='main']"),
        document.body
      ].forEach(function(source) {
        if (source && sources.indexOf(source) === -1) sources.push(source);
      });

      return sources.reduce(function(best, source) {
        var root = cleanClone(source);
        root.querySelectorAll("script, style, noscript, svg, form, header, nav, footer, aside, .mw-editsection, .mw-jump-link, .toc, #toc, .catlinks, #catlinks, .printfooter, .noprint, .mw-indicators, .mw-hidden-catlinks, .mw-empty-elt, .mw-headline-anchor").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("section, div, aside, form, table, ul, ol, p, li, span").forEach(function(el) {
          if (glossaryNoiseNode(el)) el.remove();
        });
        cleanupAgentRoot(root);

        var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
        var bodyText = normalizeText(markdown).toLowerCase();
        if (!bodyText || bodyText.length < 80) return best;
        if (bodyText === leadText || leadText.indexOf(bodyText) >= 0) return best;
        if (!/(^|\n)#{1,6}\s*(?:examples?|etymolog(?:y|ies)|word history|first known use|translations?|quotations?|usage notes?|synonyms?|antonyms?|derived terms|related terms|pronunciation)\b/i.test(markdown)) return best;
        if (!best || bodyText.length > normalizeText(best).length) return markdown;
        return best;
      }, "");
    }

    document.querySelectorAll("p.desc").forEach(function(node) {
      var text = compactDefinition(node.textContent || "");
      if (!text || text.length < 12 || utilityHeadingText(text)) return;

      var termNode = node.parentElement && node.parentElement.querySelector("p.term");
      var term = normalizeText(termNode && termNode.textContent);
      if (term && text.toLowerCase().indexOf(term.toLowerCase()) === -1) text = term + ": " + text;
      if (pairedDefinitions.map(glossaryDefinitionKey).indexOf(glossaryDefinitionKey(text)) === -1) pairedDefinitions.push(text);
    });

    var partsOfSpeech = manyTexts([".fl", "[data-fl]", ".partOfSpeech", "[class*='part-of-speech']"]).filter(function(text) {
      return text && text.length <= 40 && !utilityHeadingText(text);
    });
    var pronunciations = manyTexts([".prs .pr", ".ipa", "[class*='ipa']", ".pron", "[class*='pron-us']", "[class*='pron-uk']"]).filter(function(text) {
      return text && text.length <= 120 && !audioFallbackText(text) && !utilityHeadingText(text) && !/how to pronounce|how to say|listen to the pronunciation/i.test(text);
    });
    var leadDefinitions = orderedSenseDefinitions().concat(dtTextDefinitions());
    var definitions = leadDefinitions.concat(pairedDefinitions).concat(manyTexts(["p.desc", ".dtText", ".sense .dtText", ".sense", ".def", ".definition", "[class*='definition']", "li[class*='meaning'] > span", "li[class*='definition'] > span", "li[class*='sense'] > span", "[class*='meaning']", "dd", "[itemprop='description']"]).map(compactDefinition)).filter(function(text) {
      return text && text.length >= 12 && text.length <= 320 && !utilityHeadingText(text) && !/dictionary definitions page includes all the possible meanings|how to pronounce|how to say|translation|numerology|citation|top lookups/i.test(text);
    }).filter(function(text, index, items) {
      var key = glossaryDefinitionKey(text);
      if (!key || key.length < 10) return items.indexOf(text) === index;
      return items.map(glossaryDefinitionKey).indexOf(key) === index;
    });

    if (!definitions.length && !pronunciations.length) return null;

    title = headword || title;
    var sections = ["# " + title];
    if (headword && title.toLowerCase().indexOf(headword.toLowerCase()) === -1) sections.push("## " + headword);
    if (partsOfSpeech.length) sections.push(partsOfSpeech.join(" | "));
    if (pronunciations.length) sections.push(pronunciations.slice(0, 4).join("\n"));
    definitions.slice(0, 6).forEach(function(text) {
      sections.push(text);
    });

    var leadMarkdown = cleanupMarkdownNoise(sections.filter(Boolean).join("\n\n"));
    var retainedMarkdown = retainedGlossaryBodyMarkdown(leadMarkdown);
    var markdown = cleanupMarkdownNoise([leadMarkdown, retainedMarkdown].filter(Boolean).join("\n\n"));
    var text = normalizeText(markdown);
    if (text.length < 40) return null;
    var article = document.createElement("article");
    var heading = document.createElement("h1");
    var list = document.createElement("ol");
    heading.textContent = title;
    article.appendChild(heading);
    definitions.slice(0, 6).forEach(function(definition) {
      var item = document.createElement("li");
      item.textContent = definition;
      list.appendChild(item);
    });
    article.appendChild(list);

    return {
      title: title || (metadata && metadata.title) || document.title,
      byline: null,
      excerpt: definitions[0] || text.slice(0, 280) || null,
      siteName: (metadata && metadata.siteName) || location.hostname,
      publishedTime: null,
      html: article.outerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
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
