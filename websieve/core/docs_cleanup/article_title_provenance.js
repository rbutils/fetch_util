function sourceArticleForSelectedParagraphs(selectedArticle) {
  if (!selectedArticle) return null;
  var selectedParagraphs = Array.prototype.map.call(selectedArticle.querySelectorAll("p"), function(paragraph) {
    return normalizeText(paragraph.textContent || "");
  }).filter(Boolean);
  if (selectedParagraphs.length < 2) return null;

  var sourceArticles = Array.prototype.filter.call(document.querySelectorAll("article"), function(article) {
    return !elementSubtreeHidden(article) && !sourceOwnershipInChrome(article) && !article.parentElement.closest("article");
  });
  var owners = sourceArticles.filter(function(owner) {
    var sourceParagraphs = Array.prototype.filter.call(owner.querySelectorAll("p"), function(paragraph) {
      return !elementSubtreeHidden(paragraph) && paragraph.closest("article") === owner;
    }).map(function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    });
    var sourcePositions = new Map();
    sourceParagraphs.forEach(function(text, index) {
      sourcePositions.set(text, sourcePositions.has(text) ? null : index);
    });
    var lastIndex = -1;
    return selectedParagraphs.every(function(text) {
      var index = sourcePositions.get(text);
      if (index === undefined || index === null || index <= lastIndex) return false;
      lastIndex = index;
      return true;
    });
  });
  return owners.length === 1 ? owners[0] : null;
}

function sourceOwnedSelfLinkedArticle(selectedArticle, title) {
  if (!selectedArticle || !title) return null;
  var selectedH1 = selectedArticle.querySelector("h1");
  if (selectedH1 && normalizeText(selectedH1.textContent || "") !== normalizeText(title)) return null;
  var owner = sourceArticleForSelectedParagraphs(selectedArticle);
  if (!owner) return null;
  var sourceHeadings = owner.querySelectorAll("h1");
  if (sourceHeadings.length !== 1 || elementSubtreeHidden(sourceHeadings[0]) ||
      normalizeText(sourceHeadings[0].textContent || "") !== normalizeText(title)) return null;

  var selectedHeading = selectedH1 || Array.prototype.find.call(selectedArticle.querySelectorAll("h2"), function(heading) {
    return normalizeText(heading.textContent || "") === normalizeText(title);
  }) || null;
  var selectedLinks = selectedHeading ? selectedHeading.querySelectorAll("a[href]") : [];
  var sourceLinks = sourceHeadings[0].querySelectorAll("a[href]");
  if (selectedLinks.length > 1 || sourceLinks.length !== 1 || elementSubtreeHidden(sourceLinks[0]) ||
      normalizeText(sourceLinks[0].textContent || "") !== normalizeText(title)) return null;
  var sourceUrl = materializedHttpUrl(sourceLinks[0].getAttribute("href"));
  var selectedUrl = selectedLinks.length ? materializedHttpUrl(selectedLinks[0].getAttribute("href")) : sourceUrl;
  if (!sourceUrl || !selectedUrl || selectedUrl !== sourceUrl) return null;
  var destination = new URL(sourceUrl);
  if (destination.origin !== location.origin || destination.pathname !== location.pathname ||
      destination.search !== location.search) return null;
  return { owner: owner, selectedHeading: selectedHeading, sourceHeading: sourceHeadings[0], url: sourceUrl };
}
