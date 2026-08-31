function gitlabThreadOpening(root) {
  var body = gitlabThreadBody(root);
  if (!body) return null;
  return body.closest("[data-testid='work-item-description-wrapper'], .detail-page-description, .issuable-description, .description") || body;
}

function gitlabThreadEventMarkdown(node) {
  var clone = visibilityPrunedClone(node);
  removeAll(clone, "button, svg, img, [role='tooltip'], .note-actions, .js-note-actions, .sr-only");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function gitlabThreadEntry(node, route) {
  var markdown = gitlabThreadNodeMarkdown(node);
  var system = node.matches(".system-note, [data-testid='system-note']") || !!node.querySelector(".system-note, [data-testid='system-note']");
  var review = route.kind === "merge_requests" && (
    node.matches(".note-discussion, .diff-note, [data-testid='diff-note']") ||
    !!node.closest(".note-discussion, .diff-note, [data-testid='diff-note']") ||
    !!node.querySelector(".diff-note, [data-testid='diff-note'], .discussion")
  );
  var kind = system ? "Event" : review ? "Review" : "Comment";
  if (!markdown) markdown = gitlabThreadEventMarkdown(node);
  if (!normalizeText(markdown)) return null;

  return {
    sourceNode: visibilityPrunedClone(node),
    kind: kind,
    author: gitlabThreadAuthor(node),
    markdown: markdown,
    permalink: gitlabThreadPermalink(node, route),
    timestamp: gitlabThreadTimestamp(node)
  };
}

function gitlabThreadEntries(root, opening, route) {
  var selector = ".js-timeline-entry.timeline-entry, .timeline-entry, .note-discussion, .note-wrapper.note-comment, [data-testid='note-wrapper'], .system-note, [data-testid='system-note'], .diff-note, [data-testid='diff-note']";
  var atomicSelector = ".note-wrapper.note-comment, [data-testid='note-wrapper'], .system-note, [data-testid='system-note'], .diff-note, [data-testid='diff-note']";
  var nodes = Array.prototype.slice.call(root.querySelectorAll(selector));
  var records = nodes.filter(function(node) {
    if (node === opening || node.contains(opening) || opening.contains(node) || elementSubtreeHidden(node)) return false;
    if (node.matches(atomicSelector)) {
      return !nodes.some(function(other) {
        return other !== node && other.matches(atomicSelector) && other.contains(node);
      });
    }
    return !node.querySelector(atomicSelector);
  });
  var seen = new Set();
  return records.map(function(node) {
    return gitlabThreadEntry(node, route);
  }).filter(function(entry) {
    if (!entry) return false;
    var identity = entry.permalink || JSON.stringify([entry.kind, entry.author, entry.timestamp, normalizeText(entry.markdown)]);
    if (seen.has(identity)) return false;
    seen.add(identity);
    return true;
  });
}

function gitlabThreadMetadataMarkdown(root) {
  var selectors = [
    "[data-testid='work-item-attributes-wrapper']",
    ".issuable-sidebar",
    ".mr-state-widget",
    "[data-testid='merge-request-sidebar']"
  ];
  var sections = [];
  var seenNodes = new Set();
  var seenMarkdown = new Set();
  selectors.forEach(function(selector) {
    var nodes = Array.prototype.slice.call(root.querySelectorAll(selector))
      .concat(Array.prototype.slice.call(document.querySelectorAll(selector)));
    nodes.forEach(function(node) {
      if (seenNodes.has(node) || elementSubtreeHidden(node)) return;
      seenNodes.add(node);

      var clone = visibilityPrunedClone(node);
      removeAll(clone, "button, svg, img, [role='tooltip'], form, .js-sidebar-dropdown-toggle");
      var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
      var identity = normalizeText(markdown);
      if (identity && !seenMarkdown.has(identity)) {
        seenMarkdown.add(identity);
        sections.push(markdown);
      }
    });
  });
  return sections.length ? "## Metadata\n\n" + sections.join("\n\n") : "";
}

function gitlabTimelineInventoryEntries(route, root) {
  var selector = "a[data-testid*='load-more'][href], [data-testid*='load-more'] a[href], .js-load-more a[href]";
  var entries = [];
  Array.prototype.slice.call(root.querySelectorAll(selector)).forEach(function(link) {
    if (elementVisuallyHidden(link)) return;
    var url = materializedHttpUrl(link.getAttribute("href"));
    if (!url) return;
    try {
      var parsed = new URL(url);
      if (parsed.origin !== location.origin || parsed.pathname !== route.basePath) return;
    } catch (_error) {
      return;
    }
    entries.push({ label: "Continue timeline", url: url });
  });

  var button = Array.prototype.slice.call(root.querySelectorAll(
    "button[data-testid*='load-more'], [data-testid*='load-more'] button, .js-load-more button"
  ))
    .find(function(candidate) {
      return !candidate.disabled && candidate.getAttribute("aria-disabled") !== "true" &&
        !elementVisuallyHidden(candidate);
    });
  if (button && !entries.length) {
    entries.push({
      label: "Conversation page",
      url: gitlabRouteUrl(route),
      detail: "Additional timeline records remain behind this GitLab page's in-page loader."
    });
  }
  return entries;
}

function gitlabThreadInventory(route, root) {
  var entries = gitlabTimelineInventoryEntries(route, root);
  var projectId = gitlabProjectId();
  var apiKind = route.kind === "merge_requests" ? "merge_requests" : "issues";
  var apiBase = projectId && gitlabApiRoot() + "/projects/" + projectId + "/" + apiKind + "/" + route.number;
  if (apiBase) {
    entries.push(
      { label: "API details", url: apiBase, detail: "May require authentication on this GitLab instance." },
      { label: "API notes", url: apiBase + "/notes?per_page=100&page=1", detail: "May require authentication; follow Link or X-Next-Page response headers." },
      { label: "API discussions", url: apiBase + "/discussions?per_page=100&page=1", detail: "May require authentication; follow Link or X-Next-Page response headers." }
    );
  }

  if (route.kind === "merge_requests") {
    entries.push(
      { label: "Commits", url: gitlabRouteUrl(route, "/commits") },
      { label: "Pipelines", url: gitlabRouteUrl(route, "/pipelines") },
      { label: "Reports", url: gitlabRouteUrl(route, "/reports") },
      { label: "Changes", url: gitlabRouteUrl(route, "/diffs") },
      { label: "Raw diff", url: gitlabRouteUrl(route) + ".diff" },
      { label: "Raw patch", url: gitlabRouteUrl(route) + ".patch" }
    );
    if (apiBase) {
      entries.push(
        { label: "API commits", url: apiBase + "/commits?per_page=100&page=1", detail: "May require authentication; follow Link or X-Next-Page response headers." },
        { label: "API pipelines", url: apiBase + "/pipelines?per_page=100&page=1", detail: "May require authentication; follow Link or X-Next-Page response headers." },
        { label: "API diffs", url: apiBase + "/diffs?per_page=100&page=1", detail: "May require authentication; follow Link or X-Next-Page response headers." },
        { label: "API approvals", url: apiBase + "/approvals", detail: "May require authentication on this GitLab instance." }
      );
    }
  }
  return browsableInventory("Browse this GitLab thread", entries);
}

function gitlabThreadEntrySections(entries) {
  var sections = [];
  entries.forEach(function(entry) {
    var label = entry.kind + (entry.author ? " by " + entry.author : "");
    sections.push("### " + (entry.permalink ? markdownLink(label, entry.permalink) : label));
    if (entry.timestamp) sections.push("- Time: " + entry.timestamp);
    sections.push(entry.markdown);
  });
  return sections;
}

function gitlabThreadContent(metadata) {
  var route = gitlabThreadRoute();
  if (!route) return null;

  var root = gitlabThreadRoot(route);
  if (!gitlabProductMatch(root)) return null;
  var opening = gitlabThreadOpening(root);
  if (!opening) return null;

  var openingMarkdown = gitlabThreadNodeMarkdown(opening) || gitlabThreadEventMarkdown(opening);
  var author = gitlabThreadAuthor(opening);
  var title = normalizeText(firstText(["[data-testid='work-item-title']", "[data-testid='issuable-title']", ".issue-title", ".merge-request .title", "main h1"]) || metadata.title || document.title);
  if (!title) return null;

  var entries = gitlabThreadEntries(root, opening, route);
  var label = route.kind === "merge_requests" ? "Merge Request" : route.kind === "work_items" ? "Work Item" : "Issue";
  var openingLink = gitlabThreadPermalink(opening, route);
  var sections = ["# " + title];
  if (author) sections.push("- Author: " + author);
  sections.push("- " + label + ": " + route.community,
                "## " + (openingLink ? markdownLink("Opening", openingLink) : "Opening"));
  if (openingMarkdown) sections.push(openingMarkdown);
  var metadataMarkdown = gitlabThreadMetadataMarkdown(root);
  if (metadataMarkdown) sections.push(metadataMarkdown);
  if (entries.length) sections.push("## Timeline");
  sections = sections.concat(gitlabThreadEntrySections(entries));
  sections.push(gitlabThreadInventory(route, root));

  var visibleNodes = [visibilityPrunedClone(opening)].concat(entries.map(function(entry) { return entry.sourceNode; }));
  return {
    title: title,
    byline: author,
    excerpt: normalizeText((gitlabThreadBody(opening) || {}).textContent || ""),
    siteName: location.hostname,
    publishedTime: gitlabThreadTimestamp(opening) || metadata.publishedTime,
    html: visibleNodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n"),
    markdown: sections.filter(Boolean).join("\n\n"),
    textContent: normalizeText([title, openingMarkdown].concat(entries.map(function(entry) { return entry.markdown; })).join(" ")),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    threadConversation: true,
    platform: "GitLab",
    handle: author,
    replyCount: null,
    community: route.community
  };
}

function registerGitLabThreadProfiles() {
  registerHostAwareProfile(true, gitlabThreadContent);
}
