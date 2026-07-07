  function joomlaDomDetected() {
    var generator = document.querySelector("meta[name='generator'][content*='Joomla' i]");
    if (generator) return true;

    if (document.querySelector(".article-content, #ja-content, .item-page")) return true;

    var body = document.body;
    if (!body) return false;

    var template = normalizeText(body.getAttribute("data-template") || "");
    return /\bjoomla\b|\b(?:cassiopeia|protostar|atum|helix|gantry|t4|ja-)\b/i.test(template);
  }

  function joomlaArticleContent(metadata) {
    if (!joomlaDomDetected()) return null;

    var body = document.querySelector(".com-content-article__body, .article-content, #ja-contentmain, .itemFullText, .articleBody");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      titleSelectors: ["article h1", ".item-page h1", "h1"],
      minTextLength: 180,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".breadcrumb",
          "[class*='breadcrumb' i]",
          ".module",
          ".moduletable",
          "[class*='module' i]",
          ".pagination",
          ".pagenav",
          "[class*='pagination' i]",
          "nav",
          "aside",
          "form"
        ].join(", "));
      }
    });
  }

  registerHostAwareProfile(true, joomlaArticleContent);
  hostAwareProfiles.unshift(hostAwareProfiles.pop());
