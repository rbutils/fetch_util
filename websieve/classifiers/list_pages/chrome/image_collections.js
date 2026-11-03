  var listImageCollectionEventOwners = new WeakSet();

  function listImageCollectionEventSources(root) {
    return [root].concat(Array.from(root.querySelectorAll("*"))).filter(function(node) {
      return !!node.closest("main, [role='main']") && (listImageCollectionEventOwners.has(node) ||
        Array.from(node.attributes || []).some(function(attribute) { return /^on/i.test(attribute.name); }));
    });
  }

  function preserveListImageCollectionEvents(sources, sourceToVisible, visibleToCleaned, root) {
    sources.forEach(function(source) {
      var visible = sourceToVisible.get(source);
      var cleaned = visible && visibleToCleaned.get(visible);
      if (cleaned && (cleaned === root || root.contains(cleaned))) listImageCollectionEventOwners.add(cleaned);
    });
  }

  function listImageCollectionContext(node) {
    if (!node || node.nodeType !== 1 || listCardNodeHidden(node)) return false;
    if (!node.closest("main, [role='main']")) return false;
    var interfaces = "a, nav, header, footer, aside, menu, form, button, input, select, textarea, option, dialog, " +
      "pre, code, table, details, script, style, template, iframe, [role='navigation'], [role='menu'], " +
      "[role='menubar'], [role='menuitem'], [role='menuitemcheckbox'], [role='menuitemradio'], [role='toolbar'], " +
      "[role='banner'], [role='contentinfo'], [role='button'], [role='link'], [role='tab'], [role='tablist'], " +
      "[role='tabpanel'], [role='dialog'], [role='alertdialog'], [role='checkbox'], [role='radio'], [role='switch'], " +
      "[role='listbox'], [role='option'], [role='combobox'], [role='tree'], [role='treeitem'], [role='textbox'], " +
      "[role='searchbox'], [role='slider'], [role='spinbutton'], [role='scrollbar'], [role='tooltip'], " +
      "[contenteditable]:not([contenteditable='false']), [tabindex], [aria-controls], [aria-haspopup], " +
      "[aria-expanded], [aria-modal='true']";
    if (node.closest(interfaces)) return false;
    for (var current = node; current; current = current.parentElement) {
      if (listImageCollectionEventOwners.has(current) || Array.from(current.attributes || []).some(function(attribute) {
        return /^on/i.test(attribute.name);
      })) return false;
      if (current.matches("main, [role='main']")) return true;
    }
    return false;
  }

  function listImageCollectionChildren(node) {
    var children = [];
    for (var child of node.childNodes) {
      if (child.nodeType === 8) continue;
      if (child.nodeType === 3) {
        if (normalizeText(child.nodeValue)) return null;
        continue;
      }
      if (child.nodeType !== 1) return null;
      if (!listCardNodeHidden(child)) children.push(child);
    }
    return children;
  }

  function listUnlinkedImageRecord(node) {
    if (!node.matches("div, article, li") || !listImageCollectionContext(node)) return false;
    var images = [];
    var text = [];
    function visit(current) {
      if (current.nodeType === 8) return true;
      if (current.nodeType === 3) {
        text.push(current.nodeValue);
        return true;
      }
      if (current.nodeType !== 1) return false;
      if (listCardNodeHidden(current)) return true;
      if (!listImageCollectionContext(current) || current.namespaceURI !== "http://www.w3.org/1999/xhtml") return false;
      if (current.matches("img")) {
        if (!materializedHttpUrl(current.getAttribute("src") || "")) return false;
        images.push(current);
        return true;
      }
      if (!current.matches("div, article, li, span, p")) return false;
      return Array.from(current.childNodes).every(visit);
    }
    if (!visit(node)) return false;
    var reading = normalizeText(text.join(" "));
    return images.length === 1 && !!reading && !genericListControlText(reading);
  }

  function listImageCollectionLabel(node) {
    var text = [];
    function visit(current) {
      if (current.nodeType === 8) return true;
      if (current.nodeType === 3) {
        text.push(current.nodeValue);
        return true;
      }
      if (current.nodeType !== 1) return false;
      if (listCardNodeHidden(current)) return true;
      if (!listImageCollectionContext(current) || current.namespaceURI !== "http://www.w3.org/1999/xhtml") return false;
      if (current.matches("img")) return true;
      if (!current.matches("div, span, p, h2, h3, h4, h5, h6")) return false;
      return Array.from(current.childNodes).every(visit);
    }
    if (!visit(node)) return false;
    var reading = normalizeText(text.join(" "));
    return !!reading && !genericListControlText(reading);
  }

  function completeListImageCollection(node) {
    if (!node.matches("div, section, article, li") || !listImageCollectionContext(node)) return false;
    var children = listImageCollectionChildren(node);
    if (!children || children.length !== 2 || !listImageCollectionLabel(children[0])) return false;
    var collection = children[1];
    if (!collection.matches("div, ul, ol") || !listImageCollectionContext(collection)) return false;
    var records = listImageCollectionChildren(collection);
    if (!records || records.length < 2) return false;
    return records.every(function(record) {
      return record.tagName === records[0].tagName && listUnlinkedImageRecord(record);
    });
  }

  function listOwnedImageCollectionNode(node) {
    if (!listImageCollectionContext(node)) return false;
    var main = node.closest("main, [role='main']");
    for (var current = node; current && current !== main; current = current.parentElement) {
      if (completeListImageCollection(current)) return true;
    }
    return false;
  }
