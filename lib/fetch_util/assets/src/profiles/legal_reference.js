  function officialStatutePageSignature(doc, metadata) {
    var root = doc.querySelector("#container, #paddingLR12, main, body");
    var text = normalizeText((root && root.textContent) || "").slice(0, 20000);
    var title = normalizeText([
      metadata && metadata.title,
      doc.title,
      (doc.querySelector("h1") || {}).textContent
    ].join(" "));
    var legalContext = legalProvisionContext({ root: root, text: text, title: title });

    return /\b(?:code|act|statute|regulation|ordinance)\b/i.test(title) &&
      legalContext.profileOfficialTextSignals &&
      /\b(?:section|article)\s*\d+[a-z]?\b/i.test(text);
  }

  function sameOriginHtmlLink(doc) {
    var links = Array.prototype.slice.call(doc.querySelectorAll("a[href]"));
    var current = new URL(location.href);
    var best = null;

    links.some(function(link) {
      var href = link.getAttribute("href") || "";
      var text = normalizeText(link.textContent || link.getAttribute("title") || "");
      var url;
      try {
        url = new URL(href, location.href);
      } catch (_error) {
        return false;
      }
      if (url.origin !== current.origin) return false;
      if (!/\.html?(?:$|#)/i.test(url.pathname + url.hash)) return false;
      if (!/^(?:html|full text|full text in format html)$/i.test(text) && !/\/[^/]+\.html?$/i.test(url.pathname)) return false;
      if (url.pathname === current.pathname) return false;
      best = url.href.replace(/#.*/, "");
      return /^(?:html|full text in format html)$/i.test(text);
    });

    return best;
  }

  function fetchSameOriginDocument(url) {
    var xhr = new XMLHttpRequest();
    var parser;
    try {
      xhr.open("GET", url, false);
      xhr.send(null);
      if (xhr.status < 200 || xhr.status >= 300 || !xhr.responseText) return null;
      parser = new DOMParser();
      return parser.parseFromString(xhr.responseText, "text/html");
    } catch (_error) {
      return null;
    }
  }

  function legalTableOfContentsContent(metadata) {
    var root = document.querySelector(".LegContents, #viewLegContents, .viewLegContents, [class*='table-of-contents' i], [aria-label*='table of contents' i]");
    if (!root || !legalTableOfContentsPage(root, root.textContent || "")) return null;

    var clone = cleanClone(root);
    var title = normalizeText(((document.querySelector("#pageTitle, h1") || {}).textContent) || metadata.title || document.title);
    var heading = document.createElement("h1");
    heading.textContent = title;
    clone.insertBefore(heading, clone.firstChild);
    cleanupAgentRoot(clone);

    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML)).replace(/\n{3,}/g, "\n\n").trim();
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < 200) return null;

    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "list",
      hostAware: true
    };
  }

  function officialStatuteContent(metadata) {
    var sourceDoc = document;
    var sourceRoot = sourceDoc.querySelector("#container, #paddingLR12");
    if (!sourceRoot || !officialStatutePageSignature(sourceDoc, metadata)) return null;

    var sourceText = normalizeText(sourceRoot.textContent || "");
    var tocTableNode = sourceRoot.querySelector("table") || sourceDoc.querySelector("#paddingLR12 table, table");
    var tocTable = tocTableNode && /\bSection\s*1/i.test(tocTableNode.textContent || "");
    if (tocTable) {
      var linkedUrl = sameOriginHtmlLink(sourceDoc);
      var linkedDoc = linkedUrl && fetchSameOriginDocument(linkedUrl);
      if (linkedDoc && officialStatutePageSignature(linkedDoc, metadata)) sourceDoc = linkedDoc;
    }

    var root = sourceDoc.getElementById("paddingLR12") || sourceDoc.getElementById("container") || sourceDoc.querySelector("#paddingLR12, #container");
    if (!root) return null;

    var clone = cleanClone(root);
    clone.querySelectorAll("script, style, form, nav, .noprint, #toc, table").forEach(function(el) { el.remove(); });
    clone.querySelectorAll("a[href*='index.html#'], a[href*='index.htm#']").forEach(function(link) {
      var container = link.closest("p, div, li") || link;
      if (/^table of contents$/i.test(normalizeText(container.textContent || ""))) container.remove();
    });
    cleanupAgentRoot(clone);

    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    markdown = markdown.replace(/\n{3,}/g, "\n\n").trim();
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < 400 || !/\bSection\s*1/i.test(text) || !/\bSection\s*2/i.test(text)) return null;

    var title = normalizeText(((sourceDoc.querySelector("h1") || document.querySelector("h1") || {}).textContent) || metadata.title || document.title);
    if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true,
      legalProvision: true
    };
  }

  function structuredLegalProvisionContent(metadata) {
    var root = document.querySelector("text .text .section, text .section, [class~='text'] > .section");
    if (!root) return null;

    var sourceText = normalizeText(root.textContent || "");
    var hasSupplementaryNotes = !!document.querySelector("notes, [id*='notes' i], [class*='notes' i]");
    var title = normalizeText(((document.querySelector("#page_title, #pageTitle, h1") || {}).textContent) || metadata.title || document.title);
    var titleContext = normalizeText([title, document.title, location.pathname].join(" "));
    var legalContext = legalProvisionContext({ text: sourceText, title: titleContext, path: location.pathname || "" });
    var provisionSignature = /\b(?:U\.S\.\s+Code|Code|Statute|Act|Section|§)\b/i.test(titleContext) || legalContext.sectionOrArticleMarker;

    if (sourceText.length < 250 || !hasSupplementaryNotes || !provisionSignature || legalContext.numberedClauses < 2) return null;

    var clone = cleanClone(root);
    cleanupAgentRoot(clone);
    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < 250) return null;
    if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true,
      legalProvision: true
    };
  }

  function legalReferenceArticleContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll([
      "#extracted-content #main-content",
      "#extracted-content",
      ".wex-content",
      ".node-wex-term",
      "[class*='legal-reference' i]",
      "[class*='encyclopedia-entry' i]"
    ].join(", ")));
    var root = null;

    roots.some(function(candidate) {
      if (!candidate || !candidate.querySelector("h1") || textLength(candidate) < 500) return false;
      if (!candidate.querySelector("p")) return false;
      root = candidate;
      return true;
    });

    if (!root) return null;

    var signature = normalizeText([
      metadata.siteName || "",
      metadata.title || "",
      document.title || "",
      root.id || "",
      root.className || "",
      Array.prototype.slice.call(root.querySelectorAll("a[href]")).slice(0, 40).map(function(link) {
        return (link.getAttribute("href") || "") + " " + normalizeText(link.textContent || "");
      }).join(" ")
    ].join(" "));

    var legalSignature = /\b(?:law|legal|court|courts|statute|regulation|jurisdiction|litigation|plaintiff|defendant|claim|judgment|preclusion|rule|rights?)\b/i.test(signature);
    var referenceSignature = /\b(?:wex|encyclopedia|definition|definitions|reference|glossary|term)\b/i.test(signature) || /\/wex\//i.test(signature);
    if (!legalSignature || !referenceSignature) return null;

    var clone = cleanClone(root);
    clone.querySelectorAll([
      "aside",
      "nav",
      "[role='complementary']",
      "[id*='related' i]",
      "[class*='related' i]",
      "[id*='recommended' i]",
      "[class*='recommended' i]"
    ].join(", ")).forEach(function(el) { el.remove(); });

    var markdown = markdownFor(clone.innerHTML);
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < 500) return null;

    var title = normalizeText(((clone.querySelector("h1") || root.querySelector("h1") || {}).textContent) || metadata.title || document.title);
    if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }
