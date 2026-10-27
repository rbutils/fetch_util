function sourceOwnedResourceSectionVisible(node) {
  if (!node || sourceOwnershipInChrome(node) || elementVisuallyHidden(node) ||
      node.closest("button, input, select, textarea, pre, code, [role='button'], [role='dialog'], [role='toolbar']")) return false;
  for (var parent = node; parent; parent = parent.parentElement) {
    if (!parent.matches("details:not([open])")) continue;
    var summary = Array.from(parent.children).find(function(child) { return child.matches("summary"); });
    if (!summary || !summary.contains(node)) return false;
  }
  return true;
}

function sourceOwnedResourceHeading(node) {
  if (!node || !sourceOwnedResourceSectionVisible(node) ||
      !node.matches("div, section, h2, h3, h4, h5, h6")) return null;
  var headings = node.matches("h2, h3, h4, h5, h6") ? [node] : Array.from(node.querySelectorAll("h2, h3, h4, h5, h6"));
  if (headings.length !== 1 || !normalizeText(headings[0].textContent) ||
      normalizeText(node.textContent) !== normalizeText(headings[0].textContent) ||
      node.querySelector("a[href], img, picture, svg, iframe, object, audio, video, form, button, input, select, textarea")) return null;
  return headings[0];
}

function sourceOwnedResourceGroup(node) {
  if (!node || !sourceOwnedResourceSectionVisible(node) || !node.matches("div, section")) return false;
  var visible = visibilityPrunedClone(node, document);
  if (normalizeText(visible.textContent) || !visible.querySelector("a[href] img")) return false;
  return [visible].concat(Array.from(visible.querySelectorAll("*"))).every(function(part) {
    if (part.matches("div, section, span")) {
      return Array.from(part.attributes).every(function(attribute) { return /^(?:class|style)$/.test(attribute.name); });
    }
    if (part.matches("a[href]")) {
      return !!materializedHttpUrl(part.getAttribute("href")) && !!part.querySelector("img") &&
        !Array.from(part.attributes).some(function(attribute) { return /^on/i.test(attribute.name); });
    }
    return part.matches("img") && !!part.closest("a[href]") && !!materializedHttpUrl(part.getAttribute("src"));
  });
}

function sourceOwnedResourceNodeMaterial(node) {
  var holder = document.createElement("div");
  holder.appendChild(node.cloneNode(true));
  return sourceOwnedPublicationMaterial(holder);
}

function sourceOwnedResourceCohorts(main) {
  for (var owner = main.parentElement; owner && owner !== document.body; owner = owner.parentElement) {
    if (sourceOwnershipInChrome(owner)) continue;
    var pairs = Array.from(owner.children).filter(function(child) {
      return !child.contains(main) && !!sourceOwnedResourceHeading(child) && sourceOwnedResourceGroup(child.nextElementSibling);
    }).map(function(heading) {
      return { heading: heading, resources: heading.nextElementSibling };
    });
    if (pairs.length < 2) continue;
    var clones = new WeakMap();
    var visible = visibilityPrunedClone(owner, document, clones);
    if (!pairs.every(function(pair) {
      return clones.has(pair.heading) && clones.has(pair.resources) &&
        visible.contains(clones.get(pair.heading)) && visible.contains(clones.get(pair.resources));
    })) continue;
    var groups = pairs.map(function(pair) {
      return {
        heading: sourceOwnedResourceNodeMaterial(clones.get(pair.heading)),
        resources: sourceOwnedResourceNodeMaterial(clones.get(pair.resources))
      };
    });
    Object.defineProperty(groups, "sourceOwner", { value: owner });
    return groups;
  }
  return [];
}

function sourceOwnedResourceFallbackCohorts(root, groups) {
  var previous = null;
  return groups.every(function(group) {
    var match = Array.from(root.querySelectorAll("h2, h3, h4, h5, h6")).some(function(heading) {
      for (var node = heading; node && node !== root; node = node.parentElement) {
        if (!node.nextElementSibling || (previous &&
            !(previous.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING))) continue;
        if (sourceOwnedResourceNodeMaterial(node) !== group.heading ||
            sourceOwnedResourceNodeMaterial(node.nextElementSibling) !== group.resources) continue;
        previous = node.nextElementSibling;
        return true;
      }
      return false;
    });
    return match;
  });
}

