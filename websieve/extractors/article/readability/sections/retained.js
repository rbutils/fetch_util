  function readerSectionParagraphNarrative(paragraph) {
    if (!paragraph || paragraph.querySelector("button, input, select, textarea, iframe, form")) return false;
    var walker = paragraph.ownerDocument.createTreeWalker(paragraph, NodeFilter.SHOW_TEXT);
    var text = "";
    while (walker.nextNode()) {
      var node = walker.currentNode;
      if (!node.parentElement.closest("a, button, input, select, textarea")) text += node.textContent;
    }
    return normalizeText(text).length >= 40;
  }

  function readerSectionHeadingSnapshots(root, metadata, sourceClones, sourceIdentities, marker) {
    var headlines = [];
    sourceIdentities.forEach(function(_identity, source) {
      var clone = sourceClones.get(source);
      if (source.localName === "h1" && clone &&
          clone.getAttribute("data-fetchutil-reader-source-headline") === marker) headlines.push(source);
    });
    if (headlines.length !== 1 || !sourceOwnedReaderHeadlineTitleMatches(headlines[0].textContent, null, metadata)) return null;
    var owner = headlines[0].parentElement;
    var ownerClone = sourceClones.get(owner);
    if (!owner || owner === document.body || !owner.matches("article, main, section, div") ||
        owner.querySelectorAll("h1").length !== 1 || !ownerClone || !root.contains(ownerClone)) return null;
    var idCounts = new Map();
    document.querySelectorAll("[id]").forEach(function(node) {
      var id = node.getAttribute("id");
      idCounts.set(id, (idCounts.get(id) || 0) + 1);
    });
    var headings = [];
    Array.from(owner.children).forEach(function(source) {
      if (!source.matches("h2, h3, h4, h5, h6") || !source.id || idCounts.get(source.id) !== 1 ||
          elementVisuallyHidden(source)) return;
      var heading = sourceClones.get(source);
      var paragraph = source.nextElementSibling;
      var paragraphClone = paragraph && sourceClones.get(paragraph);
      var paragraphIdentity = paragraph && sourceIdentities.get(paragraph);
      if (!heading || !root.contains(heading) || heading.parentElement !== ownerClone ||
          heading.querySelector("p, div, section, article, ul, ol, table, pre, button, input, select, textarea") ||
          !paragraph || paragraph.localName !== "p" || !paragraphClone || !root.contains(paragraphClone) ||
          paragraphClone.parentElement !== ownerClone || !paragraphIdentity || !paragraphIdentity.unique ||
          normalizeText(paragraphClone.textContent) !== paragraphIdentity.visibleText ||
          !readerSectionParagraphNarrative(paragraphClone)) return;
      var text = normalizeText(heading.textContent);
      if (text) headings.push({
        id: source.id,
        text: text,
        html: heading.outerHTML,
        paragraph: paragraph,
        paragraphId: paragraphIdentity.id,
        paragraphText: paragraphIdentity.visibleText
      });
    });
    return headings.length ? { owner: owner, headings: headings } : null;
  }

  function sourceOwnedReaderRetainedSections(article, snapshots, sourceClones, sourceIdentities, marker) {
    if (!article || !article.content || !snapshots) return article;
    var template = document.createElement("template");
    template.innerHTML = article.content;
    var root = template.content;
    var evidence = sourceOwnedReaderSelectedParagraphs(root, sourceClones, sourceIdentities, marker, true);
    if (!evidence || evidence.sourceParagraphs.some(function(source) { return !snapshots.owner.contains(source); })) return article;
    var selected = new Set(evidence.sourceParagraphs);
    var nodesById = new Map();
    root.querySelectorAll("[id]").forEach(function(node) {
      var id = node.getAttribute("id");
      nodesById.set(id, nodesById.has(id) ? null : node);
    });
    var retainedLabels = new Set(Array.from(root.querySelectorAll("h1, h2, h3, h4, h5, h6")).map(function(node) {
      return normalizeText(node.textContent);
    }));
    var changed = false;
    snapshots.headings.forEach(function(snapshot) {
      var paragraph = nodesById.get(snapshot.paragraphId);
      if (nodesById.has(snapshot.id) || retainedLabels.has(snapshot.text) || !selected.has(snapshot.paragraph) ||
          !paragraph || paragraph.localName !== "p" || normalizeText(paragraph.textContent) !== snapshot.paragraphText) return;
      var headingTemplate = document.createElement("template");
      headingTemplate.innerHTML = snapshot.html;
      var heading = headingTemplate.content.firstElementChild;
      if (!heading || heading.getAttribute("id") !== snapshot.id || normalizeText(heading.textContent) !== snapshot.text) return;
      paragraph.before(heading);
      retainedLabels.add(snapshot.text);
      nodesById.set(snapshot.id, heading);
      changed = true;
    });
    if (changed) {
      article.content = template.innerHTML;
      article.textContent = normalizeText(root.textContent);
    }
    return article;
  }
