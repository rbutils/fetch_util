  function controlledListPanelControl(control, root) {
    if (!control || elementVisuallyHidden(control) || control.disabled || control.hasAttribute("disabled") ||
        control.getAttribute("aria-disabled") === "true") return null;

    var role = (control.getAttribute("role") || "").toLowerCase();
    var stateName = role === "tab" ? "aria-selected" : (role === "checkbox" ? "aria-checked" : "");
    var state = stateName && control.getAttribute(stateName);
    if (!stateName || (state !== "true" && state !== "false")) return null;

    var targetId = normalizeText(control.getAttribute("aria-controls") || "");
    if (!targetId || /\s/.test(targetId)) return null;
    var target = document.getElementById(targetId);
    if (!target || !root.contains(target) || !control.parentElement || !target.parentElement) return null;

    return {
      controlParent: control.parentElement,
      target: target,
      targetParent: target.parentElement,
      selected: state === "true"
    };
  }

  function controlledListPanelRecordShape(node) {
    var recordChildren = Array.prototype.filter.call(node.children || [], function(child) {
      return Array.prototype.some.call(child.querySelectorAll("a[href]"), function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || link.getAttribute("title") || "");
        return !!materializedHttpUrl(link.href) && text.length >= minimumListTitleLength(text);
      });
    });
    if (recordChildren.length < 3) return "";
    var recordTag = recordChildren[0].tagName;
    if (!recordChildren.every(function(child) { return child.tagName === recordTag; })) return "";
    return node.tagName + ">" + recordTag;
  }

  function controlledListPanelRecordIdentity(node) {
    var keys = [];
    Array.prototype.forEach.call(node.children || [], function(child) {
      Array.prototype.some.call(child.querySelectorAll("a[href]"), function(link) {
        var text = normalizeText(link.textContent || link.getAttribute("aria-label") || link.getAttribute("title") || "");
        var url = materializedHttpUrl(link.href);
        if (!url || text.length < minimumListTitleLength(text)) return false;
        keys.push(JSON.stringify([listCanonicalKey(url), text, normalizeText(child.textContent || "")]));
        return true;
      });
    });
    return keys.length >= 3 ? JSON.stringify(keys) : "";
  }

  function controlledListDirectChild(node, target) {
    while (node && node.parentElement !== target) node = node.parentElement;
    return node && node.parentElement === target ? node : null;
  }

  function controlledListPaginationEvidence(target, globallyVisible, pages) {
    var controls = Array.prototype.filter.call(
      target.querySelectorAll("button[aria-current], [role='button'][aria-current]"),
      function(control) {
        if (control.disabled || control.hasAttribute("disabled") || control.getAttribute("aria-disabled") === "true") return false;
        var hidden = globallyVisible ? elementVisuallyHidden(control) : elementVisuallyHiddenWithin(control, target);
        return !hidden;
      }
    );
    if (controls.length !== pages.length || !controls.length) return false;

    var pagerParent = controls[0].parentElement;
    if (!pagerParent || pagerParent === target || !controls.every(function(control) {
      return control.parentElement === pagerParent;
    })) return false;
    var pagerBranch = controlledListDirectChild(pagerParent, target);
    if (!pagerBranch || Array.prototype.some.call(pagerBranch.querySelectorAll("a[href]"), function(link) {
      return !!materializedHttpUrl(link.href);
    })) return false;

    var children = Array.prototype.slice.call(target.children || []);
    var pageIndexes = pages.map(function(page) { return children.indexOf(page); }).sort(function(left, right) {
      return left - right;
    });
    if (pageIndexes.some(function(index, position) {
      return index < 0 || (position > 0 && index !== pageIndexes[position - 1] + 1);
    })) return false;
    var pagerIndex = children.indexOf(pagerBranch);
    var intervening;
    if (pagerIndex < pageIndexes[0]) intervening = children.slice(pagerIndex + 1, pageIndexes[0]);
    else if (pagerIndex > pageIndexes[pageIndexes.length - 1]) {
      intervening = children.slice(pageIndexes[pageIndexes.length - 1] + 1, pagerIndex);
    } else return false;
    if (!intervening.every(function(child) { return elementVisuallyHiddenWithin(child, target); })) return false;

    var states = controls.map(function(control) {
      return normalizeText(control.getAttribute("aria-current") || "").toLowerCase();
    });
    return states.filter(function(state) { return state !== "false"; }).length === 1 &&
      states.filter(function(state) { return state === "false"; }).length === states.length - 1;
  }

  function controlledListContinuationGroups(target, globallyVisible) {
    var groups = Object.create(null);
    Array.prototype.forEach.call(target.children || [], function(child) {
      var shape = controlledListPanelRecordShape(child);
      if (!shape) return;
      var group = groups[shape] || { visible: [], hidden: [] };
      var collection = elementVisuallyHiddenWithin(child, target) ? group.hidden : group.visible;
      collection.push(child);
      groups[shape] = group;
    });

    var continuations = Object.create(null);
    Object.keys(groups).forEach(function(shape) {
      var group = groups[shape];
      var visibleIdentities = group.visible.map(controlledListPanelRecordIdentity).filter(Boolean);
      var hidden = group.hidden.filter(function(page) {
        var identity = controlledListPanelRecordIdentity(page);
        return identity && visibleIdentities.indexOf(identity) === -1;
      });
      var pages = group.visible.concat(hidden);
      if (group.visible.length && hidden.length >= 2 && controlledListPaginationEvidence(target, globallyVisible, pages)) {
        continuations[shape] = hidden;
      }
    });
    return continuations;
  }

  function controlledListPanelRoots(root) {
    if (!root || !root.querySelectorAll) return [];
    var groups = [];
    Array.prototype.forEach.call(root.querySelectorAll("[role='tab'][aria-controls], [role='checkbox'][aria-controls]"), function(control) {
      var entry = controlledListPanelControl(control, root);
      if (!entry || entry.controlParent === document.body || entry.targetParent === document.body) return;
      var group = groups.find(function(candidate) {
        return candidate.controlParent === entry.controlParent && candidate.targetParent === entry.targetParent;
      });
      if (!group) {
        group = { controlParent: entry.controlParent, targetParent: entry.targetParent, entries: [] };
        groups.push(group);
      }
      if (!group.entries.some(function(candidate) { return candidate.target === entry.target; })) group.entries.push(entry);
    });

    var roots = [];
    groups.forEach(function(group) {
      if (group.entries.length < 2) return;
      var active = group.entries.some(function(entry) {
        return entry.selected && !elementVisuallyHidden(entry.target);
      });
      var inactive = group.entries.some(function(entry) {
        return !entry.selected && elementVisuallyHidden(entry.target);
      });
      if (!active || !inactive) return;
      var activeContinuationShapes = Object.create(null);
      group.entries.forEach(function(entry) {
        if (!entry.selected || elementVisuallyHidden(entry.target)) return;
        var continuations = controlledListContinuationGroups(entry.target, true);
        Object.keys(continuations).forEach(function(shape) {
          activeContinuationShapes[shape] = true;
          continuations[shape].forEach(function(continuation) {
            if (roots.indexOf(continuation) === -1) roots.push(continuation);
          });
        });
      });
      group.entries.forEach(function(entry) {
        if (entry.selected || !elementVisuallyHidden(entry.target)) return;
        if (roots.indexOf(entry.target) === -1) roots.push(entry.target);
        var continuations = controlledListContinuationGroups(entry.target, false);
        Object.keys(continuations).forEach(function(shape) {
          if (!activeContinuationShapes[shape]) return;
          continuations[shape].forEach(function(continuation) {
            if (roots.indexOf(continuation) === -1) roots.push(continuation);
          });
        });
      });
    });
    return roots.sort(function(left, right) {
      return left.compareDocumentPosition(right) & 2 ? 1 : -1;
    });
  }

  function controlledListPanelAdditions(items, representedItems) {
    var representedKeys = (representedItems || []).map(sameRootListRecordKey);
    var represented = Object.create(null);
    representedKeys.forEach(function(key) { represented[key] = true; });
    var representedIndex = 0;
    var additions = [];
    var ordered = (items || []).every(function(item) {
      var key = sameRootListRecordKey(item);
      if (representedIndex < representedKeys.length && key === representedKeys[representedIndex]) {
        representedIndex += 1;
        return true;
      }
      if (representedIndex < representedKeys.length) return false;
      if (!represented[key]) additions.push(item);
      return true;
    });
    return ordered && representedIndex === representedKeys.length ? additions : null;
  }

  function controlledListMaterializedRecordSequence(items) {
    return (items || []).filter(function(item) {
      return !!materializedHttpUrl(item && item.url);
    }).map(sameRootListRecordKey);
  }

  function controlledListMaterializedSequenceCoveredBy(items, ownerItems) {
    var sequence = controlledListMaterializedRecordSequence(items);
    var ownerSequence = controlledListMaterializedRecordSequence(ownerItems);
    if (sequence.length < 3 || ownerSequence.length < sequence.length) return false;

    var sequenceIndex = 0;
    ownerSequence.forEach(function(record) {
      if (record === sequence[sequenceIndex]) sequenceIndex += 1;
    });
    return sequenceIndex === sequence.length;
  }

  function listMarkdownWithControlledPanels(content, metadata, currentMarkdown) {
    if (!content || content.contentType !== "list") return null;
    var pageTitles = [metadata.title, document.title];
    var ordinary = content.listExtraction;
    if (!ordinary && content.listSourceNode && content.listSourceItems) {
      var sourceExtraction = buildListExtraction(content.listSourceNode, pageTitles);
      if (controlledListMaterializedSequenceCoveredBy(sourceExtraction.items, content.listSourceItems)) ordinary = sourceExtraction;
    }
    if (!ordinary || materializedListItemCount(ordinary.items) < 3) return null;

    var preservedRoots = controlledListPanelRoots(ordinary.sourceNode);
    if (!preservedRoots.length) return null;
    var expanded = buildListExtraction(ordinary.sourceNode, pageTitles, { preservedRoots: preservedRoots });
    var additions = controlledListPanelAdditions(expanded.items, ordinary.items);
    if (!additions) return null;
    additions = additions.filter(function(item) {
      return item.card && item.card.closest("[data-fetchutil-controlled-list-panel='true']");
    });
    if (materializedListItemCount(additions) < 3) return null;

    var additionalMarkdown = listMarkdown(additions);
    if (!additionalMarkdown) return null;
    return [(currentMarkdown || content.markdown || content.textContent || "").trim(), additionalMarkdown].filter(Boolean).join("\n\n");
  }
