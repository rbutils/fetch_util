function newsletterVisibleMarkdownLength(line) {
  return normalizeText(String(line || "")
    .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
    .replace(/\[([^\]]*)\]\([^)]+\)/g, "$1")).length;
}

function newsletterRecordDestination(link) {
  if (link.matches("[download], [rel~='tag' i], [rel~='cite' i], [rel~='author' i]")) return null;
  if (link.closest(
    "aside, nav, footer, cite, sup, [role~='complementary' i], [role~='navigation' i], " +
    "[class*='taxonomy' i], [class~='tag' i], [class~='tags' i], [class*='tag-list' i], " +
    "[class*='citation' i], [id*='citation' i], [class*='footnote' i], [id*='footnote' i]"
  )) return null;

  var destination = materializedHttpUrl(link.getAttribute("href") || "");
  if (!destination) return null;
  try {
    var parsed = new URL(destination);
    var current = new URL(location.href);
    parsed.hash = "";
    current.hash = "";
    Array.from(parsed.searchParams.keys()).forEach(function(name) {
      if (/^(?:utm_.+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)$/i.test(name)) parsed.searchParams.delete(name);
    });
    Array.from(current.searchParams.keys()).forEach(function(name) {
      if (/^(?:utm_.+|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid)$/i.test(name)) current.searchParams.delete(name);
    });
    var key = parsed.origin + parsed.pathname.replace(/\/+$/, "") + parsed.search;
    var currentKey = current.origin + current.pathname.replace(/\/+$/, "") + current.search;
    return key === currentKey ? null : key;
  } catch (_error) {
    return null;
  }
}

function newsletterIndependentLinkedSectionCount(root) {
  if (!root || !root.querySelectorAll) return 0;
  var headings = Array.from(root.querySelectorAll("h2, h3, h4, h5, h6"));
  var destinations = new Set();

  headings.forEach(function(heading, index) {
    if (heading.closest(
      "aside, nav, footer, [role~='complementary' i], [role~='navigation' i], " +
      "[class*='taxonomy' i], [class~='tag' i], [class~='tags' i], [class*='tag-list' i]"
    )) return;

    var level = Number(heading.tagName.slice(1));
    var boundary = null;
    var hasNestedHeading = false;
    for (var nextIndex = index + 1; nextIndex < headings.length; nextIndex++) {
      var nextLevel = Number(headings[nextIndex].tagName.slice(1));
      if (nextLevel <= level) {
        boundary = headings[nextIndex];
        break;
      }
      hasNestedHeading = true;
    }
    if (hasNestedHeading) return;

    var range = document.createRange();
    range.setStartAfter(heading);
    if (boundary) range.setEndBefore(boundary);
    else range.setEnd(root, root.childNodes.length);
    var section = range.cloneContents();
    if (section.querySelector("table, dl")) return;
    var textLength = normalizeText([heading.textContent || "", section.textContent || ""].join(" ")).length;
    if (!textLength || textLength >= 200) return;

    var links = Array.from(section.querySelectorAll("a[href]"));
    links = Array.from(heading.querySelectorAll("a[href]")).concat(links);
    var destination = links.map(newsletterRecordDestination).find(Boolean);
    if (destination) destinations.add(destination);
  });

  return destinations.size;
}
