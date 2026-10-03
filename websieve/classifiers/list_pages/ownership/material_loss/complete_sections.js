  function listCandidateLosesCompleteOwnedSections(content, candidate, rendered) {
    if (!content || !content.readerMode) return false;
    var sourceNamed = Array.from(document.querySelectorAll("[id]"));
    var namedRoots = Array.from(rendered.querySelectorAll("[id]")).filter(function(node) {
      return node.id && sourceNamed.some(function(sourceNode) {
        return sourceNode.id === node.id;
      });
    });
    if (namedRoots.length !== 1) return false;

    var owners = sourceNamed.filter(function(node) {
      return node.id === namedRoots[0].id;
    });
    if (owners.length !== 1) return false;
    var owner = owners[0];
    if (owner === document.body || owner === document.documentElement ||
        elementSubtreeHidden(owner) || owner.closest("nav, aside, footer, [role='navigation'], [role='complementary']") ||
        owner.querySelector("nav, aside, footer, [role='navigation'], [role='complementary']")) return false;

    var sourceParagraphs = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
      return !elementSubtreeHidden(paragraph) && !paragraph.closest("table, figure, figcaption");
    });
    var sourceImages = Array.from(owner.querySelectorAll("img[src]")).filter(function(image) {
      return !elementSubtreeHidden(image);
    });
    var sourceItems = Array.from(owner.querySelectorAll("li")).filter(function(item) {
      return !elementSubtreeHidden(item) && !item.querySelector("a[href]");
    });
    var sourceHeadings = Array.from(owner.querySelectorAll("h1, h2, h3")).filter(function(heading) {
      return !elementSubtreeHidden(heading);
    });
    if (sourceParagraphs.length < 3 || sourceImages.length < 2 || sourceItems.length < 3 ||
        sourceHeadings.length < 2) return false;

    var articleText = normalizeText(rendered.textContent || "");
    if (sourceParagraphs.some(function(paragraph) {
      return articleText.indexOf(normalizeText(paragraph.textContent || "")) === -1;
    }) || sourceItems.some(function(item) {
      return articleText.indexOf(normalizeText(item.textContent || "")) === -1;
    }) || sourceHeadings.some(function(heading) {
      return articleText.indexOf(normalizeText(heading.textContent || "")) === -1;
    }) || sourceImages.some(function(image) {
      return !Array.from(rendered.querySelectorAll("img[src]")).some(function(renderedImage) {
        return renderedImage.src === image.src;
      });
    })) return false;

    var listRoot = document.createElement("div");
    listRoot.innerHTML = candidate.html || "";
    var links = Array.from(listRoot.querySelectorAll("a[href]"));
    if (!links.length || links.some(function(link) {
      return !Array.from(owner.querySelectorAll("ul li a[href]")).some(function(sourceLink) {
        return sourceLink.href === link.href && normalizeText(sourceLink.textContent) === normalizeText(link.textContent) &&
          !elementSubtreeHidden(sourceLink) && !sourceLink.closest("li").querySelector("p, img, article");
      });
    })) return false;

    var candidateText = normalizeText(candidate.markdown || candidate.textContent || "");
    return sourceParagraphs.some(function(paragraph) {
      return candidateText.indexOf(normalizeText(paragraph.textContent || "")) === -1;
    }) || sourceImages.some(function(image) {
      return !Array.from(listRoot.querySelectorAll("img[src]")).some(function(candidateImage) {
        return candidateImage.src === image.src;
      });
    });
  }
