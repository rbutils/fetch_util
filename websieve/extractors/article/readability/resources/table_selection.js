  function readabilityDataTableInterfaces() {
    return "nav, aside, footer, form, button, [role='navigation'], [role='complementary'], " +
      "[role='dialog'], [role='menu'], [role='toolbar'], [role='button']";
  }

  function readabilityMappedDataTable(source, clone, sourceClones) {
    if (source.localName !== "table" || clone.localName !== "table" ||
        source.closest(readabilityDataTableInterfaces()) || elementSubtreeHidden(source) ||
        source.closest("pre, code, kbd, samp, details:not([open])") ||
        source.querySelector("table") || clone.querySelector("table")) return false;
    var rows = Array.from(clone.rows);
    if (!rows.length || rows[0].cells.length < 2 || !rows.some(function(row) {
      return Array.from(row.cells).some(function(cell) { return cell.localName === "td"; });
    }) || !Array.from(rows[0].cells).every(function(cell) {
      return cell.localName === "th" && !!normalizeText(cell.textContent);
    })) return false;

    var originals = Array.from(source.rows).filter(function(row) {
      var mapped = sourceClones.get(row);
      return mapped && clone.contains(mapped);
    });
    return originals.length === rows.length && originals.every(function(row, index) {
      var mapped = rows[index];
      if (sourceClones.get(row) !== mapped || row.cells.length !== mapped.cells.length) return false;
      return Array.from(row.cells).every(function(cell, column) {
        var retained = mapped.cells[column];
        if (sourceClones.get(cell) !== retained || cell.localName !== retained.localName ||
            !["rowspan", "colspan", "scope", "headers"].every(function(attribute) {
              return cell.getAttribute(attribute) === retained.getAttribute(attribute);
            })) return false;
        var walker = source.ownerDocument.createTreeWalker(cell, NodeFilter.SHOW_TEXT);
        var text = [];
        while (walker.nextNode()) {
          var part = sourceClones.get(walker.currentNode);
          if (!part || !retained.contains(part)) continue;
          if (part.nodeValue !== walker.currentNode.nodeValue) return false;
          text.push(walker.currentNode.nodeValue);
        }
        return text.join("") === retained.textContent;
      });
    });
  }

  function readabilityDataPublicationOwner(source, root, sourceClones, metadata, sourceIdentities) {
    var canonical = document.querySelectorAll("link[rel~='canonical' i][href]");
    if (canonical.length !== 1 || materializedHttpUrl(canonical[0].getAttribute("href")) !== location.href) return null;
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading) && !heading.closest("table, " + readabilityDataTableInterfaces());
    });
    if (headings.length !== 1) return null;
    var heading = headings[0];
    var title = normalizedHeadingText(heading);
    var identity = sourceIdentities.get(heading);
    var mappedHeading = sourceClones.get(heading);
    var declarations = [metadata && metadata.title, document.title].map(normalizeText);
    var titleMatches = declarations.every(function(value) {
      return value === title || (value.startsWith(title) && /^\s*[|·:–—-]\s*\S/u.test(value.substring(title.length)));
    });
    if (!title || !titleMatches || !identity || !identity.unique ||
        !mappedHeading || !root.contains(mappedHeading) ||
        !(heading.compareDocumentPosition(source) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
    for (var owner = source.parentElement; owner && owner !== document.body; owner = owner.parentElement) {
      if (!owner.contains(heading)) continue;
      var mappedOwner = sourceClones.get(owner);
      if (!/^(div|section|article|main)$/.test(owner.localName) || !mappedOwner || !root.contains(mappedOwner) ||
          owner.closest(readabilityDataTableInterfaces()) || elementSubtreeHidden(owner)) return null;
      var hasProse = Array.from(owner.querySelectorAll("p")).some(function(paragraph) {
        var mapped = sourceClones.get(paragraph);
        return mapped && mappedOwner.contains(mapped) && !paragraph.closest("table, " + readabilityDataTableInterfaces()) &&
          !elementSubtreeHidden(paragraph) && readerSectionParagraphNarrative(mapped);
      });
      return hasProse ? { source: owner, root: mappedOwner, sourceHeading: heading, heading: mappedHeading } : null;
    }
    return null;
  }

  function readabilityDataPublicationResources(root, sourceClones, publications, blocks) {
    var excluded = readabilityDataTableInterfaces() + ", pre, code, kbd, samp, details:not([open])";
    var owners = Array.from(publications.values());
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "div" || clone.localName !== "div" || !root.contains(clone) ||
          source.closest(excluded) || elementSubtreeHidden(source)) return;
      var owned = owners.some(function(publication) {
        return publication.source.contains(source) && publication.root.contains(clone);
      });
      if (owned && readabilityMappedLeadResources(source, clone, sourceClones, true)) blocks.add(clone);
    });
  }

  function preserveReadabilityDataTableSelection(reader, root, sourceClones, metadata, sourceIdentities, headingRoles) {
    var tables = new WeakMap();
    var headings = new WeakSet();
    var blocks = new WeakSet();
    var publications = new Map();
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "table" || !root.contains(clone) ||
          !readabilityMappedDataTable(source, clone, sourceClones)) return;
      var publication = readabilityDataPublicationOwner(source, root, sourceClones, metadata, sourceIdentities);
      tables.set(clone, publication ? publication.root : clone);
      var child = clone;
      for (var parent = source.parentElement; parent; parent = parent.parentElement) {
        var mapped = sourceClones.get(parent);
        if (parent.localName !== "div" || !mapped || mapped.localName !== "div" ||
            !root.contains(mapped) || child.parentElement !== mapped ||
            mapped.children.length !== 1 || mapped.firstElementChild !== child ||
            normalizeText(mapped.textContent) !== normalizeText(child.textContent) ||
            parent.closest(readabilityDataTableInterfaces()) || elementSubtreeHidden(parent)) break;
        blocks.add(mapped);
        child = mapped;
      }
      if (publication) {
        publications.set(publication.source, publication);
        headings.add(publication.heading);
        headingRoles.set(publication.sourceHeading, readabilityHeadingRoleSignature(publication.heading));
      }
    });
    readabilityDataPublicationResources(root, sourceClones, publications, blocks);
    publications.forEach(function(publication) {
      readabilityDataPublicationHeader(publication, sourceClones, sourceIdentities, blocks);
    });

    var setNodeTag = reader._setNodeTag;
    reader._setNodeTag = function(node, tag) {
      if (tag === "DIV" && node && node.localName === "table" && tables.has(node)) return node;
      return setNodeTag.apply(this, arguments);
    };
    var ancestors = reader._getNodeAncestors;
    reader._getNodeAncestors = function(node, maxDepth) {
      var result = ancestors.apply(this, arguments);
      if (typeof maxDepth !== "number" || !node || !node.closest) return result;
      var table = node.closest("table");
      var owner = table && tables.get(table);
      if (!owner || !root.contains(owner) || !owner.contains(node)) return result;
      return [owner].concat(result.filter(function(ancestor) {
        return ancestor !== owner && !owner.contains(ancestor);
      }));
    };
    var duplicateTitle = reader._headerDuplicatesTitle;
    reader._headerDuplicatesTitle = function(node) {
      return headings.has(node) ? false : duplicateTitle.apply(this, arguments);
    };
    return { blocks: blocks, publications: publications };
  }
