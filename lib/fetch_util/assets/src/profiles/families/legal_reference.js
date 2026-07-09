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

    var title = normalizeText(((sourceDoc.querySelector("h1") || document.querySelector("h1") || {}).textContent) || metadata.title || document.title);
    return profileHtmlContent(metadata, root, {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: function(_metadata, _root, _node, _markdown, text) { return metadata.excerpt || text.slice(0, 280); },
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      minTextLength: 400,
      postProcessMarkdown: function(markdown) { return markdown.replace(/\n{3,}/g, "\n\n").trim(); },
      rewriteRoot: function(clone) {
        clone.querySelectorAll("script, style, form, nav, .noprint, #toc, table").forEach(function(el) { el.remove(); });
        clone.querySelectorAll("a[href*='index.html#'], a[href*='index.htm#']").forEach(function(link) {
          var container = link.closest("p, div, li") || link;
          if (/^table of contents$/i.test(normalizeText(container.textContent || ""))) container.remove();
        });
      },
      validateMarkdown: function(_markdown, text) {
        return /\bSection\s*1/i.test(text) && /\bSection\s*2/i.test(text);
      },
      extra: { legalProvision: true }
    });
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

    return profileHtmlContent(metadata, root, {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: function(_metadata, _root, _node, _markdown, text) { return metadata.excerpt || text.slice(0, 280); },
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      minTextLength: 250,
      extra: { legalProvision: true }
    });
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

    return profileHtmlContent(metadata, root, {
      title: function(_metadata, clone) {
        return normalizeText(((clone.querySelector("h1") || root.querySelector("h1") || {}).textContent) || metadata.title || document.title);
      },
      byline: null,
      excerpt: function(_metadata, _root, _node, _markdown, text) { return metadata.excerpt || text.slice(0, 280); },
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      cleanupRoot: false,
      cleanupMarkdown: false,
      minTextLength: 500,
      rewriteRoot: function(clone) {
        clone.querySelectorAll([
          "aside",
          "nav",
          "[role='complementary']",
          "[id*='related' i]",
          "[class*='related' i]",
          "[id*='recommended' i]",
          "[class*='recommended' i]"
        ].join(", ")).forEach(function(el) { el.remove(); });
      }
    });
  }

  function courtListenerOpinionContent(metadata) {
    if (!hostMatches(/(^|\.)courtlistener\.com$/i)) return null;
    if (!/^\/opinion\/\d+\//i.test(location.pathname || "")) return null;

    var root = document.querySelector("#opinion-content, .opinion-content, [data-testid='opinion-content'], article .opinion") ||
      document.querySelector("article") ||
      document.querySelector("main");
    if (!root || textLength(root) < 700) return null;

    return profileHtmlContent(metadata, root, {
      title: normalizeText(((document.querySelector("main h1, article h1, h1") || {}).textContent) || metadata.title || document.title),
      byline: function() { return firstText([".author", ".judge", ".judges", "[class*='judge' i]"]) || null; },
      siteName: metadata.siteName || "CourtListener",
      minTextLength: 700,
      rewriteRoot: function(clone) {
        clone.querySelectorAll([
          "script",
          "style",
          "nav",
          "aside",
          "form",
          ".sidebar",
          ".breadcrumb",
          ".breadcrumbs",
          ".alert",
          ".btn",
          ".share",
          ".citation-links",
          ".download-menu",
          "[class*='citation' i]",
          "[class*='download' i]",
          "[class*='related' i]"
        ].join(", ")).forEach(function(el) { el.remove(); });
      },
      validateMarkdown: function(_markdown, text) {
        return /\b(?:v\.|versus|plaintiff|defendant|appellant|appellee|court|appeal|opinion|judgment)\b/i.test(text);
      },
      extra: { legalOpinion: true }
    });
  }

  function metadataListValue(root, label) {
    var terms = Array.prototype.slice.call((root || document).querySelectorAll("dt"));
    var values = [];

    terms.forEach(function(term) {
      if (!new RegExp("^" + label + "s?:?$", "i").test(normalizeText(term.textContent || ""))) return;

      var node = term.nextElementSibling;
      while (node && node.tagName && node.tagName.toLowerCase() === "dd") {
        var value = normalizeText(node.textContent || "");
        if (value && values.indexOf(value) === -1) values.push(value);
        node = node.nextElementSibling;
      }
    });

    return values.join("; ") || null;
  }

  function federalRegisterVisibleDate() {
    return metadataListValue(document, "Publication Date") ||
      firstText(["#metadata_content_area .metadata a[href*='/documents/']"]);
  }

  function federalRegisterAgency() {
    return metadataListValue(document, "Agencies") ||
      normalizeText(Array.prototype.slice.call(document.querySelectorAll("#metadata_content_area .metadata .agencies a, h6.agency, h6.sub-agency")).map(function(node) {
        return normalizeText(node.textContent || "");
      }).filter(function(value, index, values) {
        return value && values.indexOf(value) === index;
      }).join("; ")) || null;
  }

  function federalRegisterNoticeContent(metadata) {
    if (!hostMatches(/(^|\.)federalregister\.gov$/i)) return null;
    if (!/^\/documents\/\d{4}\/\d{2}\/\d{2}\//i.test(location.pathname || "")) return null;

    var title = firstText(["#metadata_content_area > h1", "meta[name='title']"], "content") ||
      normalizeText((metadata && metadata.title) || document.title || "").replace(/^Federal Register\s*::\s*/i, "");
    var documentType = metadataListValue(document, "Document Type") || firstText([".main-title-bar h1"]);
    var body = document.querySelector(".document-content, #document-content, .doc-content, .article, #fulltext_content_area") ||
      document.querySelector("#agency") && document.querySelector("#agency").parentElement;
    if (!body || textLength(body) < 250) return null;

    var typeText = normalizeText(documentType || "");
    if (!/\b(?:notice|proposed rule|rule|presidential document)\b/i.test(typeText)) return null;

    return profileHtmlContent(metadata, body, {
      title: title,
      byline: federalRegisterAgency,
      publishedTime: federalRegisterVisibleDate,
      siteName: metadata.siteName || "Federal Register",
      contentType: "notice",
      minTextLength: 250,
      rewriteRoot: function(clone) {
        clone.querySelectorAll([
          "script",
          "style",
          "nav",
          "aside",
          "form",
          ".fr-seal-meta",
          ".document-clipping-actions",
          ".copy-to-clipboard",
          "[class*='tooltip' i]",
          "[class*='share' i]"
        ].join(", ")).forEach(function(el) { el.remove(); });
      },
      validateMarkdown: function(_markdown, text) {
        return /\b(?:AGENCY|ACTION|SUMMARY|DATES|SUPPLEMENTARY INFORMATION):/i.test(text) ||
          /\bFederal Register\b/i.test(text);
      }
    });
  }

  function govUkGuidanceContent(metadata) {
    if (!hostMatches(/(^|\.)gov\.uk$/i)) return null;
    if (!/^\/guidance\//i.test(location.pathname || "")) return null;

    var body = document.querySelector(".gem-c-contents-list-with-body") || document.querySelector(".gem-c-govspeak .govspeak");
    if (!body || textLength(body) < 500) return null;
    var contentsMarkdown = govUkContentsMarkdown(body);

    return profileHtmlContent(metadata, body, {
      title: firstText([".gem-c-heading__text", "main h1", "h1"]) || metadata.title || document.title,
      byline: function() { return metadataListValue(document, "From") || metadata.byline || null; },
      publishedTime: metadata.publishedTime || firstText(["meta[name='govuk:first-published-at']"], "content"),
      siteName: metadata.siteName || "GOV.UK",
      minTextLength: 500,
      cleanupRoot: false,
      rewriteRoot: function(clone) {
        clone.querySelectorAll("nav.gem-c-contents-list, nav[aria-label='Contents']").forEach(function(nav) {
          var div = document.createElement("div");
          Array.prototype.slice.call(nav.childNodes).forEach(function(child) { div.appendChild(child); });
          nav.parentNode.replaceChild(div, nav);
        });
        clone.querySelectorAll([
          "script",
          "style",
          "form",
          ".gem-c-print-link",
          ".gem-c-single-page-notification-button",
          ".published-dates-button-group",
          "[data-sticky-element]"
        ].join(", ")).forEach(function(el) { el.remove(); });
      },
      postProcessMarkdown: function(markdown, root) {
        if (/^##\s+Contents\b/m.test(markdown)) return markdown;
        if (contentsMarkdown) return contentsMarkdown + "\n\n" + markdown;

        var links = Array.prototype.slice.call(root.querySelectorAll(".gem-c-contents-list a, [aria-label='Contents'] a, a[href^='#']"));
        var items = links.map(function(link) {
          var text = normalizeText(link.textContent || "");
          var href = link.getAttribute("href") || "";
          return text && /^#/.test(href) ? "- [" + text + "](" + href + ")" : null;
        }).filter(Boolean);

        return items.length ? "## Contents\n\n" + items.join("\n") + "\n\n" + markdown : markdown;
      },
      validateMarkdown: function(markdown, text) {
        return /^#\s+/m.test(markdown) || text.length >= 500;
      }
    });
  }

  function govUkContentsMarkdown(root) {
    var links = Array.prototype.slice.call((root || document).querySelectorAll(".gem-c-contents-list a, [aria-label='Contents'] a, a[href^='#']"));
    var items = links.map(function(link) {
      var text = normalizeText(link.textContent || "");
      var href = link.getAttribute("href") || "";
      return text && /^#/.test(href) ? "- [" + text + "](" + href + ")" : null;
    }).filter(Boolean);

    return items.length ? "## Contents\n\n" + items.join("\n") : null;
  }

  function registerLegalReferenceProfiles() {
    registerHostAwareProfile(true, federalRegisterNoticeContent);
    registerHostAwareProfile(true, govUkGuidanceContent);
    registerHostAwareProfile(true, courtListenerOpinionContent);
    registerHostAwareProfile(true, structuredLegalProvisionContent);
    registerHostAwareProfile(true, legalTableOfContentsContent);
    registerHostAwareProfile(true, officialStatuteContent);
    registerHostAwareProfile(true, legalReferenceArticleContent);
  }