function sourceOwnedResourceMaterialTree(root) {
  var clone = root.cloneNode(true);
  clone.querySelectorAll("main, [role='main']").forEach(function(main) {
    if (!Array.from(main.attributes).every(function(attribute) { return /^(?:class|role)$/.test(attribute.name); }) ||
        (main.getAttribute("role") && main.getAttribute("role") !== "main")) return;
    var wrapper = document.createElement("div");
    while (main.firstChild) wrapper.appendChild(main.firstChild);
    main.replaceWith(wrapper);
  });
  Array.from(clone.children).forEach(function(child) {
    if (child.matches("div.page[id='readability-page-1']") && !document.getElementById(child.id)) child.removeAttribute("id");
  });
  var events = JSON.parse(sourceOwnedPublicationMaterial(clone))[1];
  var tree = { children: [] };
  var stack = [tree];
  events.forEach(function(event) {
    if (event[0] === "end") {
      stack.pop();
      return;
    }
    var node = { key: JSON.stringify(event), children: [] };
    stack[stack.length - 1].children.push(node);
    if (event[0] === "start") stack.push(node);
  });
  return tree;
}

function sourceOwnedResourceMaterialPreserved(primary, fallback) {
  var paragraphKey = JSON.stringify(["start", "p", [], "http://www.w3.org/1999/xhtml", null]);
  function inlineNode(node) {
    var event = JSON.parse(node.key);
    return event[0] === "text" || event[0] === "foreign" ||
      (event[0] === "start" && /^(?:a|span|em|strong|b|i|u|s|del|mark|small|abbr|code|kbd|samp|sub|sup|time|img|br)$/.test(event[1]));
  }
  function containsSequence(source, target) {
    var next = 0;
    return source.every(function(node) {
      while (next < target.length) {
        var start = next;
        var candidate = target[next++];
        if (node.key === candidate.key && containsSequence(node.children, candidate.children)) return true;
        if (node.key !== paragraphKey || !node.children.length || (start && inlineNode(target[start - 1]))) continue;
        var end = start;
        while (end < target.length && inlineNode(target[end])) end++;
        if (JSON.stringify(node.children) === JSON.stringify(target.slice(start, end))) {
          next = end;
          return true;
        }
      }
      return false;
    });
  }
  return containsSequence(sourceOwnedResourceMaterialTree(primary).children, sourceOwnedResourceMaterialTree(fallback).children);
}

function sourceOwnedResourceFallbackRecord(records, selected, context) {
  if (!context || !selected || !context.main.contains(selected.node)) return selected;
  var owner = records.find(function(record) { return record.node === context.owner; });
  if (!owner || !Number.isFinite(owner.score) ||
      !sourceOwnedResourceFallbackCohorts(owner.visibleNode, context.groups) ||
      !sourceOwnedResourceMaterialPreserved(selected.visibleNode, owner.visibleNode)) return selected;
  return owner;
}

function sourceOwnedResourceContext(metadata) {
  if (!document.body) return null;
  var mains = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(node) {
    return sourceOwnedResourceSectionVisible(node);
  });
  if (mains.length !== 1) return null;
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
    return sourceOwnedResourceSectionVisible(node);
  });
  if (headings.length !== 1 || !mains[0].contains(headings[0]) || headings[0].closest("a[href]") ||
      !sourceOwnedReaderHeadlineTitleMatches(headings[0].textContent, metadata, null)) return null;
  var groups = sourceOwnedResourceCohorts(mains[0]);
  return groups.length >= 2 ? { main: mains[0], owner: groups.sourceOwner, groups: groups } : null;
}

function sourceOwnedLinkedResourceSections(primary, fallback, primaryRoot, fallbackRoot) {
  if (!document.body || primary.contentType !== "article" || fallback.contentType !== "article" ||
      fallback.sourceOwnedFocalArticle) return false;
  var context = sourceOwnedResourceContext(fallback);
  return !!context && sourceOwnedResourceFallbackCohorts(fallbackRoot, context.groups) &&
    sourceOwnedResourceMaterialPreserved(primaryRoot, fallbackRoot);
}
