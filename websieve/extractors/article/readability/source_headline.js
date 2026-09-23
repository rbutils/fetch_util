  function sourceOwnedReaderHeadlineEvidence(html, title) {
    if (!document.body || !html || !title) return null;
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading) && !heading.closest("header, nav, footer, aside, form, [role='navigation']");
    });
    if (headings.length !== 1 || normalizeText(headings[0].textContent) !== normalizeText(title)) return null;

    var selected = document.createElement("div");
    selected.innerHTML = html;
    if (selected.querySelector("h1, h2, h3, h4, h5, h6")) return null;

    var owner = headings[0].parentElement;
    while (owner && owner !== document.body && owner.querySelectorAll("p").length < 3) owner = owner.parentElement;
    if (!owner || owner === document.body || owner.querySelectorAll("h1").length !== 1) return null;

    var sourceParagraphs = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
      return !elementSubtreeHidden(paragraph) &&
        !paragraph.closest("aside, nav, footer, form, [role='complementary']") &&
        normalizeText(paragraph.textContent).length >= 80;
    }).map(function(paragraph) { return normalizeText(paragraph.textContent); });
    var selectedParagraphs = Array.from(selected.querySelectorAll("p")).map(function(paragraph) {
      return normalizeText(paragraph.textContent);
    }).filter(function(text) { return text.length >= 80; });
    if (selectedParagraphs.length < 2 || selectedParagraphs[0] !== sourceParagraphs[0] ||
        !selectedParagraphs.every(function(text) { return sourceParagraphs.indexOf(text) >= 0; })) return null;

    return { heading: headings[0], lead: sourceParagraphs[0] };
  }

  function sourceOwnedReaderMissingHeadlineContent(content) {
    if (!content || !content.readerMode || content.hostAware || content.contentType !== "article" ||
        !content.html || content.markdown) return content;
    var evidence = sourceOwnedReaderHeadlineEvidence(content.html, content.title);
    if (!evidence) return content;

    var root = document.createElement("div");
    root.innerHTML = content.html;
    var heading = document.createElement("h1");
    heading.textContent = normalizeText(evidence.heading.textContent);
    root.insertBefore(heading, root.firstChild);
    return Object.assign({}, content, { html: root.innerHTML });
  }
