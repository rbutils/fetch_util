  function tempoArticleContent(metadata) {
    if (!tempoArticlePage()) return null;

    var body = tempoArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".title-article", "main h1", "article h1", "h1"]) || metadata.title,
      minTextLength: 220,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".related-news",
          ".related-article",
          ".bacadetail",
          "[class*='related' i]",
          "[class*='share' i]",
          "[class*='audio' i]",
          "[class*='ringkasan' i]",
          "[class*='summary' i]",
          "[class*='newsletter' i]",
          "[class*='rekomendasi' i]",
          "[class*='recommend' i]",
          "[class*='ads' i]",
          "[id*='ads' i]",
          "[data-testid*='share' i]"
        ].join(", "));

        root.querySelectorAll("p, div, span, button, a, li").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (!text || text.length > 220) return;
          if (/^(dengarkan artikel|bagikan|gabung tempo circle|tampilkan ringkasan artikel|sembunyikan ringkasan artikel|mengapa tempo bisa dipercaya|scroll ke bawah untuk membaca berita)$/i.test(text)) el.remove();
          if (/^(akses edisi mingguan|akses penuh seluruh artikel tempo\+|baca dengan lebih sedikit gangguan iklan|anda mendukung independensi jurnalisme tempo)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function tempoArticlePage() {
    if (!hostMatches(/(^|\.)tempo\.co$/)) return false;
    if (/^\/?$/i.test(location.pathname || "")) return false;
    return !!tempoArticleBody();
  }

  function tempoArticleBody() {
    var selectors = [
      ".article-body",
      "div.detail-body",
      ".news-content",
      ".content-detail",
      "[itemprop='articleBody']",
      "article[itemprop='articleBody']"
    ];

    for (var i = 0; i < selectors.length; i++) {
      var node = document.querySelector(selectors[i]);
      if (tempoUsefulArticleNode(node)) return node;
    }

    var candidates = Array.prototype.slice.call(document.querySelectorAll("main article, article"));
    var best = null;
    var bestScore = 0;
    candidates.forEach(function(node) {
      if (!tempoUsefulArticleNode(node)) return;
      var text = normalizeText(node.innerText || node.textContent || "");
      var paragraphScore = node.querySelectorAll("p").length * 80;
      var score = text.length + paragraphScore;
      if (node.closest("main")) score += 250;
      if (score > bestScore) {
        best = node;
        bestScore = score;
      }
    });

    return best;
  }

  function tempoUsefulArticleNode(node) {
    if (!node) return false;
    if (node.closest("header, nav, footer, aside")) return false;
    var text = normalizeText(node.innerText || node.textContent || "");
    if (text.length < 220) return false;
    if (node.querySelectorAll("p").length < 1) return false;
    return true;
  }

  registerHostAwareProfile(true, tempoArticleContent);
