function githubThreadOpening(root) {
  var modern = root.querySelector("[data-testid='issue-body']");
  if (githubThreadBody(modern) && githubThreadAuthor(modern)) return modern;

  var candidates = Array.prototype.slice.call(root.querySelectorAll(".js-comment-container, .timeline-comment, [data-testid='issue-comment'], .discussion-comment"));
  for (var index = 0; index < candidates.length; index += 1) {
    if (githubThreadBody(candidates[index]) && githubThreadAuthor(candidates[index])) return candidates[index];
  }
  return null;
}

function githubThreadEventMarkdown(node) {
  var clone = visibilityPrunedClone(node);
  removeAll(clone, "button, svg, img, [role='tooltip'], .sr-only, [data-testid*='hamburger']");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function githubThreadEntry(node, route) {
  var markdown = githubThreadNodeMarkdown(node);
  var accepted = /\b(?:accepted answer|answer marked as accepted)\b/i.test(normalizeText(node.textContent || "")) || !!node.querySelector("[data-testid='accepted-answer'], [aria-label*='accepted']");
  var review = route.kind === "pull" && !!node.querySelector("[id^='pullrequestreview-'], [id^='discussion_r'], a[href*='#pullrequestreview-'], a[href*='#discussion_r']");
  var kind = accepted ? "Accepted answer" : review ? "Review" : markdown ? "Comment" : "Event";
  if (!markdown) markdown = githubThreadEventMarkdown(node);
  if (!normalizeText(markdown)) return null;

  return {
    node: node,
    sourceNode: visibilityPrunedClone(node),
    kind: kind,
    author: githubThreadAuthor(node),
    markdown: markdown,
    permalink: githubThreadPermalink(node),
    timestamp: githubThreadTimestamp(node)
  };
}

function githubThreadEntries(root, opening, route) {
  var modern = Array.prototype.slice.call(root.querySelectorAll("[data-testid^='timeline-row-border-']"));
  var nodes = modern.length ? modern : Array.prototype.slice.call(root.querySelectorAll([
    ".js-comment-container",
    ".timeline-comment",
    "[data-testid='issue-comment']",
    ".discussion-comment",
    ".timeline-event",
    ".discussion-item"
  ].join(", ")));

  var seen = new Set();
  return nodes.filter(function(node) {
    return node !== opening && !node.contains(opening) && !opening.contains(node);
  }).map(function(node) {
    return githubThreadEntry(node, route);
  }).filter(function(entry) {
    if (!entry) return false;
    var identity = entry.permalink || JSON.stringify([entry.kind, entry.author, entry.timestamp, normalizeText(entry.markdown)]);
    if (seen.has(identity)) return false;
    seen.add(identity);
    return true;
  });
}

function githubThreadMetadataMarkdown(root) {
  var selectors = [
    "[data-testid='sidebar-assignees-section']",
    "[data-testid='sidebar-labels-section']",
    "[data-testid='sidebar-types-section']",
    "[data-testid='sidebar-projects-section']",
    "[data-testid='sidebar-milestones-section']",
    "[data-testid='sidebar-relationships-section']",
    "[data-testid='sidebar-development-section']",
    "[data-testid='sidebar-participants-section']"
  ];
  var sections = [];

  selectors.forEach(function(selector) {
    var node = root.querySelector(selector) || document.querySelector(selector);
    if (!node || elementSubtreeHidden(node)) return;

    var clone = visibilityPrunedClone(node);
    removeAll(clone, "button, svg, img, [role='tooltip']");
    var heading = normalizeText((clone.querySelector("h2, h3, h4") || {}).textContent || "");
    removeAll(clone, "h2, h3, h4");
    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    if (heading && normalizeText(markdown)) sections.push("### " + heading + "\n\n" + markdown);
  });

  return sections.length ? "## Metadata\n\n" + sections.join("\n\n") : "";
}

function githubTimelineControlEnabled(control) {
  if (!control || elementSubtreeHidden(control) || control.disabled || control.getAttribute("aria-disabled") === "true") return false;

  var wrapper = control.closest("[data-testid*='timeline-load-more']");
  return !wrapper || (!elementSubtreeHidden(wrapper) && wrapper.getAttribute("aria-disabled") !== "true");
}

function githubTimelineInventory(route, root) {
  var entries = [];
  var current = new URL(location.href);
  var mainUrl = githubRouteUrl(route);
  if (current.searchParams.has("timeline_page")) entries.push({ label: "Main conversation", url: mainUrl });

  Array.prototype.slice.call(root.querySelectorAll("a[rel~='next'][href*='timeline_page='], a[data-testid*='timeline-load-more'][href*='timeline_page='], [data-testid*='timeline-load-more'] a[href*='timeline_page=']")).forEach(function(link) {
    var continuation = githubTimelineContinuation(route, link.getAttribute("href"));
    if (continuation && githubTimelineControlEnabled(link)) {
      entries.push({ label: normalizeText(link.textContent) || "More timeline items", url: continuation });
    }
  });

  var loadMore = Array.prototype.slice.call(root.querySelectorAll("[data-testid*='timeline-load-more'] button, button[data-testid*='timeline-load-more']")).find(githubTimelineControlEnabled);
  if (loadMore && !entries.some(function(entry) { return /timeline_page=/.test(entry.url || ""); })) {
    var next = new URL(mainUrl);
    next.searchParams.set("timeline_page", String(Number(current.searchParams.get("timeline_page") || "0") + 1));
    var continuation = githubTimelineContinuation(route, next.href);
    if (continuation) entries.push({ label: "More timeline items", url: continuation, detail: normalizeText(loadMore.textContent) });
  }

  var hasContinuation = entries.length > 0;

  if (route.kind === "pull") {
    entries.push(
      { label: "Commits", url: githubRouteUrl(route, "/commits") },
      { label: "Checks", url: githubRouteUrl(route, "/checks") },
      { label: "Files changed", url: githubRouteUrl(route, "/files") },
      { label: "Raw diff", url: githubRouteUrl(route) + ".diff" },
      { label: "Raw patch", url: githubRouteUrl(route) + ".patch" }
    );
  }

  return {
    markdown: browsableInventory("Browse this GitHub thread", entries),
    hasContinuation: hasContinuation
  };
}

function githubTimelineContinuation(route, href) {
  if (!href) return null;

  try {
    var url = new URL(href, location.href);
    var current = githubRouteUrl(route);
    if (url.origin !== location.origin || url.pathname !== new URL(current).pathname) return null;
    if (!url.searchParams.has("timeline_page")) return null;
    return materializedHttpUrl(url.href);
  } catch (_error) {
    return null;
  }
}

function githubThreadEntrySections(entries) {
  var sections = [];
  entries.forEach(function(entry) {
    var label = entry.kind + (entry.author ? " by " + entry.author : "");
    sections.push("### " + (entry.permalink ? markdownLink(label, entry.permalink) : label));
    if (entry.timestamp) sections.push("- Time: " + entry.timestamp);
    sections.push(entry.markdown);
  });
  return sections;
}

function githubThreadReplyCount(root, entries, hasContinuation) {
  if (hasContinuation) return null;

  var loaded = entries.filter(function(entry) { return entry.kind !== "Event"; }).length;
  var loadedReplies = entries.filter(function(entry) { return entry.kind === "Comment" || entry.kind === "Accepted answer"; }).length;
  var reported = githubThreadCount(root);
  if (!root.querySelector("[data-testid='issue-body']")) return reported == null ? loaded : reported;
  return reported != null && reported > loadedReplies ? null : loaded;
}

function githubThreadContent(metadata) {
  var route = githubThreadRoute();
  if (!route) return null;

  var root = githubThreadRoot();
  if (!root) return null;

  var opening = githubThreadOpening(root);
  var openingMarkdown = githubThreadNodeMarkdown(opening);
  if (!opening) return null;

  var title = normalizeText(firstText(["[data-testid='issue-title']", "#issue_title", ".js-issue-title", "main h1", "h1"]) || metadata.title || document.title);
  var author = githubThreadAuthor(opening);
  if (!title || !author) return null;

  var entries = githubThreadEntries(root, opening, route);
  var label = route.kind === "pull" ? "Pull Request" : route.kind === "discussions" ? "Discussion" : "Issue";
  var openingLabel = githubThreadPermalink(opening) ? markdownLink("Opening", githubThreadPermalink(opening)) : "Opening";
  var sections = ["# " + title, "- Author: " + author, "- " + label + ": " + route.community, "## " + openingLabel];
  if (openingMarkdown) sections.push(openingMarkdown);
  var metadataMarkdown = githubThreadMetadataMarkdown(root);
  if (metadataMarkdown) sections.push(metadataMarkdown);
  if (entries.length) sections.push("## Timeline");
  sections = sections.concat(githubThreadEntrySections(entries));
  var inventory = githubTimelineInventory(route, root);
  if (inventory.markdown) sections.push(inventory.markdown);

  var count = githubThreadReplyCount(root, entries, inventory.hasContinuation);
  var visibleNodes = [visibilityPrunedClone(opening)].concat(entries.map(function(entry) { return entry.sourceNode; }));
  return {
    title: title,
    byline: author,
    excerpt: openingMarkdown ? normalizeText((githubThreadBody(opening) || {}).textContent || "") : "",
    siteName: "GitHub",
    publishedTime: metadata.publishedTime,
    html: visibleNodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n"),
    markdown: sections.join("\n\n"),
    textContent: normalizeText([title, openingMarkdown].concat(entries.map(function(entry) { return entry.markdown; })).join(" ")),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    platform: "GitHub",
    handle: author,
    replyCount: count,
    community: route.community,
    score: githubThreadScore(opening)
  };
}

function registerGitHubThreadProfiles() {
  registerHostAwareProfile(/(^|\.)github\.com$/, githubThreadContent);
}
