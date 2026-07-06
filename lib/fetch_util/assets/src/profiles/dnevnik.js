  function dnevnikArticleContent(metadata) {
    if (!dnevnikArticlePage()) return null;

    var body = dnevnikArticleBody();
    if (!body) return null;

    var content = profileArticleContent(metadata, body, {
      title: metadata.title || firstText(["article.story-content h1", "main h1", "h1"]),
      byline: firstText(["a[href*='/author/']", "meta[name='author']"], "content") || metadata.byline,
      minTextLength: 250,
      cleanupRoot: false,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".paywall-content",
          "[class*='share' i]",
          "[class*='social' i]",
          "[class*='advert' i]",
          "[id*='advert' i]",
          "[data-ad]",
          ".tab-content",
          ".main-footer-body",
          "footer"
        ].join(", "));

        root.querySelectorAll("div[role='paragraph'], div.default").forEach(function(el) {
          var paragraph = document.createElement("p");
          paragraph.innerHTML = el.innerHTML;
          el.replaceWith(paragraph);
        });

        root.querySelectorAll("p, div, span, a, button").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(сподели|линкът е копиран|копирай линк|изпрати по имейл|facebook|linkedin|viber|абонирайте се|ако сте абонат, влезте в профила си)$/i.test(text)) el.remove();
          if (/^продължете да четете с пълен достъп/i.test(text)) el.remove();
        });
      },
      validateMarkdown: function(markdown) {
        return !/Дневник и Капитал са сертифицирани по професионалния стандарт|Общи условия за ползване|Политика за бисквитките/i.test(markdown);
      },
      postProcessMarkdown: function(markdown) {
        return markdown.replace(/^\|\s+/gm, "");
      }
    });

    if (content) {
      metadata.language = null;
      if (dnevnikPublicBodyComplete(body)) dnevnikRemovePaywallIndicators();
    }
    return content;
  }

  function dnevnikArticlePage() {
    if (!hostMatches(/(^|\.)dnevnik\.bg$/)) return false;
    if (homepageRootPath()) return false;
    return !!dnevnikArticleBody();
  }

  function dnevnikArticleBody() {
    var selectors = [
      ".paywall-short-content",
      "#story-body",
      ".article-content",
      ".article__body",
      "#article-body",
      ".article-text",
      "article.story-content"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var candidates = Array.prototype.slice.call(document.querySelectorAll(selectors[i]));
      for (var j = 0; j < candidates.length; j += 1) {
        var node = candidates[j];
        if (node.closest("footer, nav, aside, .main-footer-body, .tab-content")) continue;
        if (normalizeText(node.textContent || "").length >= 250) return node;
      }
    }

    return null;
  }

  function dnevnikPublicBodyComplete(body) {
    var publicBody = body.querySelector(".paywall-short-content") || body;
    var text = normalizeText(publicBody.textContent || "");
    if (text.length < 700) return false;
    if (/\.\.\.$|…$/.test(text)) return false;
    return true;
  }

  function dnevnikRemovePaywallIndicators() {
    removeAll(document, [
      "meta[property='article:content_tier']",
      "meta[name='article:content_tier']",
      ".paywall-content",
      "[data-paywall]",
      "[data-piano-offer]"
    ].join(", "));

    document.querySelectorAll("[id*='paywall' i], [class*='paywall' i], [class*='article-lock' i]").forEach(function(el) {
      if (/paywall/i.test(el.getAttribute("id") || "")) el.removeAttribute("id");
      var classes = (el.getAttribute("class") || "").split(/\s+/).filter(function(name) {
        return name && !/paywall|article-lock/i.test(name);
      });
      if (classes.length) {
        el.setAttribute("class", classes.join(" "));
      } else {
        el.removeAttribute("class");
      }
    });

    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      if (/isAccessibleForFree|Paywall|Subscription/i.test(script.textContent || "")) script.remove();
    });
  }

  var dnevnikBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return dnevnikArticleContent(metadata) || dnevnikBaseHostAwareContent(metadata, pageText);
  };
