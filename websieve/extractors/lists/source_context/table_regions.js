  function listSourceTableColumns(table) {
    if (table.querySelector("table")) return false;
    var rows = Array.from(table.rows).filter(function(row) { return row.closest("table") === table; });
    if (rows.length < 2) return false;
    var headers = Array.from(rows[0].cells);
    if (!headers.length || headers.some(function(cell) {
      return cell.tagName !== "TH" || cell.colSpan !== 1 || cell.rowSpan !== 1;
    })) return false;
    var destinations = headers.map(function(cell) {
      var links = cell.querySelectorAll("a[href]");
      var title = normalizeText(cell.textContent);
      if (links.length !== 1 || !title || genericListControlText(title) ||
          normalizeText(links[0].textContent) !== title) return null;
      return materializedHttpUrl(links[0].getAttribute("href"));
    });
    if (destinations.some(function(destination) { return !destination; })) return false;
    var hasImage = false;
    return rows.slice(1).every(function(row) {
      var cells = Array.from(row.cells);
      return cells.length === headers.length && cells.every(function(cell, index) {
        if (cell.tagName !== "TD" || cell.colSpan !== 1 || cell.rowSpan !== 1) return false;
        var links = Array.from(cell.querySelectorAll("a[href]"));
        if (!links.length || !links.every(function(link) {
          return materializedHttpUrl(link.getAttribute("href")) === destinations[index];
        })) return false;
        if (cell.querySelector("img[src]")) hasImage = true;
        return true;
      });
    }) && hasImage;
  }

  function listSourceTableContext(sourceRoot) {
    if (!sourceRoot || !sourceRoot.querySelector("table")) return null;
    return withSourceVisibilityRead(function() {
      var mains = Array.from(document.querySelectorAll("main, [role~='main' i]")).filter(function(main) {
        return !elementSubtreeHidden(main);
      });
      if (mains.length !== 1 || (sourceRoot !== mains[0] && !sourceRoot.contains(mains[0]))) return null;
      var main = mains[0];
      var interfaceSelector = [
        "nav, aside, header, footer, form, menu, dialog, details",
        "[role~='navigation' i], [role~='complementary' i], [role~='menu' i], [role~='toolbar' i]",
        "[role~='button' i], [role~='dialog' i], [role~='tab' i], [role~='search' i]",
        "[role~='grid' i], [role~='treegrid' i], [role~='listbox' i], [role~='combobox' i]"
      ].join(", ");
      if (main.closest(interfaceSelector) || !main.querySelector("table th a[href]") ||
          !main.querySelector("table td img[src]")) return null;
      var sourceClones = new Map();
      var visible = visibilityPrunedClone(main, document, sourceClones);
      var allowed = /^(MAIN|DIV|SECTION|P|H[1-6]|TABLE|CAPTION|THEAD|TBODY|TFOOT|TR|TH|TD|A|IMG|SPAN|BR|EM|STRONG|B|I|SMALL|SUB|SUP)$/;
      if (Array.from(visible.querySelectorAll("*")).some(function(node) { return !allowed.test(node.tagName); })) return null;
      if (visible.querySelector(interfaceSelector)) return null;
      var paragraphs = Array.from(visible.querySelectorAll("p")).filter(function(paragraph) {
        return !paragraph.closest("table") && !!normalizeText(paragraph.textContent);
      });
      if (!paragraphs.length) return null;
      if (Array.from(visible.querySelectorAll("a[href]")).some(function(link) {
        return !materializedHttpUrl(link.getAttribute("href"));
      }) || Array.from(visible.querySelectorAll("img")).some(function(image) {
        // Richer declarations keep their existing serializers rather than being
        // reduced to the table renderer's SRC/ALT representation.
        return !materializedHttpUrl(image.getAttribute("src")) || Array.from(image.attributes).some(function(attribute) {
          return !/^(src|alt)$/.test(attribute.name);
        });
      })) return null;
      var tables = Array.from(visible.querySelectorAll("table"));
      if (!tables.length || !tables.every(listSourceTableColumns)) return null;
      var originals = new Map();
      sourceClones.forEach(function(clone, source) { originals.set(clone, source); });
      return { main: main, visible: visible, originals: originals };
    });
  }

  function listSourceContextAttributes(node) {
    return Array.from(node.attributes).map(function(attribute) {
      var value = attribute.value;
      if (/^(href|src)$/.test(attribute.name)) value = materializedHttpUrl(value) || value;
      return [attribute.name, value];
    }).sort(function(left, right) { return left[0].localeCompare(right[0]); });
  }

  function listMappedTableContext(context, root) {
    if (!context || !context.mapping) return null;
    var proof = context.proof;
    var main = context.mapping.get(proof.main);
    if (!main || (main !== root && !root.contains(main))) return null;
    var expected = [proof.visible].concat(Array.from(proof.visible.querySelectorAll("*")));
    var complete = expected.every(function(node) {
      var source = proof.originals.get(node);
      var clone = source && context.mapping.get(source);
      if (!clone || clone.tagName !== node.tagName ||
          JSON.stringify(listSourceContextAttributes(clone)) !== JSON.stringify(listSourceContextAttributes(node))) return false;
      var children = Array.from(node.childNodes).filter(function(child) { return child.nodeType === 1 || child.nodeType === 3; });
      var clonedChildren = Array.from(clone.childNodes).filter(function(child) { return child.nodeType === 1 || child.nodeType === 3; });
      return clonedChildren.length === children.length && children.every(function(child, index) {
        var mappedChild = clonedChildren[index];
        return child.nodeType === 3 ? mappedChild.nodeType === 3 && mappedChild.nodeValue === child.nodeValue :
          context.mapping.get(proof.originals.get(child)) === mappedChild;
      });
    });
    if (!complete) return null;
    var remainder = root.cloneNode(true);
    var mapped = main === root ? remainder : remainder.querySelector("main, [role~='main' i]");
    if (!mapped) return null;
    mapped.remove();
    if (main !== root && (normalizeText(remainder.textContent) ||
        remainder.querySelector("a[href], img, table, p, h1, h2, h3, h4, h5, h6, pre, blockquote, svg, video, audio"))) return null;
    return main;
  }

  function applyListSourceTableContext(best) {
    if (!listMappedTableContext(best.sourceOwnedTableContext, best.root)) return;
    var markdown = markdownFor(best.root.innerHTML).trim();
    if (markdown) best.markdown = markdown;
  }
