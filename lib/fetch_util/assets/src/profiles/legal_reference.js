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

  var fetchUtilBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return legalReferenceArticleContent(metadata) || fetchUtilBaseHostAwareContent(metadata, pageText);
  };
