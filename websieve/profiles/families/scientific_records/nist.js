  function nistReferenceDataContent(metadata) {
    if (!/\.nist\.gov$/i.test(location.hostname || "") && !/^nist\.gov$/i.test(location.hostname || "")) return null;

    var main = document.querySelector("main#main, #main");
    var title = normalizeText(((main && main.querySelector("h1#Top, h1")) || {}).textContent || "");
    if (!main || !title) return null;

    var mainText = normalizeText(main.textContent || "");
    var hasCompoundData = /\bFormula:\s*\S/i.test(mainText) && /\bMolecular weight:\s*[0-9.]+/i.test(mainText) && /\bCAS Registry Number:\s*\S/i.test(mainText);
    if (!hasCompoundData) return null;

    return profileHtmlContent(metadata, main, {
      title: title,
      excerpt: metadata.excerpt,
      defaultExcerpt: false,
      siteName: metadata.siteName || "NIST",
      cleanupRoot: false,
      minTextLength: 220,
      rewriteRoot: function(root) {
        root.querySelectorAll(".copy-prior-text, svg, img, form, .sr-only").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("li").forEach(function(item) {
          var text = normalizeText(item.textContent || "");
          if (/^Chemical structure:/i.test(text) || /^Permanent link/i.test(text)) item.remove();
        });
      },
      validateMarkdown: function(markdown) {
        return /\bFormula\b[\s\S]*\bMolecular weight\b[\s\S]*\bCAS Registry Number\b/i.test(markdown);
      }
    });
  }
