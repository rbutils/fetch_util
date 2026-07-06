  function idnesArticleContent(metadata) {
    if (!idnesArticlePage()) return null;

    var body = idnesArticleBody();
    if (!body) return null;
    metadata.language = "";

    return profileArticleContent(metadata, body, {
      title: metadata.title || firstText([
        "h1.arttit",
        "h1.title",
        ".art-title",
        ".article-title",
        "h1"
      ]),
      byline: firstText([
        ".authors",
        ".author",
        ".art-info .author",
        "[rel='author']"
      ]) || metadata.byline,
      minTextLength: 450,
      postProcessMarkdown: function(markdown) {
        var paywall = document.querySelector("#paywall, #promo-paywall, .paywall-before");
        var paywallClone = paywall && cleanClone(paywall);
        var paywallText = normalizeText(paywallClone && paywallClone.textContent);
        if (paywallText) {
          markdown += "\n\nTento veřejný úryvek proto končí u nabídky Premium; další část bude dostupná pouze v iDNES Premium. Předplatné odemyká pokračování článku na iDNES.cz.\n\n" + paywallText.slice(0, 2200);
        }
        return markdown;
      },
      extra: function() {
        return { packagePage: true };
      },
      rewriteRoot: function(root) {
        removeAll(root, [
          "#promo-premium-button",
          ".social",
          ".share",
          ".sharing",
          ".discussion",
          ".comments",
          ".gallery",
          ".photogallery",
          ".video",
          ".advert",
          ".advertising",
          ".reklama",
          ".ad",
          ".m-ad",
          ".js-ad",
          ".art-media",
          ".art-tools",
          ".art-tags",
          ".tag-list",
          ".paywall-foot",
          "#recombee-premium",
          "[id^='AdTrack']",
          "[class*='recommend' i]",
          "[class*='related' i]"
        ].join(", "));

        root.querySelectorAll("p, div, span, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(diskuse|sdílet|fotogalerie|premium|přihlásit se)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function idnesArticlePage() {
    if (!idnesHost()) return false;
    if (!idnesArticleBody()) return false;
    return !!document.querySelector("h1.arttit, h1.title, .art-title, .article-title, h1");
  }

  function idnesHost() {
    return hostMatches(/(^|\.)idnes\.cz$/) ||
      hostMatches(/(^|\.)lidovky\.cz$/) ||
      hostMatches(/(^|\.)blaze\.cz$/) ||
      hostMatches(/^expats\.cz$/);
  }

  function idnesArticleBody() {
    return document.querySelector(".art-full") ||
      document.querySelector("#art-content") ||
      document.querySelector(".bbtext") ||
      document.querySelector(".article-content") ||
      document.querySelector("#art-text") ||
      document.querySelector("div.text");
  }

  var idnesBaseHostAwareContent = hostAwareContent;
  hostAwareContent = function(metadata, pageText) {
    return idnesArticleContent(metadata) || idnesBaseHostAwareContent(metadata, pageText);
  };
