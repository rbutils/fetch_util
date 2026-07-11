  function ringierAxelSpringerArticleContent(metadata, pageText) {
    if (!ringierAxelSpringerHost()) return null;

    var root = document.createElement("div");
    var title = firstText(["h1.article__title", ".detail_title", ".ods-m-labeled-h1__text", "article h1", "h1"]) || metadata.title;
    var leadArticle = document.querySelector(".ods-article-lead[data-section='article-lead']");
    var lead = document.querySelector(".ods-article-lead .ods-a-lead, .article__lead, .detail_lead, .articleLead");
    var summary = document.querySelector(".ods-m-inline-summary-container__list");
    var body = document.querySelector(".ods-article-body[data-section='article-body'], .article__body, .detail_body, div.articleContent, .cda_artblox");
    var articleData = structuredDataNode(["NewsArticle", "Article", "VideoObject"]);
    var articleBody = entityText(articleData && articleData.articleBody);
    var textSummary = ringierAxelSpringerSummaryText(pageText);

    if (!leadArticle && !lead && !summary && !body && !textSummary && !articleBody) return null;

    var summaryItems = summary ? Array.prototype.map.call(summary.querySelectorAll("li"), function(item) {
      return normalizeText(item.textContent || "");
    }).filter(Boolean) : [];
    if (lead) root.appendChild(ringierAxelSpringerCleanClone(lead));
    if (!lead && metadata.excerpt) {
      var leadParagraph = document.createElement("p");
      leadParagraph.textContent = metadata.excerpt;
      root.appendChild(leadParagraph);
    }
    if (body) root.appendChild(ringierAxelSpringerCleanClone(body));
    if (!body && articleBody) {
      var bodyParagraph = document.createElement("p");
      bodyParagraph.textContent = articleBody;
      root.appendChild(bodyParagraph);
    }

    var leadText = lead ? ringierAxelSpringerMarkdown(ringierAxelSpringerCleanClone(lead)) : metadata.excerpt || "";
    var bodyText = body ? ringierAxelSpringerMarkdown(ringierAxelSpringerCleanClone(body)) : articleBody || "";
    var markdownParts = [];
    if (title) markdownParts.push("# " + title);
    if (summaryItems.length) {
      markdownParts.push("## Streszczenie\n\n" + summaryItems.map(function(item) { return "- " + item; }).join("\n"));
    } else if (textSummary) {
      markdownParts.push("## Streszczenie\n\n" + textSummary);
    }
    ringierAxelSpringerPushUnique(markdownParts, leadText);
    ringierAxelSpringerPushUnique(markdownParts, bodyText);

    var markdown = cleanupMarkdownNoise(markdownParts.filter(Boolean).join("\n\n"));
    var text = normalizeText(markdown);
    if (text.length < 250) return null;

    return {
      title: title || metadata.title,
      byline: firstText([".ods-m-author-authorship__author-item a", ".article__author", ".detail_author", "[rel='author']"]) || metadata.byline,
      excerpt: leadText || metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true,
      docsLike: true
    };
  }

  function registerRingierAxelSpringerProfiles() {
    registerHostAwareProfile(true, ringierAxelSpringerArticleContent);
  }

  function ringierAxelSpringerCleanClone(node) {
    var clone = safeDeepClone(node, document);
    var removable = clone.querySelectorAll("iframe, script, style, noscript, nav, footer, [data-ad], [data-testid*='ad' i], [class~='ad'], [class*='-ad-'], [class$='-ad'], [class^='ad-'], [id~='ad'], [id*='-ad-'], [id$='-ad'], [id^='ad-'], [class*='recommend' i], [class*='related' i]");
    Array.prototype.forEach.call(removable, function(element) { element.remove(); });

    Array.prototype.forEach.call(clone.querySelectorAll("p, div, section, aside, span"), function(element) {
      var text = normalizeText(element.textContent || "");
      if (/^REKLAMA$/i.test(text) || /^Dalszy ciag artykulu pod materialem wideo/i.test(stripDiacritics(text))) element.remove();
    });
    Array.prototype.forEach.call(clone.querySelectorAll("h2, h3, h4, p, div, section, aside"), function(element) {
      var text = stripDiacritics(normalizeText(element.textContent || ""));
      if (!/^(?:Zobacz takze|Czytaj takze|Wydarzenie dnia|Zobacz rowniez)(?::|$)/i.test(text)) return;
      var container = element.parentElement;
      if (element.querySelector("a")) element.remove();
      else if (container && container !== clone) container.remove();
    });
    return clone;
  }

  function ringierAxelSpringerMarkdown(root) {
    return cleanupMarkdownNoise(markdownFor(root.innerHTML || ""))
      .replace(/\s+-\s+\*\*(?:Zobacz (?:takze|także)|Czytaj (?:takze|także)|Wydarzenie dnia|Zobacz (?:rowniez|również))\s*:?\*\*[\s\S]*$/i, "")
      .trim();
  }

  function ringierAxelSpringerHost() {
    return hostMatches(/(^|\.)(komputerswiat\.pl|onet\.pl|medonet\.pl)$/) ||
      hostMatches(/(^|\.)poradnikzdrowie\.pl$/);
  }

  function ringierAxelSpringerSummaryText(pageText) {
    var text = normalizeText(pageText || "");
    var match = text.match(/Poniżej streszczenie artykułu:\s*(?:Skrót przygotowany przez Onet Czat z AI, może zawierać błędy\.\s*)?(.+?)\s*Zapytaj o więcej Onet Czat z AI/i);
    if (!match) return "";

    return normalizeText(match[1]);
  }

  function ringierAxelSpringerPushUnique(parts, text) {
    text = normalizeText(text || "");
    if (!text) return;
    var normalizedText = text.toLowerCase();
    if (parts.some(function(part) { return normalizeText(part).toLowerCase().indexOf(normalizedText) !== -1; })) return;
    parts.push(text);
  }
