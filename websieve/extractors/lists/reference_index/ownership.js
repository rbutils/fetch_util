function datedReferenceHeadingValue(value) {
  var text = normalizeText(value || "");
  var iso = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  var named = text.match(/^(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\s+(\d{1,2}),\s+(\d{4})$/i);
  if (!iso && !named) return null;
  var year = Number(iso ? iso[1] : named[3]);
  var month = iso ? Number(iso[2]) - 1 : ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"].indexOf(named[1].toLowerCase().substring(0, 3));
  var day = Number(iso ? iso[3] : named[2]);
  var date = new Date(0);
  date.setUTCFullYear(year, month, day);
  date.setUTCHours(0, 0, 0, 0);
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month || date.getUTCDate() !== day) return null;
  return date.getTime();
}

function datedReferenceDocumentUrl(value) {
  if (!normalizeText(value || "")) return null;
  try {
    var url = new URL(value, document.baseURI);
    if (!/^https?:$/.test(url.protocol)) return null;
    return url.origin + url.pathname + url.search;
  } catch (_error) { return null; }
}

function datedReferenceAppearanceControl(node) {
  if (!node.matches("button") || node.querySelector("a, input, select, textarea, img, video, audio, iframe")) return false;
  var label = normalizeText(node.getAttribute("aria-label") || node.textContent || "");
  return /^(?:toggle|switch)\s+(?:(?:dark|light|colou?r)\s+)?(?:mode|theme)$/i.test(label);
}

function datedReferenceOutsideMaterial(root) {
  return Array.from(document.body.childNodes).some(function(node) {
    if (node === root || node.nodeType === 8) return false;
    if (node.nodeType === 3) return !!normalizeText(node.nodeValue || "");
    if (node.nodeType !== 1 || node.matches("script, style, noscript, template")) return false;
    return !datedReferenceAppearanceControl(node);
  });
}

function datedReferenceGroupsOwned(root, heading) {
  var groups = [];
  var group = null;
  var previousDate = null;
  var invalid = false;
  Array.from(root.children).forEach(function(node) {
    if (invalid || node === heading) return;
    if (node.matches("h2")) {
      var date = datedReferenceHeadingValue(node.textContent);
      if (date === null || (previousDate !== null && date >= previousDate) || elementVisuallyHidden(node)) {
        invalid = true;
        return;
      }
      group = { heading: node, topics: 0, references: 0 };
      groups.push(group);
      previousDate = date;
      return;
    }
    if (!group) {
      if (!node.matches("p") || elementVisuallyHidden(node)) invalid = true;
      return;
    }
    if (node.matches("h3")) {
      if (!normalizeText(node.textContent || "") || elementVisuallyHidden(node)) invalid = true;
      else group.topics += 1;
      return;
    }
    if (!node.matches("ul, ol")) { invalid = true; return; }
    var links = Array.from(node.querySelectorAll("a[href]")).filter(function(link) {
      return !!normalizeText(link.textContent || "") && !!datedReferenceDocumentUrl(link.getAttribute("href")) &&
        !elementVisuallyHidden(link);
    });
    if (!links.length && (normalizeText(node.textContent || "") || node.querySelector("img, video, audio, iframe, input, button"))) {
      invalid = true;
      return;
    }
    group.references += links.length;
  });
  return !invalid && groups.length > 1 && groups.every(function(entry) { return entry.topics > 0 && entry.references > 0; });
}

function datedReferenceIndexContext() {
  return withSourceVisibilityRead(function() {
    var roots = Array.from(document.querySelectorAll("main, [role='main']"));
    if (roots.length !== 1) return null;
    var root = roots[0];
    if (root.parentElement !== document.body || datedReferenceOutsideMaterial(root)) return null;
    if (document.querySelector("script[type='application/ld+json'], [itemscope][itemtype]") ||
        root.querySelector("article, form, [role='feed'], [itemprop~='articleBody']")) return null;
    var types = Array.from(document.querySelectorAll("meta[property='og:type']"));
    if (types.some(function(node) { return !/^(?:website|summary)$/i.test(normalizeText(node.content || "")); })) return null;
    var headings = Array.from(document.querySelectorAll("h1"));
    if (headings.length !== 1 || headings[0].parentElement !== root || root.firstElementChild !== headings[0]) return null;
    var heading = headings[0];
    var title = normalizeText(heading.textContent || "");
    var titles = Array.from(document.querySelectorAll("meta[property='og:title']"));
    if (!title || !titles.length || titles.some(function(node) { return normalizeText(node.content || "") !== title; })) return null;
    var current = datedReferenceDocumentUrl(location.href);
    var declarations = Array.from(document.querySelectorAll("meta[property='og:url'], link[rel='canonical']"));
    if (!declarations.length || declarations.some(function(node) {
      return datedReferenceDocumentUrl(node.getAttribute("content") || node.getAttribute("href")) !== current;
    })) return null;
    if (elementVisuallyHidden(root) || elementVisuallyHidden(heading) || nodeHasShadowContent(root)) return null;
    if (!datedReferenceGroupsOwned(root, heading)) return null;
    return { root: root, title: title };
  });
}
