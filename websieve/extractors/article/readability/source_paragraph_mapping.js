  function sourceParagraphBreakSegments(clone) {
    var children = Array.from(clone.childNodes);
    var rawSegments = [];
    var current = "";
    var index = 0;

    while (index < children.length) {
      var child = children[index];
      if (child.nodeType === Node.ELEMENT_NODE && child.localName === "br") {
        var runEnd = index;
        while (runEnd < children.length && children[runEnd].nodeType === Node.ELEMENT_NODE &&
               children[runEnd].localName === "br") runEnd += 1;
        var runLength = runEnd - index;
        if (runLength === 2) {
          rawSegments.push(current);
          current = "";
          index = runEnd;
          continue;
        }
        if (runLength > 2) return null;
        current += child.textContent || "";
        index += 1;
        continue;
      }
      current += child.textContent || "";
      index += 1;
    }

    if (!rawSegments.length) return null;
    rawSegments.push(current);
    if (normalizeText(rawSegments.join("")) !== normalizeText(clone.textContent || "")) return null;
    var segments = rawSegments.map(normalizeText);
    if (segments.some(function(segment) { return !segment; })) return null;
    return segments;
  }

  function sourceReaderParagraphOrigin(node, root, sourceByToken, sourceById, marker) {
    var ancestor = node;
    while (ancestor && ancestor !== root) {
      if (ancestor.nodeType === Node.ELEMENT_NODE) {
        var token = ancestor.getAttribute("data-fetchutil-reader-source-paragraph");
        if (token && token.indexOf(marker + ":") === 0) return sourceByToken.get(token) || null;
        var source = sourceById.get(ancestor.getAttribute("id"));
        if (source) return source;
      }
      ancestor = ancestor.parentNode;
    }
    return null;
  }

  function sourceOwnedReaderParagraphIdentitySources(root, sourceClones, sourceIdentities, marker) {
    if (!root || !sourceClones || !sourceIdentities || !marker) return null;
    var sourceByToken = new Map();
    var sourceById = new Map();
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "p" || clone.nodeType !== Node.ELEMENT_NODE) return;
      var identity = sourceIdentities.get(source);
      if (!identity) return;
      var token = clone.getAttribute("data-fetchutil-reader-source-paragraph");
      if (token && token.indexOf(marker + ":") === 0) sourceByToken.set(token, source);
      if (identity.unique) sourceById.set(identity.id, source);
    });

    var selectedNodes = Array.from(root.querySelectorAll("p")).filter(function(node) {
      return !!normalizeText(node.textContent);
    });
    var sources = [];
    var seen = new Set();
    var previousSource = null;
    for (var index = 0; index < selectedNodes.length; index += 1) {
      var source = sourceReaderParagraphOrigin(selectedNodes[index], root, sourceByToken, sourceById, marker);
      if (!source || source.localName !== "p" || elementVisuallyHidden(source) ||
          (seen.has(source) && source !== previousSource)) return null;
      if (!seen.has(source)) {
        seen.add(source);
        sources.push(source);
      }
      previousSource = source;
    }
    if (sources.length < 2 || sources.some(function(source, sourceIndex) {
      return sourceIndex > 0 && !(sources[sourceIndex - 1].compareDocumentPosition(source) & Node.DOCUMENT_POSITION_FOLLOWING);
    })) return null;
    return sources;
  }

  function sourceOwnedReaderSelectedParagraphs(root, sourceClones, sourceIdentities, marker, allowUnmappedEdges) {
    if (!root || !sourceClones || !sourceIdentities || !marker) return null;
    var sourceByToken = new Map();
    var sourceById = new Map();
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "p" || clone.nodeType !== Node.ELEMENT_NODE) return;
      var identity = sourceIdentities.get(source);
      if (!identity) return;
      var token = clone.getAttribute("data-fetchutil-reader-source-paragraph");
      if (token && token.indexOf(marker + ":") === 0) sourceByToken.set(token, source);
      if (identity.unique) sourceById.set(identity.id, source);
    });

    var selectedNodes = Array.from(root.querySelectorAll("p")).filter(function(node) {
      return !!normalizeText(node.textContent);
    });
    if (allowUnmappedEdges && !sourceOwnedReaderHasMultipleMappedParagraphs(
      selectedNodes, root, sourceByToken, sourceById, marker
    )) return null;

    var groups = new Map();
    var unmappedHeaderParagraphs = [];
    var unmappedTrailingParagraphs = [];
    var unmappedParagraphSourcesByText = null;
    var bodyStarted = false;
    var bodyEnded = false;
    var previousSource = null;
    for (var index = 0; index < selectedNodes.length; index += 1) {
      var node = selectedNodes[index];
      var source = sourceReaderParagraphOrigin(node, root, sourceByToken, sourceById, marker);
      if (!source) {
        if (!allowUnmappedEdges) return null;
        if (!unmappedParagraphSourcesByText) {
          unmappedParagraphSourcesByText = sourceOwnedReaderUnmappedParagraphSourcesByText(sourceClones);
        }
        var edgeSource = sourceOwnedReaderUnmappedParagraphSource(node, unmappedParagraphSourcesByText);
        if (!edgeSource) return null;
        var edge = { text: normalizeText(node.textContent), source: edgeSource };
        if (bodyStarted) {
          bodyEnded = true;
          unmappedTrailingParagraphs.push(edge);
        } else {
          unmappedHeaderParagraphs.push(edge);
        }
        continue;
      }
      if (bodyEnded) return null;
      if (source.localName !== "p" || elementVisuallyHidden(source)) return null;
      if (groups.has(source) && source !== previousSource) return null;
      if (!groups.has(source)) groups.set(source, []);
      groups.get(source).push(normalizeText(node.textContent));
      previousSource = source;
      bodyStarted = true;
    }

    var sources = Array.from(groups.keys());
    if (sources.length < 2) return null;
    for (var sourceIndex = 1; sourceIndex < sources.length; sourceIndex += 1) {
      if (!(sources[sourceIndex - 1].compareDocumentPosition(sources[sourceIndex]) & Node.DOCUMENT_POSITION_FOLLOWING)) {
        return null;
      }
    }

    for (var groupIndex = 0; groupIndex < sources.length; groupIndex += 1) {
      var sourceNode = sources[groupIndex];
      var identity = sourceIdentities.get(sourceNode);
      var actual = groups.get(sourceNode);
      var segments = identity && identity.breakSegments;
      if (!identity || !identity.visibleText) return null;
      if (segments && actual.length === segments.length) {
        for (var segmentIndex = 0; segmentIndex < segments.length; segmentIndex += 1) {
          if (actual[segmentIndex] !== segments[segmentIndex]) return null;
        }
      } else if (actual.length !== 1 || actual[0] !== identity.visibleText) return null;
    }

    return allowUnmappedEdges
      ? {
          sourceParagraphs: sources,
          unmappedHeaderParagraphs: unmappedHeaderParagraphs,
          unmappedTrailingParagraphs: unmappedTrailingParagraphs
        }
      : sources;
  }

  function sourceOwnedReaderHasMultipleMappedParagraphs(nodes, root, sourceByToken, sourceById, marker) {
    var sources = new Set();
    for (var index = 0; index < nodes.length; index += 1) {
      var source = sourceReaderParagraphOrigin(nodes[index], root, sourceByToken, sourceById, marker);
      if (!source || source.localName !== "p" || elementVisuallyHidden(source)) continue;
      sources.add(source);
      if (sources.size >= 2) return true;
    }
    return false;
  }

  function sourceOwnedReaderUnmappedParagraphSourcesByText(sourceClones) {
    var sourcesByText = new Map();
    sourceClones.forEach(function(clone, source) {
      if (!clone || source.nodeType !== Node.ELEMENT_NODE || source.localName === "p" ||
          elementVisuallyHidden(source) || source.querySelector("p")) return;
      var text = normalizeText(source.textContent || "");
      if (!text) return;
      if (!sourcesByText.has(text)) sourcesByText.set(text, []);
      sourcesByText.get(text).push(source);
    });
    return sourcesByText;
  }

  function sourceOwnedReaderUnmappedParagraphSource(node, sourcesByText) {
    var text = normalizeText(node.textContent || "");
    var candidates = sourcesByText.get(text) || [];
    var sourceCandidate = null;
    for (var index = 0; index < candidates.length; index += 1) {
      var source = candidates[index];
      if (!sourceCandidate) {
        sourceCandidate = source;
      } else if (sourceCandidate.contains(source)) {
        sourceCandidate = source;
      } else if (!source.contains(sourceCandidate)) {
        return null;
      }
    }
    return sourceCandidate;
  }
