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

    // Recognition-only sample; the article renderer emits every retained visible link.
    var legalLinkSignatureSample = Array.prototype.slice.call(root.querySelectorAll("a[href]")).slice(0, 40).map(function(link) {
      return (link.getAttribute("href") || "") + " " + normalizeText(link.textContent || "");
    }).join(" ");
    var signature = normalizeText([
      metadata.siteName || "",
      metadata.title || "",
      document.title || "",
      root.id || "",
      root.className || "",
       legalLinkSignatureSample
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
