  function readabilityExcerptIsVisibleLead(article, excerpt) {
    if (!article || !article.content) return false;

    var template = document.createElement("template");
    template.innerHTML = article.content;
    return Array.from(template.content.querySelectorAll("p")).some(function(paragraph) {
      if (normalizeText(paragraph.textContent || "") !== excerpt) return false;

      var range = document.createRange();
      range.setStart(template.content, 0);
      range.setEndBefore(paragraph);
      var prefix = normalizeText(range.toString());
      return Array.from(prefix).length < 40 && !/\p{Sentence_Terminal}/u.test(prefix);
    });
  }

  function readabilityExcerptUnits(text) {
    var value = normalizeText(text || "");
    if (typeof Intl === "undefined" || !Intl.Segmenter) return null;
    var segmenter = new Intl.Segmenter(undefined, {granularity: "grapheme"});
    return Array.from(segmenter.segment(value), function(part) { return part.segment; });
  }

  function readabilityExcerptLength(text) {
    var value = normalizeText(text || "");
    var characters = readabilityExcerptUnits(value);
    return characters ? characters.length : Array.from(value).length;
  }

  function readabilityExcerptPrefix(text) {
    var value = normalizeText(text || "");
    var characters = readabilityExcerptUnits(value);
    if (!characters) return Array.from(value).length <= 280 ? value : null;
    if (characters.length <= 280) return characters.join("");

    var prefix = characters.slice(0, 280).join("");
    var next = characters[280] || "";
    if (/[\p{L}\p{N}]$/u.test(prefix) && /^[\p{L}\p{N}]/u.test(next)) {
      if (!/\s+\S+$/u.test(prefix)) return null;
      prefix = prefix.replace(/\s+\S+$/u, "");
    }
    var sentencePrefix = "";
    var sentenceEnd = /\p{Sentence_Terminal}(?:["'’”)\]]*)/gu;
    var match;
    while ((match = sentenceEnd.exec(prefix))) {
      var candidate = prefix.slice(0, match.index + match[0].length);
      if (readabilityExcerptLength(candidate) >= 40) sentencePrefix = candidate;
    }
    return sentencePrefix ? normalizeText(sentencePrefix) : null;
  }

  function readabilityExcerptNode(node) {
    if (!node) return false;
    var current = node;
    while (current && current.nodeType === 1) {
      if (current.isConnected) {
        var computed = window.getComputedStyle(current);
        if (computed.display === "none" || computed.visibility === "hidden" || parseFloat(computed.opacity || "1") === 0) return false;
      }
      if (current.matches("nav, aside, footer, form, figure, figcaption, header, dialog, [role='dialog'], [role='alertdialog'], [role='complementary']")) return false;
      if (current.hidden || current.hasAttribute("inert") || (current.getAttribute("aria-hidden") || "").toLowerCase() === "true") return false;
      var style = (current.getAttribute("style") || "").replace(/\s+/g, "").toLowerCase();
      if (/(?:^|;)(?:display:none|visibility:hidden|opacity:0(?:\.0+)?)(?:;|$)/.test(style)) return false;
      var signal = ["id", "class", "role", "aria-label", "data-section", "data-component", "data-testid", "data-region", "data-type"]
        .map(function(name) { return current.getAttribute(name) || ""; }).join(" ")
        .replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[^A-Za-z0-9]+/g, " ").toLowerCase();
      if (/\b(?:caption|category|taxonomy|tags?|promo|related|recommend(?:ed|ation|ations)?|share|widgets?|global summary|sitewide summary|site summary)\b/.test(signal)) return false;
      current = current.parentElement;
    }
    return true;
  }

  function readabilitySummarySelector() {
    return "[data-section*='summary' i], [class*='page-summary' i], [class*='article-summary' i], [class~='summary'], [class*='key-points' i]";
  }

  function readabilityStructuredExcerptOwner(root) {
    var documentKeys = pageStructuredDataDocumentKeys();
    var articleTypes = ["article", "newsarticle", "reportagenewsarticle", "analysisnewsarticle", "opinionnewsarticle"];
    var records = structuredDataNodes().filter(function(record) {
      if (!nodeTypes(record).some(function(type) {
        return articleTypes.indexOf(String(type).toLowerCase()) !== -1;
      })) return false;
      return detailArticleRecordUrls(record).some(function(url) {
        var key = structuredDataDocumentKey(url);
        return key && documentKeys.indexOf(key) !== -1;
      });
    });
    if (records.length !== 1) return null;
    var title = normalizeText(records[0].headline || records[0].name || "");
    if (!title) return null;

    var headings = Array.prototype.filter.call(root.querySelectorAll("h1, [itemprop='headline']"), function(heading) {
      return normalizeText(heading.textContent || "") === title;
    });
    if (headings.length !== 1) return null;

    var heading = headings[0];
    var owner = heading.closest("article, [itemprop~='articleBody'], [class~='article'], [class~='story'], [class~='post']");
    if (!owner) return null;
    var paragraphs = Array.prototype.filter.call(owner.querySelectorAll("p"), function(paragraph) {
      return readabilityExcerptLength(paragraph.textContent || "") >= 80;
    });
    return paragraphs.length >= 2 ? {heading: heading, owner: owner} : null;
  }

  function readabilityExcerptOwner(node, structuredOwner) {
    if (!node || !node.closest) return false;
    if (structuredOwner && structuredOwner.owner.contains(node) &&
        (structuredOwner.heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING)) return true;
    if (node.closest("article")) return true;
    var main = node.closest("main, [role='main']");
    return !!main && !main.querySelector("article");
  }

  function readabilityBodyExcerptNode(node, structuredOwner) {
    if (!node || !node.matches || !node.matches("p")) return false;
    if (structuredOwner && structuredOwner.owner.contains(node)) {
      var structuredCurrent = node.parentElement;
      if (structuredCurrent === structuredOwner.owner) return true;
      while (structuredCurrent && structuredCurrent !== structuredOwner.owner) {
        var structuredSignal = ((structuredCurrent.id || "") + " " + (structuredCurrent.className || ""))
          .replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[^A-Za-z0-9]+/g, " ").toLowerCase();
        if (/\b(?:article body|article content|story body|entry content|post content|rich text|prose)\b/.test(structuredSignal)) return true;
        structuredCurrent = structuredCurrent.parentElement;
      }
      return false;
    }
    var owner = node.closest("article, main, [role='main']");
    if (!owner) return false;
    var current = node.parentElement;
    while (current && current !== owner) {
      if (current.matches("section")) return true;
      var signal = ((current.id || "") + " " + (current.className || ""))
        .replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[^A-Za-z0-9]+/g, " ").toLowerCase();
      if (!/\b(?:article body|article content|story body|entry content|post content|rich text|prose)\b/.test(signal)) return false;
      current = current.parentElement;
    }
    return current === owner;
  }

  function markReadabilityExcerptSources(root) {
    var values = new Uint32Array(4);
    crypto.getRandomValues(values);
    var marker = Array.from(values).map(function(value) {
      return value.toString(16).padStart(8, "0");
    }).join("");
    var structuredOwner = readabilityStructuredExcerptOwner(root);
    var owned = Array.prototype.filter.call(root.querySelectorAll("p, li"), function(node) {
      return readabilityExcerptOwner(node, structuredOwner) && readabilityExcerptNode(node);
    });
    owned.forEach(function(node) {
      node.setAttribute("data-fetchutil-excerpt-source", marker);
      if (readabilityBodyExcerptNode(node, structuredOwner)) node.setAttribute("data-fetchutil-excerpt-body", marker);
    });
    var summaryIndex = 0;
    root.querySelectorAll(readabilitySummarySelector()).forEach(function(container) {
      if (!readabilityExcerptNode(container)) return;
      var parts = [];
      if (container.matches("p, li")) parts.push(container);
      parts = parts.concat(Array.prototype.slice.call(container.querySelectorAll("p, li")));
      parts = parts.filter(function(node) {
        return node.getAttribute("data-fetchutil-excerpt-source") === marker;
      });
      if (!parts.length) return;
      var group = marker + ":" + summaryIndex;
      summaryIndex += 1;
      parts.forEach(function(node) { node.setAttribute("data-fetchutil-excerpt-summary", group); });
    });
    return marker;
  }

  function readabilityArticleTemplate(article) {
    if (!article || !article.content) return null;
    var template = document.createElement("template");
    template.innerHTML = article.content;
    return template;
  }

  function readabilitySummaryExcerpt(template, shortExcerpt, marker) {
    var groups = new Map();
    template.content.querySelectorAll("[data-fetchutil-excerpt-summary]").forEach(function(node) {
      var group = node.getAttribute("data-fetchutil-excerpt-summary") || "";
      if (group.indexOf(marker + ":") !== 0) return;
      if (!groups.has(group)) groups.set(group, []);
      var value = normalizeText(node.textContent || "");
      if (readabilityExcerptLength(value) >= 20) groups.get(group).push(value);
    });
    var result = null;
    groups.forEach(function(parts) {
      if (result) return;
      var text = normalizeText(parts.join(" "));
      if (text !== shortExcerpt && readabilityExcerptLength(text) >= 80) result = readabilityExcerptPrefix(text);
    });
    return result;
  }

  function readabilityBodyExcerpt(template, shortExcerpt, marker) {
    var paragraph = Array.prototype.find.call(template.content.querySelectorAll("p"), function(node) {
      var value = normalizeText(node.textContent || "");
      return node.getAttribute("data-fetchutil-excerpt-body") === marker &&
        value !== shortExcerpt && readabilityExcerptLength(value) >= 80;
    });
    return paragraph ? readabilityExcerptPrefix(paragraph.textContent || "") : null;
  }

  function readabilityMetadataExcerptOwned(node, excerpt) {
    var value = normalizeText((node && node.textContent) || "");
    if (value === excerpt) return true;
    if (!value.startsWith(excerpt) || value.length === excerpt.length) return false;
    return /\p{Sentence_Terminal}(?:["'’”)\]]*)$/u.test(excerpt) && /^\s/u.test(value.slice(excerpt.length));
  }

  function readabilityArticleExcerpt(article, metadata, marker) {
    var excerpt = normalizeText((article && article.excerpt) || "");
    if (!excerpt) return (article && article.excerpt) || null;

    var text = normalizeText((article && article.textContent) || "");
    var excerptCharacters = Array.from(excerpt);
    var textCharacters = Array.from(text);
    if (excerptCharacters.length >= 80 || textCharacters.length < 400) return article.excerpt;

    if (!readabilityExcerptIsVisibleLead(article, excerpt)) return article.excerpt;
    var template = readabilityArticleTemplate(article);
    if (!template) return article.excerpt;
    var summaryExcerpt = readabilitySummaryExcerpt(template, excerpt, marker);
    if (summaryExcerpt) return summaryExcerpt;

    var metadataExcerpt = normalizeText((metadata && metadata.excerpt) || "");
    var leadNodes = Array.prototype.filter.call(template.content.querySelectorAll("p"), function(node) {
      return node.getAttribute("data-fetchutil-excerpt-body") === marker;
    }).slice(0, 3);
    var metadataOwned = readabilityExcerptLength(metadataExcerpt) >= 40 && leadNodes.some(function(node) {
      return readabilityMetadataExcerptOwned(node, metadataExcerpt);
    });
    if (metadataOwned) return metadata.excerpt;

    return readabilityBodyExcerpt(template, excerpt, marker) || article.excerpt;
  }

  function stripReadabilityExcerptMarkers(html, marker) {
    var template = document.createElement("template");
    template.innerHTML = html;
    template.content.querySelectorAll("[data-fetchutil-excerpt-source], [data-fetchutil-excerpt-body], [data-fetchutil-excerpt-summary]").forEach(function(node) {
      if (node.getAttribute("data-fetchutil-excerpt-source") === marker) {
        node.removeAttribute("data-fetchutil-excerpt-source");
      }
      if (node.getAttribute("data-fetchutil-excerpt-body") === marker) {
        node.removeAttribute("data-fetchutil-excerpt-body");
      }
      var group = node.getAttribute("data-fetchutil-excerpt-summary") || "";
      if (group.indexOf(marker + ":") === 0) node.removeAttribute("data-fetchutil-excerpt-summary");
    });
    return template.innerHTML;
  }
