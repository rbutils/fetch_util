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
