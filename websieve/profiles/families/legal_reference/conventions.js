  function legalConventionIndexContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll(".page-content .container, main .container, main, .content"));
    var best = null;

    roots.forEach(function(root) {
      var conventionLists = Array.prototype.slice.call(root.querySelectorAll("ul.arrows, ol.arrows, ul, ol")).filter(function(list) {
        var links = Array.prototype.slice.call(list.querySelectorAll("a[href]"));
        if (links.length < 4) return false;
        var conventionLinks = links.filter(function(link) {
          var text = normalizeText(link.textContent || "");
          var href = link.getAttribute("href") || "";
          return /\b(?:convention|protocol|principles?|instrument)\b/i.test(text) && /\b(?:conventions?|instruments?|full-text|specialised-sections)\b/i.test(href);
        });
        return conventionLinks.length >= Math.min(4, links.length);
      });
      var context = normalizeText([root.querySelector("h1, h2") && root.querySelector("h1, h2").textContent, root.textContent].join(" "));
      var score = textLength(root) + conventionLists.length * 1000;

      if (conventionLists.length < 2) return;
      if (!/\bConventions? and (?:other )?Instruments?\b/i.test(context) && !/\bCore Conventions?\b/i.test(context)) return;
      if (!best || score > best.score) best = { root: root, score: score };
    });

    if (!best) return null;

    return institutionalArticleResult(metadata, best.root, {
      docsLike: true,
      minText: 400,
      titleRoot: best.root,
      strip: function(clone) {
        removeAll(clone, COMMON_INSTITUTIONAL_CHROME_SELECTOR + ", [class*='breadcrumb' i], .navbar, [class*='nav' i], form");
      }
    });
  }
