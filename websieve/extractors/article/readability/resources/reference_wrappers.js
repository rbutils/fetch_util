  function readabilityOwnedReferenceWrappers(root, sourceClones) {
    var blocks = new WeakSet();
    var owners = new Map();
    var ownerSelector = "main, article, [role='main'], [itemprop~='articleBody']";
    var excluded = "nav, footer, aside, form, button, details:not([open]), " +
      "[role='navigation'], [role='banner'], [role='complementary'], " +
      "[role='dialog'], [role='toolbar'], [role='menu']";
    function ownsVisible(node, owner) {
      var mapped = sourceClones.get(node);
      return node.closest(ownerSelector) === owner && mapped && root.contains(mapped) &&
        !node.closest(excluded) && !elementSubtreeHidden(node) && !!normalizeText(mapped.textContent);
    }
    function contentOwner(owner) {
      if (owners.has(owner)) return owners.get(owner);
      var mapped = sourceClones.get(owner);
      var valid = mapped && root.contains(mapped) && !owner.closest(excluded) &&
        !elementSubtreeHidden(owner) &&
        Array.from(owner.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(heading) {
          return ownsVisible(heading, owner);
        });
      owners.set(owner, !!valid);
      return !!valid;
    }
    function headingContext(source, owner) {
      var header = source.closest("header");
      if (header && owner.localName !== "article" &&
          !owner.matches("[itemprop~='articleBody']")) return false;
      if (Array.from(source.querySelectorAll("h1, h2, h3, h4, h5, h6")).some(function(heading) {
        return ownsVisible(heading, owner);
      })) return true;
      var parent = source.parentElement;
      return parent && (parent.localName === "section" || parent === header) && Array.from(parent.children).some(function(heading) {
        return /^h[1-6]$/.test(heading.localName) && ownsVisible(heading, owner);
      });
    }
    function mappedResourceTables(source, clone) {
      var sourceTables = Array.from(source.querySelectorAll("table")).filter(function(table) {
        return !elementSubtreeHidden(table);
      });
      var tables = Array.from(clone.querySelectorAll("table"));
      if (tables.length !== sourceTables.length) return null;
      var complete = tables.every(function(table, index) {
        var original = sourceTables[index];
        if (sourceClones.get(original) !== table || table.querySelector("table") ||
            !Array.from(table.querySelectorAll("th")).some(function(cell) { return !!normalizeText(cell.textContent); }) ||
            !Array.from(table.querySelectorAll("td")).some(function(cell) { return !!normalizeText(cell.textContent); })) return false;
        var cells = Array.from(original.querySelectorAll("th, td"));
        var mappedCells = Array.from(table.querySelectorAll("th, td"));
        return cells.length === mappedCells.length && cells.every(function(cell, cellIndex) {
          var mapped = mappedCells[cellIndex];
          return sourceClones.get(cell) === mapped && cell.localName === mapped.localName &&
            !elementSubtreeHidden(cell) && normalizeText(cell.textContent) === normalizeText(mapped.textContent);
        });
      });
      return complete ? tables : null;
    }
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "div" || clone.localName !== "div" || !root.contains(clone) ||
          source.closest(excluded) || elementSubtreeHidden(source)) return;
      var owner = source.closest(ownerSelector);
      if (!owner || !contentOwner(owner) || !headingContext(source, owner)) return;
      var links = Array.from(clone.querySelectorAll("a[href]"));
      if (!links.length || links.some(function(link) { return !normalizeText(link.textContent); })) return;
      var tables = mappedResourceTables(source, clone);
      if (!tables || !readabilityMappedLeadResources(source, clone, sourceClones, true, tables.length > 0)) return;
      blocks.add(clone);
      clone.querySelectorAll("div").forEach(function(descendant) { blocks.add(descendant); });
      tables.forEach(function(table) { blocks.add(table); });
    });
    return blocks;
  }
