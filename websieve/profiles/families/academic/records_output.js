  function scholarlyRecordOwnedNodes(owner, metadataRoot, abstractNode, bodyRoots) {
    var nodes = [];
    var bibliography = Array.prototype.filter.call(metadataRoot.querySelectorAll("[role='doc-bibliography'], [itemprop='backstory']"), function(node) {
      return scholarlyRecordVisible(node) && !bodyRoots.some(function(body) { return body === node || body.contains(node); });
    });
    bibliography.forEach(function(node) { nodes.push(node); });
    [".authors", "[itemprop='author']", "[rel='author']", ".dateline", ".metatable", "[class*='published' i]", "[class*='doi' i]", "p, div, span, li"].forEach(function(selector) {
      metadataRoot.querySelectorAll(selector).forEach(function(node) {
        if (!scholarlyRecordVisible(node) || nodes.some(function(existing) { return existing === node || existing.contains(node) || node.contains(existing); })) return;
        if (node === abstractNode || node.contains(abstractNode) || abstractNode.contains(node)) return;
        if (bodyRoots.some(function(body) { return body === node || body.contains(node) || node.contains(body); })) return;
        if (selector === "p, div, span, li" && !/^(?:published in|doi|publication date|submitted|last revised|subjects|comments|cite as)\s*:/i.test(normalizeText(node.textContent || ""))) return;
        nodes.push(node);
      });
    });
    ["[role='doc-bibliography']"].forEach(function(selector) {
      owner.querySelectorAll(selector).forEach(function(node) {
        if (!scholarlyRecordVisible(node) || nodes.some(function(existing) { return existing === node || existing.contains(node) || node.contains(existing); })) return;
        if (node === abstractNode || node.contains(abstractNode) || abstractNode.contains(node)) return;
        if (bodyRoots.some(function(body) { return body === node || body.contains(node) || node.contains(body); })) return;
        nodes.push(node);
      });
    });
    scholarlyRecordLinkedRoots(owner).forEach(function(node) {
      if (!nodes.some(function(existing) { return existing === node || existing.contains(node) || node.contains(existing); })) nodes.push(node);
    });
    return nodes;
  }

  function scholarlyRecordLinkedRoots(owner) {
    var pathKey = normalizeText((location.pathname || "").split("/").filter(Boolean).pop() || "").replace(/v\d+$/i, "");
    try {
      pathKey = decodeURIComponent(pathKey);
    } catch (_error) {
      return [];
    }
    if (!pathKey) return [];
    var context = owner.closest("main, [role='main']") || owner.parentElement;
    if (!context) return [];
    var matchesPath = function(link) {
      try {
        var segments = new URL(link.getAttribute("href"), location.href).pathname.split("/").filter(Boolean).map(decodeURIComponent);
        return segments.some(function(segment) {
          return segment === pathKey || (segment.indexOf(pathKey) === 0 && /^v\d+$/i.test(segment.slice(pathKey.length)));
        });
      } catch (_error) {
        return false;
      }
    };
    var candidates = [];
    Array.prototype.forEach.call(context.querySelectorAll("a[href]"), function(link) {
      if (!matchesPath(link)) return;
      var node = link.parentElement;
      while (node && node !== context) {
        if (node.matches("div, section, ul, ol, table, tbody, tr, td, li") &&
            node !== owner && !node.contains(owner) &&
            scholarlyRecordVisible(node) && !node.closest("aside, nav, footer, [role='navigation'], [role='complementary'], [class*='recommend' i], [id*='recommend' i], [class*='sidebar' i], [id*='sidebar' i]")) {
          var links = node.querySelectorAll("a[href]");
          var recordLinks = Array.prototype.filter.call(links, matchesPath);
          var linkedRights = Array.prototype.every.call(links, function(item) {
            return matchesPath(item) || item.rel === "license" || item.getAttribute("itemprop") === "license" ||
              /^(?:view )?license$/i.test(normalizeText(item.textContent || "")) || /license|rights to this article/i.test(item.getAttribute("title") || "");
          });
          if (recordLinks.length >= 2 && linkedRights) candidates.push(node);
        }
        node = node.parentElement;
      }
    });
    return candidates.filter(function(node, index) {
      return candidates.indexOf(node) === index && !candidates.some(function(other) {
        return other !== node && other.contains(node);
      });
    });
  }

  function scholarlyRecordSourceOrder(left, right, abstractNode) {
    if (left === right) return 0;
    if (left === abstractNode && right.contains(abstractNode)) return -1;
    if (right === abstractNode && left.contains(abstractNode)) return 1;
    var position = left.compareDocumentPosition(right);
    if (position & Node.DOCUMENT_POSITION_FOLLOWING) return -1;
    if (position & Node.DOCUMENT_POSITION_PRECEDING) return 1;
    return 0;
  }

  function scholarlyRecordAbstractHeading(node) {
    var labels = Array.prototype.map.call(node.querySelectorAll("h1, h2, h3, [role='heading'], [class*='descriptor' i]"), function(label) {
      return normalizeText(label.textContent || "");
    });
    return labels.some(function(label) { return /^(?:abstract|summary)\s*:?$/i.test(label); }) ? "" : "Abstract";
  }

  function scholarlyRecordFrontmatterRoots(owner, primaryAbstract) {
    var frontmatter = primaryAbstract.closest("[data-extent='frontmatter']");
    if (!frontmatter || !owner.contains(frontmatter)) return [];

    var abstracts = scholarlyRecordAbstracts(frontmatter).filter(function(node) {
      return node !== primaryAbstract && node.parentElement === primaryAbstract.parentElement &&
        node.matches("[property='abstract'], [itemprop='abstract'], [role='doc-abstract']") &&
        !node.closest("aside, nav, footer, [role='navigation'], [role='complementary'], [class*='recommend' i], [id*='recommend' i], [class*='sidebar' i], [id*='sidebar' i]");
    });
    var headings = abstracts.map(function(node) {
      var heading = node.querySelector("h1, h2, h3, [role='heading'], [property='name']");
      return { node: node, label: normalizeText(heading && heading.textContent || "") };
    }).filter(function(item) {
      return item.label && !/^(?:abstract|summary)\s*:?$/i.test(item.label) &&
        normalizeText(visibilityPrunedClone(item.node, document).textContent || "").length > 0;
    });

    return headings.filter(function(item) {
      return headings.filter(function(other) { return other.label.toLowerCase() === item.label.toLowerCase(); }).length === 1;
    }).map(function(item) { return item.node; });
  }

  function genericScholarlyArticleContent(metadata) {
    var candidates = scholarlyRecordAbstracts(document).map(function(node) {
      var owner = scholarlyRecordCandidateOwner(node);
      return { abstract: node, owner: owner, text: normalizeText(visibilityPrunedClone(node, document).textContent || "") };
    }).filter(function(candidate) {
      return candidate.owner && candidate.text.length >= 80 && scholarlyRecordIdentity(candidate.owner, candidate.abstract, metadata);
    });
    if (!candidates.length) return null;

    var ownerSet = [];
    candidates.forEach(function(candidate) {
      if (ownerSet.indexOf(candidate.owner) === -1) ownerSet.push(candidate.owner);
    });
    if (ownerSet.length !== 1 || scholarlyRecordOwnersConflict(ownerSet[0])) return null;

    candidates.sort(function(left, right) {
      return scholarlyRecordAbstractScore(right.abstract) - scholarlyRecordAbstractScore(left.abstract) || right.text.length - left.text.length;
    });
    var candidate = candidates[0];
    var bodyRoots = scholarlyRecordBodyRoots(candidate.owner, candidate.abstract);
    var bodyTextLength = bodyRoots.reduce(function(total, node) {
      return total + normalizeText(visibilityPrunedClone(node, document).textContent || "").length;
    }, 0);
    if (bodyTextLength && bodyTextLength < 80) bodyRoots = [];

    var metadataRoot = scholarlyRecordMetadataRoot(candidate.owner, candidate.abstract);
    var ownedNodes = scholarlyRecordOwnedNodes(candidate.owner, metadataRoot, candidate.abstract, bodyRoots);
    var citationTitle = document.querySelector("meta[name='citation_title']");
    var sourceHeadline = scholarlyRecordTitleNode(candidate.owner);
    var title = normalizeText(sourceHeadline && sourceHeadline.textContent || citationTitle && citationTitle.getAttribute("content") || metadata.title || document.title || "")
      .replace(/^Title:\s*/i, "").replace(/^\[[^\]]+\]\s*/, "");
    if (!sourceHeadline && !citationTitle && /\s\|\s/.test(title)) title = normalizeText(title.split(/\s\|\s/)[0]);

    var excerpt = candidate.text.replace(/^Abstract:\s*/i, "");
    var frontmatterRoots = scholarlyRecordFrontmatterRoots(candidate.owner, candidate.abstract);
    var orderedRoots = [candidate.abstract].concat(frontmatterRoots, bodyRoots, ownedNodes);
    orderedRoots = orderedRoots.filter(function(node, index) {
      return orderedRoots.indexOf(node) === index && scholarlyRecordVisible(node);
    });
    orderedRoots.sort(function(left, right) {
      return scholarlyRecordSourceOrder(left, right, candidate.abstract);
    });
    var abstractLabel = scholarlyRecordAbstractHeading(candidate.abstract);
    var assembled = assembleScholarlyArticle({
      metadata: Object.assign({}, metadata, {
        title: title,
        byline: scholarlyRecordAuthors(metadataRoot, metadata),
        publishedTime: scholarlyRecordPublishedTime(metadataRoot, metadata)
      }),
      orderedRoots: orderedRoots,
      title: title,
      excerpt: excerpt,
      abstractRootToLabel: abstractLabel ? candidate.abstract : null,
      abstractLabel: abstractLabel,
      preserveFullExcerpt: true,
      visibilityAware: true,
      excludeNodes: [candidate.abstract],
      minTextLength: bodyRoots.length ? 300 : 80
    });
    if (!assembled) return null;
    assembled.excerpt = excerpt || assembled.excerpt;
    return assembled;
  }
