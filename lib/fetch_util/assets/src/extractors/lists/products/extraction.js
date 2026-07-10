  function genericProductListContent(metadata) {
    var items = [];
    var selectors = ["main", "[role='main']", ".products", ".product-grid", ".product-list", ".search-results", ".category", ".collection", "body"];
    var roots = [];

    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        if (roots.indexOf(node) === -1) roots.push(node);
      });
    });

    var pageTerms = safeDecodeURI([location.pathname || "", location.search || "", (metadata && metadata.title) || document.title].join(" ")).toLowerCase().replace(/[^a-z0-9]+/g, " ").split(/\s+/).filter(function(term) {
      return term.length >= 3 && !/^(shop|store|products?|items?|brand|brands|category|categories|search|results|sale|gift|sets|perfume|perfumes|fragrance|fragrances|cologne|women|men|unisex)$/i.test(term);
    });
    var queryTerms = [];

    new URLSearchParams(location.search || "").forEach(function(value, key) {
      if (!/^(q|query|search|searchtext|keyword|k|d)$/i.test(key || "")) return;
      safeDecodeURI(value || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").split(/\s+/).forEach(function(term) {
        if (term.length >= 3 && queryTerms.indexOf(term) === -1) queryTerms.push(term);
      });
    });

    function rejectedProductTitle(text) {
      return /^\(\d+\)\s+/.test(text) || /^(top sellers|new arrivals|product|brand name|review count|star rating|sort by|view all|more options(?: from .*)?|privacy policy|my privacy choices|sign in|order status|shipping info|fragrances|see all fragrances|perfume|bath & body|gift sets|unboxed\/testers|perfume samples|cologne|samples|cologne samples|women'?s perfume|men'?s cologne|0 items in your bag|0 0 items in your bag|request it|become a fragrancenet\.com vip|powered by onetrust opens in a new tab)$/i.test(text) || /\(designer\)$/i.test(text);
    }

    function productUrlKey(url) {
      try {
        var parsed = new URL(url, location.href);
        return (parsed.origin + parsed.pathname).toLowerCase();
      } catch (_error) {
        return String(url || "").toLowerCase();
      }
    }

    function titleMatchesPageTerms(text) {
      text = text.toLowerCase();
      return pageTerms.some(function(term) {
        return text.indexOf(term) !== -1;
      });
    }

    function titleMatchesQueryTerms(text) {
      text = text.toLowerCase();
      return queryTerms.some(function(term) {
        return text.indexOf(term) !== -1;
      });
    }

    function candidateInfo(link) {
      var image = link.querySelector("img[alt], img[title]");
      var url = absoluteUrl(link.getAttribute("href"));
      var card = link.closest("article, li, [class*='product'], [class*='item'], [class*='card'], div, section") || link.parentElement;
      if (card === link && link.parentElement) card = link.parentElement.closest("article, li, [class*='product'], [class*='item'], [class*='card'], div, section") || link.parentElement;
      var titleLinkOptions = [];
      var titleOptions = [
        normalizeText(link.textContent || ""),
        normalizeText(link.getAttribute("aria-label") || ""),
        normalizeText(image && (image.getAttribute("alt") || image.getAttribute("title")))
      ];

      if (card && url) {
        Array.prototype.forEach.call(card.querySelectorAll("a[href][class*='title' i], [class*='title' i] a[href]"), function(titleLink) {
          var titleUrl = absoluteUrl(titleLink.getAttribute("href"));
          if (productUrlKey(titleUrl) === productUrlKey(url)) titleLinkOptions.push(normalizeText(titleLink.textContent || titleLink.getAttribute("aria-label") || ""));
        });
      }

      if (titleLinkOptions.length) titleOptions = titleLinkOptions;
      titleOptions.sort(function(a, b) { return b.length - a.length; });
      var title = titleOptions[0] || "";
      if (!url || !title || title.length < 6 || title.length > 140) return null;
      if (rejectedProductTitle(title)) return null;
      if (/(sort|filter|review|rating|privacy|cookie|onetrust)/i.test(url) && title.length < 32) return null;
      if (url === location.href || /^(javascript:|mailto:)/i.test(url)) return null;

      var productPath = "";
      try {
        productPath = new URL(url, location.href).pathname;
      } catch (_error) {
        return null;
      }

      var productUrl = /(\/product|\/perfume|\/cologne|\/dp\/|\/itm\/|\/pdp\/|\/shop\/products\/|\/p\/(?!pl(?:\/|$)))/i.test(productPath);
      var cardAttrs = normalizeText(card && [
        card.getAttribute("id"),
        card.getAttribute("class"),
        card.getAttribute("data-testid"),
        card.getAttribute("data-hb-id"),
        card.getAttribute("itemtype")
      ].join(" "));
      var productCard = /(product|item-cell|item-container|schema\.org\/Product)/i.test(cardAttrs);
      if (!productUrl && !productCard) return null;
      if (queryTerms.length && !titleMatchesQueryTerms(title)) return null;
      if (pageTerms.length && queryOrCategoryPage() && !titleMatchesPageTerms(title)) return null;

      var detail = productCardDetail(card, title, url);
      if (!titleMatchesPageTerms(title) && !productUrl && !productCard) return null;

      return { text: title, url: url, detail: detail };
    }

    function productCandidates(root, dedupe) {
      return collectCardLinkCandidates(root, {
        cardSelectors: "a[href]",
        allowMissingUrl: false,
        dedupe: dedupe,
        keyBuilder: function(candidate) {
          return [candidate.text + "|" + candidate.url, "url:" + candidate.url, "product:" + productUrlKey(candidate.url)];
        },
        candidateBuilder: function(link) {
          return candidateInfo(link);
        }
      });
    }

    function scoreRoot(root) {
      return productCandidates(root, false).length;
    }

    var bestRoot = roots.reduce(function(current, node) {
      var score = scoreRoot(node);
      if (!current || score > current.score) return { node: node, score: score };
      return current;
    }, null);

    if (!bestRoot || bestRoot.score < 4) return null;

    items = productCandidates(bestRoot.node, true);

    if (items.length < 4) return null;

    return listItemsContentResult(metadata, {
      excerpt: items[0].text,
      items: items
    });
  }
