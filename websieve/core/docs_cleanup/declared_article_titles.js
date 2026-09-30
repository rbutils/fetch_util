function articleTitleFromDeclaredDescription(html, title, siteName, description) {
  if (!html || !title || !siteName || !description) return title;
  var match = title.match(/^(.*)\s+(?:-|\||\u2013|\u2014)\s+(.+)$/);
  if (!match) return title;
  var brand = function(value) { return normalizeText(value).replace(/^www\./i, "").toLowerCase(); };
  var headline = normalizeText(match[1]);
  if (brand(match[2]) !== brand(siteName) ||
      normalizeText(description).replace(/[.!?]$/, "") !== headline) return title;

  var selected = document.createElement("div");
  selected.innerHTML = html;
  var articles = selected.querySelectorAll("article");
  if (articles.length !== 1) return title;
  var owner = sourceArticleForSelectedParagraphs(articles[0]);
  if (!owner) return title;
  var sourceHeadings = owner.querySelectorAll("h1");
  var selectedHeadings = articles[0].querySelectorAll("h1");
  if (sourceHeadings.length > 1 || selectedHeadings.length > 1 ||
      (sourceHeadings.length === 1 && (elementSubtreeHidden(sourceHeadings[0]) || normalizeText(sourceHeadings[0].textContent || "") !== headline)) ||
      (selectedHeadings.length === 1 && normalizeText(selectedHeadings[0].textContent || "") !== headline)) return title;
  return headline;
}
