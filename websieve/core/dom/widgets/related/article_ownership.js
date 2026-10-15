function relatedRailSourceArticle(railDecisions) {
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && !heading.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i]");
  });
  if (headings.length !== 1) return null;

  var article = headings[0].closest("article");
  if (!article || elementSubtreeHidden(article)) return null;
  var paragraphs = Array.from(article.querySelectorAll("p, blockquote")).filter(function(paragraph) {
    return relatedArticleBodyParagraph(paragraph, article, railDecisions);
  });
  if (paragraphs.length < 2 || paragraphs.reduce(function(total, paragraph) {
    return total + normalizeText(paragraph.textContent || "").length;
  }, 0) < 60) return null;
  return article;
}

function relatedRailHasUniqueVisibleArticleOwner() {
  return !!relatedRailSourceArticle();
}

function relatedRailRootOwnsArticle(root) {
  var selectedArticle = root && root.matches && root.matches("article") ? root : root && root.querySelector("article");
  if (!selectedArticle || elementSubtreeHidden(selectedArticle)) return false;
  // This comparison only reads its source and selected owners. Share primitive
  // rail decisions across their paragraphs, then discard them before any caller
  // cleanup can mutate a clone. No rendered tree or cross-call result is cached.
  var railDecisions = new WeakMap();
  var sourceArticle = relatedRailSourceArticle(railDecisions);
  if (!sourceArticle) return false;

  var sourceHeadings = Array.from(sourceArticle.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading);
  });
  var selectedHeadings = Array.from(selectedArticle.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading);
  });
  if (sourceHeadings.length !== 1 || selectedHeadings.length !== 1 ||
      normalizeText(sourceHeadings[0].textContent || "") !== normalizeText(selectedHeadings[0].textContent || "")) return false;

  var sourceParagraphs = Array.from(sourceArticle.querySelectorAll("p, blockquote")).filter(function(paragraph) {
    return relatedArticleOwnedBodyParagraph(paragraph, sourceArticle, railDecisions);
  }).map(function(paragraph) { return normalizeText(paragraph.textContent || ""); });
  var selectedParagraphs = Array.from(selectedArticle.querySelectorAll("p, blockquote")).filter(function(paragraph) {
    return relatedArticleOwnedBodyParagraph(paragraph, selectedArticle, railDecisions);
  });
  var recognizedParagraphs = selectedParagraphs.filter(function(paragraph) {
    return relatedArticleBodyParagraph(paragraph, selectedArticle, railDecisions);
  });
  if (recognizedParagraphs.length < 2 || recognizedParagraphs.reduce(function(total, paragraph) {
    return total + normalizeText(paragraph.textContent || "").length;
  }, 0) < 60) return false;

  var sourceIndexByText = new Map();
  sourceParagraphs.forEach(function(text, index) {
    if (sourceIndexByText.has(text)) sourceIndexByText.set(text, null);
    else sourceIndexByText.set(text, index);
  });
  var previousIndex = -1;
  return selectedParagraphs.every(function(paragraph) {
    var text = normalizeText(paragraph.textContent || "");
    var index = sourceIndexByText.get(text);
    if (!sourceIndexByText.has(text) || index === null || index <= previousIndex) return false;
    previousIndex = index;
    return true;
  });
}

function relatedArticleParagraphInRail(paragraph, article, railDecisions) {
  for (var parent = paragraph.parentElement; parent && parent !== article; parent = parent.parentElement) {
    var related;
    if (railDecisions && railDecisions.has(parent)) related = railDecisions.get(parent);
    else {
      related = relatedHeadingRecordRail(parent);
      if (railDecisions) railDecisions.set(parent, related);
    }
    if (related) return true;
  }
  return false;
}

function relatedArticleOwnedBodyParagraph(paragraph, article, railDecisions) {
  if (paragraph.closest("article") !== article || elementVisuallyHidden(paragraph) ||
      !normalizeText(paragraph.textContent || "")) return false;
  return !relatedArticleParagraphInRail(paragraph, article, railDecisions);
}

function relatedArticleBodyParagraph(paragraph, article, railDecisions) {
  if (paragraph.closest("article") !== article || elementVisuallyHidden(paragraph) ||
      normalizeText(paragraph.textContent || "").length < 20) return false;
  return !relatedArticleParagraphInRail(paragraph, article, railDecisions);
}
