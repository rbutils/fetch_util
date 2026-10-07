  function readabilityOwnedMarkedIntroExcerpt(article, metadata) {
    var title = normalizeText(article && (article.title || (metadata && metadata.title)));
    if (!article || !title || normalizeText(article.excerpt) !== title || !article.content) return null;
    var selected = document.createElement("div");
    selected.innerHTML = article.content;
    var selectedText = normalizeText(selected.textContent);
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading) && !sourceOwnershipInChrome(heading) &&
        normalizeText(heading.textContent) === title;
    });
    if (headings.length !== 1) return null;
    var heading = headings[0];
    var owner = heading.parentElement;
    while (owner && owner !== document.body && Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
      var text = normalizeText(paragraph.textContent);
      return text && !elementSubtreeHidden(paragraph) && !sourceOwnershipInChrome(paragraph) &&
        !articleIntroFurniture(paragraph, owner) && selectedText.includes(text) &&
        (heading.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    }).length < 2) owner = owner.parentElement;
    if (!owner || owner === document.body || Array.from(owner.querySelectorAll("h1")).filter(function(node) {
      return !elementSubtreeHidden(node);
    }).length !== 1) return null;
    var paragraphs = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
      var text = normalizeText(paragraph.textContent);
      return text && !elementSubtreeHidden(paragraph) && !sourceOwnershipInChrome(paragraph) &&
        !articleIntroFurniture(paragraph, owner) && selectedText.includes(text) &&
        (heading.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    var intros = Array.from(owner.querySelectorAll("p, div, span, section")).filter(function(node) {
      var tokens = [node.id || ""].concat(Array.from(node.classList || []));
      var text = normalizeText(node.textContent);
      return tokens.some(function(token) {
        return /(?:^|[-_])(?:lead|lede|dek|deck|standfirst|summary|intro)(?:[-_](?:text|copy|content))?$/i.test(token);
      }) && text && selectedText.includes(text) && !elementSubtreeHidden(node) &&
        !articleIntroFurniture(node, owner) && !node.querySelector("p, h1, h2, h3, h4, h5, h6, button, input, select, textarea, form") &&
        (heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        paragraphs.every(function(paragraph) {
          return node !== paragraph && (node.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
        });
    });
    return intros.length === 1 ? readabilityExcerptPrefix(intros[0].textContent) : null;
  }
