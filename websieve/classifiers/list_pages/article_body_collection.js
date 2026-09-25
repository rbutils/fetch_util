  function independentArticleBodyCollection() {
    if (!document.body || !likelyListPath()) return false;
    var records = Array.prototype.filter.call(document.querySelectorAll("main article, [role~='main' i] article"), function(article) {
      if (elementSubtreeHidden(article) || article.parentElement.closest("article")) return false;
      var heading = Array.prototype.find.call(article.querySelectorAll("h2, h3, [itemprop~='headline' i]"), function(node) {
        return !elementSubtreeHidden(node);
      });
      if (!heading) return false;
      var body = article.querySelector("[itemprop~='articleBody' i]");
      if (!body || body.closest("article") !== article) return false;
      var paragraphs = Array.prototype.filter.call(body.querySelectorAll("p"), function(paragraph) {
        return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 24;
      });
      return paragraphs.length >= 2;
    });
    var titles = records.map(function(article) {
      var heading = Array.prototype.find.call(article.querySelectorAll("h2, h3, [itemprop~='headline' i]"), function(node) {
        return !elementSubtreeHidden(node);
      });
      return normalizeText(heading && heading.textContent || "");
    });
    return titles.length >= 3 && new Set(titles).size === titles.length;
  }
