  function detailArticleRecordUrls(record) {
    var values = [];

    function append(value) {
      if (!value) return;
      if (Array.isArray(value)) {
        value.forEach(append);
        return;
      }
      if (typeof value === "string") {
        values.push(value);
        return;
      }
      if (typeof value !== "object") return;
      append(value.url);
      append(value["@id"]);
    }

    append(record && record.url);
    append(record && record.mainEntityOfPage);
    append(record && record["@id"]);
    return values;
  }

  function matchingStructuredDetailArticle(content) {
    var title = normalizeText(content && content.title || "");
    if (!title) return null;

    var documentKeys = pageStructuredDataDocumentKeys();
    var articleTypes = ["article", "newsarticle", "reportagenewsarticle", "analysisnewsarticle", "opinionnewsarticle"];
    var matches = structuredDataNodes().filter(function(record) {
      if (!nodeTypes(record).some(function(type) { return articleTypes.indexOf(String(type).toLowerCase()) !== -1; })) return false;
      if (normalizeText(record.headline || record.name || "") !== title) return false;

      return detailArticleRecordUrls(record).some(function(url) {
        var key = structuredDataDocumentKey(url);
        return key && documentKeys.indexOf(key) !== -1;
      });
    });
    return matches.length === 1 ? matches[0] : null;
  }

  function substantialSelectedDetailArticle(content) {
    if (!content || content.contentType !== "article") return false;
    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || "");
    var paragraphs = Array.prototype.filter.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= 40;
    }).length;
    var sentenceCount = (text.match(/[.!?。！？؟।]+/g) || []).length;
    return text.length >= 600 && (paragraphs >= 2 || sentenceCount >= 3 || (content.readerMode && text.length >= 900));
  }

  function detailArticleTextWitnesses(content) {
    var root = document.createElement("div");
    root.innerHTML = content && content.html || "";
    var paragraphs = Array.prototype.map.call(root.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    }).filter(function(text) { return text.length >= 60; });
    if (!paragraphs.length) return [];
    return paragraphs.length === 1 ? paragraphs : [paragraphs[0], paragraphs[paragraphs.length - 1]];
  }

  function detailArticleDescriptionWitness(record) {
    var description = normalizeText(record && (record.description || record.abstract) || "");
    if (!description) return null;
    var segments = description.split(/\s*[|•]\s*/).map(normalizeText).filter(function(text) {
      return text.length >= 60;
    });
    if (!segments.length) return null;

    for (var index = 0; index < segments.length; index += 1) {
      var text = segments[index];
      var matches = Array.prototype.filter.call(document.querySelectorAll(
        "h2, h3, h4, p, [class*='stand'], [class*='summary'], [class*='intro'], [class*='lead'], [class*='subtitle']"
      ), function(node) {
        return normalizeText(node.textContent || "") === text &&
          !elementSubtreeHidden(node) &&
          !node.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']");
      });
      if (matches.length === 1) return matches[0];
    }
    return null;
  }

  function detailArticleSourceOwner(content, record) {
    var title = normalizeText(content && content.title || "");
    var headings = Array.prototype.filter.call(document.querySelectorAll("h1, [itemprop='headline']"), function(heading) {
      return normalizeText(heading.textContent || "") === title && !elementSubtreeHidden(heading);
    });
    if (headings.length !== 1) return null;

    var owner = headings[0].closest("article, section, main, [role='main']");
    if (!owner || elementSubtreeHidden(owner)) return null;
    var ownerText = normalizeText(owner.textContent || "");
    var selectedRoot = document.createElement("div");
    selectedRoot.innerHTML = content && content.html || "";
    var selectedText = normalizeText(selectedRoot.textContent || content && content.textContent || "");
    var witnesses = detailArticleTextWitnesses(content);
    if (!witnesses.length) {
      var descriptionNode = detailArticleDescriptionWitness(record);
      if (!descriptionNode || !owner.contains(descriptionNode)) return null;
      witnesses = [normalizeText(descriptionNode.textContent || "")];
    }
    if (!witnesses.every(function(text) {
      return ownerText.indexOf(text) !== -1 && selectedText.indexOf(text) !== -1;
    })) return null;
    return owner;
  }

  function detailArticleListContainer(node, listRoot, articleOwner) {
    var current = node && node.nodeType === 1 ? node : node && node.parentElement;
    while (current && current !== listRoot && current !== document.body) {
      if (current.contains(articleOwner) || current.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) {
        current = current.parentElement;
        continue;
      }
      var signal = [current.id || "", current.className || "", current.getAttribute("role") || ""]
        .join(" ").replace(/([a-z\d])([A-Z])/g, "$1 $2").replace(/[^A-Za-z0-9]+/g, " ").toLowerCase();
      if (current.matches("ul, ol, [role='list']") ||
          /\b(?:archive|catalog|directory|feed|index|listing|results)\b/.test(signal)) return current;
      current = current.parentElement;
    }
    return null;
  }

  function lateListHasIndependentRoot(candidate, articleOwner) {
    var extraction = candidate && candidate.listExtraction;
    var listRoot = extraction && extraction.sourceNode;
    var items = extraction && extraction.items || [];
    if (!listRoot || items.length < 8) return false;
    if (!listRoot.contains(articleOwner) && !articleOwner.contains(listRoot)) return true;

    var containers = new Map();
    items.forEach(function(item) {
      var source = item && (item.sourceNode || item.card);
      if (!source || articleOwner.contains(source)) return;
      var container = detailArticleListContainer(source, listRoot, articleOwner);
      if (!container) return;
      if (!containers.has(container)) containers.set(container, new Set());
      containers.get(container).add(item);
    });
    var required = Math.max(8, Math.ceil(items.length * 0.8));
    return Array.from(containers.values()).some(function(ownedItems) {
      return ownedItems.size >= required;
    });
  }

  function selectedArticleHasExplicitDetailOwnership(content, metadata, candidate) {
    if (!content || !candidate || candidate.contentType !== "list" || likelyListPath()) return false;
    var structuredArticle = matchingStructuredDetailArticle(content);
    if (!substantialSelectedDetailArticle(content) || !structuredArticle) return false;
    var articleOwner = detailArticleSourceOwner(content, structuredArticle);
    return !!articleOwner && !lateListHasIndependentRoot(candidate, articleOwner);
  }

  function structuredDetailRailTokens(node) {
    return normalizeText([(node && node.id) || "", (node && node.getAttribute && node.getAttribute("class")) || ""]
      .join(" ").replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[^A-Za-z0-9]+/g, " ")).toLowerCase();
  }

  function structuredDetailArticleRail(node) {
    var tokens = " " + structuredDetailRailTokens(node) + " ";
    if (/\b(?:related|recommend|recommendation|popular|latest|feed|outbrain|taboola)\b/.test(tokens)) return true;
    return /\b(?:left|right|side)\b/.test(tokens) && /\b(?:articles|news|posts|stories)\b/.test(tokens);
  }

  function structuredDetailArticleClone(owner, content, record) {
    var title = normalizeText(content.title || "");
    var witness = normalizeText((detailArticleDescriptionWitness(record) || {}).textContent || "");
    var heading = Array.from(owner.querySelectorAll("h1")).find(function(node) {
      return normalizeText(node.textContent || "") === title;
    });
    var description = Array.from(owner.querySelectorAll("h2, h3, h4, p, [class*='stand' i], [class*='summary' i], [class*='intro' i], [class*='lead' i], [class*='subtitle' i]")).find(function(node) {
      return normalizeText(node.textContent || "") === witness;
    });
    var sourceClones = new Map();
    var clone = visibilityPrunedClone(owner, document.implementation.createHTMLDocument(""), sourceClones);

    Array.from(owner.querySelectorAll("*")).forEach(function(node) {
      var mapped;
      if (!structuredDetailArticleRail(node)) return;
      if (node.contains(heading) || node.contains(description)) return;
      mapped = sourceClones.get(node);
      if (mapped && mapped.parentNode) mapped.remove();
    });
    return clone;
  }

  function ownedStructuredDetailArticleContent(content, metadata, candidate) {
    if (!selectedArticleHasExplicitDetailOwnership(content, metadata, candidate)) return null;
    var structuredArticle = matchingStructuredDetailArticle(content);
    var articleOwner = detailArticleSourceOwner(content, structuredArticle);
    if (!articleOwner) return null;

    var clone = structuredDetailArticleClone(articleOwner, content, structuredArticle);
    var html = sanitizedHtml(clone.outerHTML || "");
    var root = document.createElement("div");
    root.innerHTML = html;
    var textContent = normalizeText(root.textContent || "");
    if (textContent.length < 400 || textContent.indexOf(normalizeText(content.title || "")) === -1) return null;

    return Object.assign({}, content, {
      html: html,
      markdown: null,
      textContent: textContent,
      readerMode: false
    });
  }
