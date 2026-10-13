function physicalDefinitionRecordContext(metadata) {
  var page;
  try { page = new URL(location.href); } catch (_e) { return null; }
  var route = page.pathname.match(/\/(?:records?|objects?|items?)\/([^/]+)\/?$/i);
  if (!route) return null;
  var components;
  try { components = decodeURIComponent(route[1]).split(/[_-]/); } catch (_e) { return null; }
  var canonical = document.querySelector("link[rel~='canonical' i]");
  if (!canonical || focalCanonicalUrl(canonical.getAttribute("href")) !== focalCanonicalUrl(location.href)) return null;
  if (structuredDataNodes().some(function(node) {
    return nodeTypes(node).some(function(type) { return /^(?:NewsArticle|ReportageNewsArticle|BlogPosting|Article)$/.test(type); });
  })) return null;

  var roots = document.querySelectorAll("main, [role='main']");
  if (roots.length !== 1) return null;
  var root = roots[0];
  var headings = root.querySelectorAll("h1");
  var lists = root.querySelectorAll("dl");
  if (headings.length !== 1 || lists.length !== 1 || root.querySelector("[itemprop~='author' i], [rel~='author' i], [itemprop~='datePublished' i]")) return null;
  var title = cleanDocsHeadingText(headings[0].textContent);
  var titles = [document.title, metadata && metadata.title].concat(Array.from(
    document.querySelectorAll("meta[property='og:title' i]"), function(node) { return node.getAttribute("content"); }
  )).map(function(value) { return normalizeText(value || ""); }).filter(Boolean);
  if (!title || !titles.length || !titles.every(function(value) {
    return value === title || (value.indexOf(title) === 0 && /^(?:-|\||\u2013|\u2014)\s+\S/.test(normalizeText(value.slice(title.length))));
  })) return null;
  if (elementSubtreeHidden(root) || elementSubtreeHidden(headings[0]) || elementSubtreeHidden(lists[0]) ||
      physicalTechnicalOwnerChrome(root, root) || physicalTechnicalOwnerChrome(headings[0], root)) return null;

  var identifierLabel = /^(?:identifier|(?:record|object|item|inventory|accession|registration|catalog(?:ue)?|museum)\s+(?:number|id|identifier))$/;
  var typeLabel = /^(?:(?:object|record|item)\s+)?type$/;
  var groups = visibleLabeledMetadataGroups(lists[0], function(label) { return identifierLabel.test(label) || typeLabel.test(label); });
  if (groups.length !== 1) return null;
  var identifiers = new Set();
  var titleTypes = [];
  groups[0].fields.forEach(function(field) {
    if (identifierLabel.test(field.label)) field.values.forEach(function(value) {
      if (/\p{L}/u.test(value) && /\p{N}/u.test(value) && components.indexOf(value) !== -1) identifiers.add(value);
    });
    if (typeLabel.test(field.label)) titleTypes = titleTypes.concat(field.values);
  });
  if (identifiers.size !== 1 || !titleTypes.length || !titleTypes.every(function(value) { return value === title; })) return null;
  return { root: root, title: title };
}

function physicalDefinitionRecordContent(metadata) {
  return physicalDataRecordContentForContext(metadata, physicalDefinitionRecordContext(metadata));
}
