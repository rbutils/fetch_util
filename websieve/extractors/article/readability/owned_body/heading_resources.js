  function readabilityOwnedHeadingResourceBlocks(root, sourceClones) {
    var blocks = new Set();
    var cards = new Map();
    var excluded = "nav, header, footer, aside, form, button, pre, code, kbd, samp, details:not([open]), " +
      "[role='navigation'], [role='banner'], [role='complementary'], [role='dialog'], " +
      "[role='toolbar'], [role='menu'], [role='button']";
    var headingSelector = "h2, h3, h4, h5, h6";
    var contentOwner = "main, article, [role='main'], [itemprop~='articleBody']";
    var excludedParagraph = "div, section, article, h1, h2, h3, h4, h5, h6, ul, ol, dl, table, " +
      "pre, code, kbd, samp, button, input, select, textarea, img, picture, svg, video, audio, iframe, object, embed";

    function cardChildren(node, heading) {
      return Array.from(node.childNodes).every(function(child) {
        if (child === heading) return true;
        if (child.nodeType === Node.TEXT_NODE) return !normalizeText(child.textContent);
        return child.nodeType === Node.ELEMENT_NODE && child.localName === "p" &&
          !child.querySelector(excludedParagraph);
      });
    }

    function mappedLinks(source, clone) {
      var links = Array.from(source.querySelectorAll("a[href]"));
      var clonedLinks = Array.from(clone.querySelectorAll("a[href]"));
      return links.length === clonedLinks.length && links.every(function(link, index) {
        var mapped = clonedLinks[index];
        if (sourceClones.get(link) !== mapped || elementSubtreeHidden(link) ||
            normalizeText(link.textContent) !== normalizeText(mapped.textContent)) return false;
        try {
          var sourceUrl = new URL(link.getAttribute("href"), location.href);
          var cloneUrl = new URL(mapped.getAttribute("href"), location.href);
          return /^https?:$/.test(sourceUrl.protocol) && sourceUrl.href === cloneUrl.href;
        } catch (_error) { return false; }
      });
    }

    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "div" || clone.localName !== "div" || !root.contains(clone) ||
          source.closest(excluded) || elementSubtreeHidden(source)) return;
      var owner = source.closest(contentOwner);
      var ownerClone = owner && sourceClones.get(owner);
      if (!ownerClone || !root.contains(ownerClone) || !ownerClone.contains(clone)) return;
      var headings = Array.from(source.children).filter(function(node) { return node.matches(headingSelector); });
      if (headings.length !== 1) return;
      var heading = headings[0];
      var headingClone = sourceClones.get(heading);
      if (!headingClone || headingClone.parentElement !== clone || elementSubtreeHidden(heading) ||
          headingClone.localName !== heading.localName || !cardChildren(source, heading) ||
          !cardChildren(clone, headingClone) || normalizeText(source.textContent) !== normalizeText(clone.textContent)) return;
      if (heading.querySelector("button, input, select, textarea, img, picture, svg, video, audio, pre, code, kbd, samp")) return;
      var links = Array.from(heading.querySelectorAll("a[href]"));
      var clonedLinks = Array.from(headingClone.querySelectorAll("a[href]"));
      if (links.length !== 1 || clonedLinks.length !== 1 || sourceClones.get(links[0]) !== clonedLinks[0]) return;
      var label = normalizeText(heading.textContent);
      if (!label || label !== normalizeText(links[0].textContent) ||
          label !== normalizeText(headingClone.textContent) || label !== normalizeText(clonedLinks[0].textContent) ||
          elementSubtreeHidden(links[0])) return;
      if (!mappedLinks(source, clone)) return;
      var paragraphs = Array.from(source.children).filter(function(node) { return node.localName === "p"; });
      if (!paragraphs.every(function(paragraph) {
        if (!paragraph.children.length && !normalizeText(paragraph.textContent)) return true;
        var mapped = sourceClones.get(paragraph);
        return mapped && mapped.parentElement === clone && !elementSubtreeHidden(paragraph) &&
          normalizeText(paragraph.textContent) === normalizeText(mapped.textContent);
      })) return;
      cards.set(source, clone);
      if (paragraphs.every(function(node) { return !normalizeText(node.textContent); })) blocks.add(clone);
    });

    cards.forEach(function(clone, source) {
      if (!blocks.has(clone)) return;
      var group = source.parentElement;
      var mappedGroup = sourceClones.get(group);
      if (group.localName !== "div" || !mappedGroup || mappedGroup.localName !== "div" ||
          !root.contains(mappedGroup) || group.closest(excluded) || elementSubtreeHidden(group)) return;
      var children = Array.from(group.children);
      if (children.length !== mappedGroup.children.length || !children.every(function(child, index) {
        return child.closest(contentOwner) === source.closest(contentOwner) &&
          cards.get(child) === mappedGroup.children[index];
      })) return;
      if (Array.from(group.childNodes).some(function(node) {
        return node.nodeType === Node.TEXT_NODE && !!normalizeText(node.textContent);
      })) return;
      blocks.add(mappedGroup);
    });
    return blocks;
  }
