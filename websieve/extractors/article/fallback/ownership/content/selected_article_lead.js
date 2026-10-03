  function fallbackSelectedArticleLead(root, renderedText, ownership, sourceClones, metadata) {
    if (!root || !ownership || !sourceClones || !metadata ||
        ownership.proof !== "same-owner-source-headline" || !ownership.node.matches("article") ||
        root === sourceClones.get(ownership.node) || !root.contains(sourceClones.get(ownership.node))) return null;

    var article = ownership.node;
    var heading = ownership.heading;
    var canonical = document.querySelector("link[rel~='canonical' i]");
    if (!heading || heading.closest("article") !== article ||
        normalizeText(heading.textContent || "") !== normalizeText(ownership.title || "") ||
        articleTitleFromOwnedHeading(heading.outerHTML, metadata.title, metadata.siteName) !== ownership.title ||
        sourceOwnershipPageUrl(canonical && canonical.getAttribute("href")) !== sourceOwnershipPageUrl(location.href)) return null;

    var selected = Array.from(root.querySelectorAll("p")).filter(function(node) {
      return !!normalizeText(node.textContent || "");
    });
    var source = Array.from(article.querySelectorAll("p")).filter(function(node) {
      return !elementVisuallyHidden(node) && !!normalizeText(node.textContent || "");
    });
    if (source.length < 2 || selected.length !== source.length || !selected.every(function(node, index) {
      return sourceClones.get(source[index]) === node &&
        normalizeText(node.textContent || "") === normalizeText(source[index].textContent || "");
    })) return null;

    var lead = source.find(function(paragraph) {
      return paragraph.closest("article") === article &&
        !paragraph.closest("header, address, nav, footer, aside, form, figure, figcaption, menu, time, " +
          "[role~='navigation' i], [role~='complementary' i], blockquote, " +
          "[itemprop~='author' i], [itemprop~='creator' i]") &&
        !paragraph.querySelector("button, input, select, textarea") &&
        !sourceOwnedPublicationField(paragraph) && !fallbackExcerptChromeOwner(article, paragraph) &&
        !articleIntroFurniture(paragraph, article) && /\p{L}/u.test(paragraph.textContent || "");
    });
    if (!lead) return null;
    var value = normalizeText(lead.textContent || "");
    return renderedText.indexOf(value) !== -1 ? value : null;
  }
