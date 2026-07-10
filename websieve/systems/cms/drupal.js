  function drupalDomDetected() {
    var generator = document.querySelector("meta[name='generator'][content*='Drupal' i]");
    if (generator) return true;

    if (document.querySelector("body[class*='drupal' i], .node__content, .field--name-body")) return true;

    return false;
  }

  function drupalArticleContent(metadata) {
    if (!drupalDomDetected()) return null;

    var body = document.querySelector(".node__content, .field--name-body, .article__body");
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      titleSelectors: ["article h1", ".node__title", "h1"],
      minTextLength: 180,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".views-element-container",
          "[class*='views' i]",
          ".block",
          "[class*='block' i]",
          ".comment",
          "[class*='comment' i]",
          ".comments",
          "[class*='comment-wrapper' i]",
          "nav",
          "aside",
          "form"
        ].join(", "));
      }
    });
  }

  registerHostAwareProfile(true, drupalArticleContent);
  hostAwareProfiles.unshift(hostAwareProfiles.pop());
