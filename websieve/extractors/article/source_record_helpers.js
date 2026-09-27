function sourceRecordTextKey(value) {
  return normalizeText(value || "").toLowerCase()
    .replace(/[’‘`]/g, "'")
    .replace(/\bof\b/g, " ")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function sourceRecordLabelKey(value) {
  return sourceRecordTextKey(value).replace(/\s*:?\s*$/, "");
}

function sourceRecordFieldValues(group, labels) {
  var accepted = labels.map(sourceRecordLabelKey);
  var matching = group.fields.filter(function(field) {
    return accepted.indexOf(sourceRecordLabelKey(field.label)) !== -1;
  });
  var values = matching.reduce(function(all, field) { return all.concat(field.values); }, []);
  return values.filter(function(value, index) {
    return values.findIndex(function(candidate) {
      return sourceRecordTextKey(candidate) === sourceRecordTextKey(value);
    }) === index;
  });
}

function sourceRecordUniqueField(group, labels) {
  var values = sourceRecordFieldValues(group, labels);
  var keys = values.map(sourceRecordTextKey).filter(Boolean);
  if (!keys.length || keys.some(function(key) { return key !== keys[0]; })) return null;
  return values[0] || null;
}

function sourceRecordTitleMatches(heading, title) {
  var headingKey = sourceRecordTextKey(heading);
  var titleKey = sourceRecordTextKey(title);
  if (!headingKey || !titleKey) return false;
  if (headingKey === titleKey) return true;
  var headingWords = headingKey.split(" ");
  var titleWords = titleKey.split(" ");
  if (Math.abs(headingWords.length - titleWords.length) !== 1) return false;
  var longer = headingWords.length > titleWords.length ? headingWords : titleWords;
  var shorter = headingWords.length > titleWords.length ? titleWords : headingWords;
  return longer.filter(function(word) { return word !== "and"; }).join(" ") === shorter.join(" ") &&
    longer.filter(function(word) { return word === "and"; }).length === 1;
}

function sourceRecordLowestCommonAncestor(nodes) {
  if (!nodes.length || nodes.some(function(node) { return !node; })) return null;
  var ancestors = [];
  for (var current = nodes[0]; current; current = current.parentElement) ancestors.push(current);
  return ancestors.find(function(ancestor) {
    return nodes.every(function(node) { return ancestor.contains(node); });
  }) || null;
}

function sourceRecordBefore(first, second) {
  return !!(first && second && (first.compareDocumentPosition(second) & 4));
}

function sourceRecordVisibleMain() {
  var candidates = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(node) {
    return !elementVisuallyHidden(node);
  });
  var outer = candidates.filter(function(node) {
    return !candidates.some(function(other) { return other !== node && other.contains(node); });
  });
  return outer.length === 1 ? outer[0] : null;
}

function sourceRecordVisibleHeadings(root) {
  return Array.prototype.filter.call(root.querySelectorAll("h1, h2, h3, h4, h5, h6"), function(heading) {
    return !elementVisuallyHidden(heading);
  });
}

function sourceRecordHeadingKey(heading) {
  return sourceRecordLabelKey(heading && (heading.innerText || heading.textContent));
}

function sourceRecordSectionByLabel(sections, label) {
  return sections.find(function(section) { return section.label === label; });
}

function sourceRecordFormalSections(main) {
  var headings = sourceRecordVisibleHeadings(main);
  var requiredLabels = ["agency", "action", "summary", "dates"];
  var optionalLabels = ["for further information contact", "supplementary information"];
  var sections = requiredLabels.map(function(label) {
    var matches = headings.filter(function(heading) { return sourceRecordHeadingKey(heading) === label; });
    return matches.length === 1 ? { label: label, heading: matches[0] } : null;
  });
  if (sections.some(function(section) { return !section; })) return null;
  var optionalSections = optionalLabels.map(function(label) {
    var matches = headings.filter(function(heading) { return sourceRecordHeadingKey(heading) === label; });
    return matches.length > 1 ? false : (matches.length === 1 ? { label: label, heading: matches[0] } : null);
  });
  if (optionalSections.some(function(section) { return section === false; })) return null;
  sections = sections.concat(optionalSections.filter(Boolean)).sort(function(first, second) {
    return headings.indexOf(first.heading) - headings.indexOf(second.heading);
  });
  var indices = sections.map(function(section) { return headings.indexOf(section.heading); });
  if (indices.some(function(index, position) { return position > 0 && index <= indices[position - 1]; })) return null;

  var root = sourceRecordLowestCommonAncestor(sections.map(function(section) { return section.heading; }));
  if (!root || root === main || root.matches("nav, aside, footer, [role='navigation'], [role='complementary']")) return null;
  return { headings: headings, sections: sections, root: root };
}

function sourceRecordSectionNodes(section, root) {
  var nodes = [];
  var current = section.heading;
  while (current) {
    nodes.push(current);
    var sibling = current.nextElementSibling;
    if (!sibling) break;
    if (sibling.matches("h1, h2, h3, h4, h5, h6")) break;
    nodes.push(sibling);
    current = sibling;
    if (root.contains(current.nextElementSibling) && current.nextElementSibling &&
        current.nextElementSibling.matches("h1, h2, h3, h4, h5, h6")) break;
  }
  return nodes;
}

function sourceRecordSectionText(section, root) {
  return normalizeText(sourceRecordSectionNodes(section, root).map(visibleMetadataNodeText).join(" "));
}

function sourceRecordSummaryParagraph(section, root) {
  var nodes = sourceRecordSectionNodes(section, root);
  for (var index = 1; index < nodes.length; index += 1) {
    var block = nodes[index];
    var paragraphs = block.matches && block.matches("p") ? [block] : Array.prototype.slice.call(block.querySelectorAll("p"));
    var visible = paragraphs.filter(function(paragraph) {
      return !elementVisuallyHidden(paragraph) && normalizeText(visibleMetadataNodeText(paragraph));
    });
    if (visible.length) return visible[0];
  }
  return null;
}

function sourceRecordCanonicalIdentity(metadata, number) {
  var canonicals = Array.prototype.slice.call(document.querySelectorAll("link[rel~='canonical' i][href]"));
  if (canonicals.length !== 1 || !number) return false;
  var href = materializedHttpUrl(canonicals[0].getAttribute("href"));
  var current = materializedHttpUrl(location.href);
  if (!href || !current || href !== current || metadata.canonicalUrl !== href) return false;
  try {
    var segments = new URL(href).pathname.split("/").filter(Boolean);
    return segments.some(function(segment) { return segment === number; });
  } catch (e) {
    return false;
  }
}

function sourceRecordMarkerNodes(root, number) {
  if (!root || !number) return [];
  var marker = new RegExp("\\bFR\\s+Doc\\.?\\s*" + number.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b", "i");
  return Array.prototype.filter.call(root.querySelectorAll("*"), function(node) {
    return !node.children.length && !elementVisuallyHidden(node) && marker.test(visibleMetadataNodeText(node));
  });
}
