  function readabilityMappedPublicationHeaderText(source, clone, sourceClones) {
    var excluded = readabilityDataTableInterfaces() + ", input, select, textarea, details, " +
      "h1, h2, h3, h4, h5, h6, table, pre, a, img, picture, svg, video, audio, canvas, " +
      "iframe, object, embed, script, style, template, noscript";
    if (source.querySelector(excluded) || clone.querySelector(excluded) || !normalizeText(clone.textContent)) return false;
    var sourceWalker = source.ownerDocument.createTreeWalker(source, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    var mappedNodes = [clone];
    while (sourceWalker.nextNode()) {
      var node = sourceWalker.currentNode;
      var mapped = sourceClones.get(node);
      if (!mapped || !clone.contains(mapped)) {
        var element = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
        if (element && elementSubtreeHidden(element)) continue;
        return false;
      }
      if (node.nodeType !== mapped.nodeType) return false;
      if (node.nodeType === Node.TEXT_NODE && node.nodeValue !== mapped.nodeValue) return false;
      if (node.nodeType === Node.ELEMENT_NODE && (node.localName !== mapped.localName ||
          (node.hasAttribute("id") && node.id !== mapped.id) ||
          !["name", "role", "aria-label", "title", "lang", "dir", "datetime"].every(function(attribute) {
            return node.getAttribute(attribute) === mapped.getAttribute(attribute);
          }))) return false;
      mappedNodes.push(mapped);
    }
    var cloneWalker = clone.ownerDocument.createTreeWalker(clone, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    var index = 1;
    while (cloneWalker.nextNode()) {
      if (mappedNodes[index] !== cloneWalker.currentNode) return false;
      index += 1;
    }
    return index === mappedNodes.length;
  }

  function readabilityDataPublicationHeader(publication, sourceClones, sourceIdentities, blocks) {
    var excluded = readabilityDataTableInterfaces() + ", pre, code, kbd, samp, details:not([open])";
    var heading = publication.sourceHeading;
    function afterHeading(node) {
      return !node.contains(heading) && !!(heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
    }
    var boundary = Array.from(publication.source.querySelectorAll("h2, h3, h4, h5, h6, table")).find(function(node) {
      var mapped = sourceClones.get(node);
      return afterHeading(node) && mapped && publication.root.contains(mapped) &&
        !node.closest(excluded) && !elementSubtreeHidden(node);
    });
    if (!boundary) return;
    function ownsHeaderNode(node) {
      var mapped = sourceClones.get(node);
      return afterHeading(node) && !node.contains(boundary) &&
        !!(node.compareDocumentPosition(boundary) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        mapped && publication.root.contains(mapped) && !node.closest(excluded) && !elementSubtreeHidden(node);
    }
    publication.source.querySelectorAll("div").forEach(function(node) {
      if (!ownsHeaderNode(node)) return;
      var mapped = sourceClones.get(node);
      if (mapped.localName === "div" && readabilityMappedPublicationHeaderText(node, mapped, sourceClones)) blocks.add(mapped);
    });
    var introduction = Array.from(publication.source.querySelectorAll("p")).find(function(node) {
      var mapped = sourceClones.get(node);
      var identity = sourceIdentities.get(node);
      return ownsHeaderNode(node) && readabilityExcerptNode(node) && identity && identity.unique &&
        identity.visibleText === normalizeText(mapped.textContent) && readerSectionParagraphNarrative(mapped);
    });
    if (introduction) publication.introduction = introduction;
  }

  function readabilityDataPublicationPathExcerpt(node, heading, excerpt) {
    if (node.contains(heading) || !(node.compareDocumentPosition(heading) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        elementSubtreeHidden(node) || normalizeText(node.textContent) !== excerpt ||
        node.querySelector("p, pre, code, table, h1, h2, h3, h4, h5, h6, form, button, input, select, textarea")) return false;
    var links = Array.from(node.querySelectorAll("a[href]"));
    if (!links.length || !links.every(function(link) {
      try {
        var url = new URL(link.getAttribute("href"), location.href);
        var current = new URL(location.href);
        var path = url.pathname.replace(/\/$/, "") + "/";
        return /^https?:$/.test(url.protocol) && url.origin === current.origin && !url.search && !url.hash &&
          (homepageRootPathname(url.pathname) || url.pathname === current.pathname || current.pathname.startsWith(path));
      } catch (_error) { return false; }
    })) return false;
    var outside = node.cloneNode(true);
    outside.querySelectorAll("a").forEach(function(link) { link.remove(); });
    return /[›»>\/]/u.test(outside.textContent);
  }

  function readabilityDataPublicationExcerpt(article, context, root, sourceIdentities) {
    if (!article || !context || context.publications.size !== 1 || !root) return null;
    var publication = context.publications.values().next().value;
    var introduction = publication.introduction;
    var identity = introduction && sourceIdentities.get(introduction);
    var headingIdentity = sourceIdentities.get(publication.sourceHeading);
    if (!identity || !identity.unique || !identity.visibleText || !headingIdentity || !headingIdentity.unique) return null;
    var headings = Array.from(root.querySelectorAll("h1[id]")).filter(function(node) {
      return node.id === headingIdentity.id && normalizedHeadingText(node) === normalizedHeadingText(publication.sourceHeading);
    });
    var paragraphs = Array.from(root.querySelectorAll("p[id]")).filter(function(node) {
      return node.id === identity.id && normalizeText(node.textContent) === identity.visibleText;
    });
    if (headings.length !== 1 || paragraphs.length !== 1) return null;
    var excerpt = normalizeText(article.excerpt || "");
    var pathExcerpt = Array.from(publication.source.querySelectorAll("div, nav")).some(function(node) {
      return readabilityDataPublicationPathExcerpt(node, publication.sourceHeading, excerpt);
    });
    return pathExcerpt ? readabilityExcerptPrefix(identity.visibleText) : null;
  }
