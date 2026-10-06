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
      return /^(?:html|full text|full text in format html)$/i.test(text);
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
      postProcessMarkdown: compactMarkdownSpacing,
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
