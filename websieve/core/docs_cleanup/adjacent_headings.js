function articleTitleFromAdjacentHeading(html, title) {
  if (!document.body || !html || !title) return title;
  var articles = Array.prototype.filter.call(document.querySelectorAll("article"), function(article) {
    return !elementSubtreeHidden(article) && article.previousElementSibling &&
      article.previousElementSibling.matches("header") && article.querySelectorAll("p").length >= 2;
  });
  if (articles.length !== 1) return title;

  var article = articles[0];
  var header = article.previousElementSibling;
  var headings = header.querySelectorAll("h1");
  if (headings.length !== 1 || header.querySelector("nav, form, [role='navigation'], a[href]") ||
      elementSubtreeHidden(headings[0])) return title;

  function words(text) {
    return normalizeText(text || "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
  }

  var shortTitle = words(title);
  var heading = normalizeText(headings[0].textContent || "");
  var fullTitle = words(heading);
  if (shortTitle.length < 35 || fullTitle.length < shortTitle.length + 12 ||
      fullTitle.indexOf(shortTitle) !== 0) return title;

  var finalWords = fullTitle.split(" ").slice(-4).join(" ");
  if (finalWords.length < 15 || words(article.textContent).indexOf(finalWords) < 0 ||
      words(html).indexOf(finalWords) < 0) return title;
  return heading;
}

function articleTitleFromOwnedExternalHeading(html, title, siteName) {
  if (!document.body || !html || !title || !siteName) return title;
  var fullTitle = normalizeText(title);
  var titleParts = fullTitle.match(/^(.+)\s+(?:-|\||\u2013|\u2014)\s+([^\n]+)$/);
  if (!titleParts || normalizeText(titleParts[2]).toLowerCase() !== normalizeText(siteName).toLowerCase()) return title;

  var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(main) {
    return !elementSubtreeHidden(main) && !main.parentElement.closest("main, [role='main']");
  });
  if (mains.length !== 1) return title;
  var main = mains[0];
  var articles = Array.prototype.filter.call(main.querySelectorAll("article"), function(article) {
    return !elementSubtreeHidden(article) && !article.parentElement.closest("article");
  });
  var headings = Array.prototype.filter.call(main.querySelectorAll("h1"), function(heading) {
    return !elementSubtreeHidden(heading);
  });
  if (articles.length !== 1 || headings.length !== 1) return title;

  var article = articles[0];
  var headline = normalizeText(headings[0].textContent || "");
  var shortTitle = normalizeText(titleParts[1]);
  if (article.contains(headings[0]) || !(headings[0].compareDocumentPosition(article) & Node.DOCUMENT_POSITION_FOLLOWING) ||
      shortTitle.length < 30 || headline.length < shortTitle.length + 8 || headline.indexOf(shortTitle) !== 0) return title;

  var selected = document.createElement("div");
  selected.innerHTML = html;
  var paragraphs = Array.prototype.map.call(selected.querySelectorAll("p"), function(paragraph) {
    return normalizeText(paragraph.textContent || "");
  }).filter(Boolean);
  if (paragraphs.length < 3 || paragraphs[0] !== headline) return title;
  var sourceParagraphs = Array.prototype.map.call(article.querySelectorAll("p"), function(paragraph) {
    return elementSubtreeHidden(paragraph) ? "" : normalizeText(paragraph.textContent || "");
  }).filter(Boolean);
  if (sourceParagraphs.length < 3 || sourceParagraphs[0] !== headline) return title;
  var selectedProse = paragraphs.slice(1).filter(function(paragraph) { return paragraph.length >= 40; });
  if (selectedProse.length < 2 || !selectedProse.every(function(paragraph) {
    return sourceParagraphs.indexOf(paragraph) !== -1;
  })) return title;
  return headline;
}
