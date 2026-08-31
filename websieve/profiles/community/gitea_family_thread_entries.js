function giteaFamilyThreadBody(node) {
  if (!node) return null;
  if (node.matches && node.matches(".comment-body")) return node;
  return node.querySelector(".comment-body");
}

function giteaFamilyThreadNodeMarkdown(node) {
  var body = giteaFamilyThreadBody(node);
  if (!body) return "";

  var clone = visibilityPrunedClone(body);
  removeAll(clone, ".raw-content, .edit-content-zone, form, button, [role='tooltip'], .menu, .dropdown");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function giteaFamilyThreadEventMarkdown(node) {
  var clone = visibilityPrunedClone(node);
  removeAll(clone, [
    ".timeline-avatar",
    ".author",
    "relative-time",
    "time",
    "button",
    "svg",
    "img",
    "[role='tooltip']",
    ".menu",
    ".dropdown"
  ].join(", "));
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function giteaFamilyThreadGroupMarkdown(node) {
  var clone = visibilityPrunedClone(node);
  removeAll(clone, [
    ".raw-content",
    ".edit-content-zone",
    ".timeline-avatar",
    ".comment-header-right",
    "form",
    "button",
    "svg",
    "[role='tooltip']",
    ".menu",
    ".dropdown"
  ].join(", "));
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function giteaFamilyThreadAuthor(node) {
  var selectors = [
    ".comment-header .author",
    ".timeline-avatar + * .author",
    ".comment-header-left a.tw-font-semibold",
    ".comment-header-left span.tw-font-semibold",
    ".comment-header a.tw-font-semibold",
    "a.tw-font-semibold",
    ".author"
  ];
  for (var index = 0; index < selectors.length; index += 1) {
    var candidate = node && node.querySelector(selectors[index]);
    if (candidate && elementVisuallyHidden(candidate)) continue;
    var value = normalizeText(candidate && candidate.textContent);
    if (value) return value;
  }
  return "";
}

function giteaFamilyThreadTimestamp(node) {
  var time = node && node.querySelector("relative-time[datetime], time[datetime]");
  return time ? normalizeText(time.getAttribute("datetime")) : "";
}

function giteaFamilyThreadPermalink(node, route) {
  if (!node) return null;
  var anchor = node.id ? node : node.querySelector([
    ":scope > .timeline-item[id]",
    ":scope > [id^='issuecomment-']",
    ":scope > [id^='event-']"
  ].join(", "));
  if (!anchor || !anchor.id) return null;
  return materializedHttpUrl(giteaFamilyRouteUrl(route) + "#" + encodeURIComponent(anchor.id));
}

function giteaFamilyThreadEntry(node, route) {
  var body = giteaFamilyThreadBody(node);
  var group = node.matches && node.matches(".timeline-item-group");
  var markdown = group
    ? giteaFamilyThreadGroupMarkdown(node)
    : (body ? giteaFamilyThreadNodeMarkdown(node) : giteaFamilyThreadEventMarkdown(node));
  if (!normalizeText(markdown)) return null;

  var sourceNode = visibilityPrunedClone(node);
  removeAll(sourceNode, [
    ".raw-content",
    ".edit-content-zone",
    ".pull-merge-box",
    ".timeline-item.comment.merge.box",
    "form",
    "button",
    "[role='tooltip']",
    ".menu",
    ".dropdown"
  ].join(", "));

  return {
    node: node,
    sourceNode: sourceNode,
    kind: group ? "Review" : (body ? "Comment" : "Event"),
    author: giteaFamilyThreadAuthor(node),
    markdown: markdown,
    permalink: giteaFamilyThreadPermalink(node, route),
    timestamp: giteaFamilyThreadTimestamp(node)
  };
}

function giteaFamilyThreadEntries(root, opening, route) {
  var entries = giteaFamilyTimelineItems(root).filter(function(node) {
    return node !== opening && !node.contains(opening) && !opening.contains(node);
  }).map(function(node) {
    return giteaFamilyThreadEntry(node, route);
  });
  return deduplicateForgeThreadPermalinks(entries);
}

function giteaFamilyThreadMetadata(root) {
  var node = root && root.querySelector(".issue-content-right");
  if (!node || elementSubtreeHidden(node)) return { markdown: "", sourceNode: null };

  var clone = visibilityPrunedClone(node);
  removeAll(clone, [
    "form",
    "button",
    "input",
    "select",
    "option",
    "svg",
    "img",
    "[role='tooltip']",
    ".menu",
    ".dropdown",
    ".select-menu",
    ".popup"
  ].join(", "));
  var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  return { markdown: markdown, sourceNode: normalizeText(markdown) ? clone : null };
}

function giteaFamilyThreadEntrySections(entries) {
  var sections = [];
  entries.forEach(function(entry) {
    var label = entry.kind + (entry.author ? " by " + entry.author : "");
    sections.push("### " + (entry.permalink ? markdownLink(label, entry.permalink) : label));
    if (entry.timestamp) sections.push("- Time: " + entry.timestamp);
    sections.push(entry.markdown);
  });
  return sections;
}
