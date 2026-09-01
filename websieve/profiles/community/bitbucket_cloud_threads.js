function bitbucketCloudThreadOpeningMarkdown(opening) {
  var body = opening && opening.querySelector("[data-testid='pull-request-description'], [data-testid='description-content']");
  return bitbucketCloudNodeMarkdown(body || opening);
}

function bitbucketCloudCommentBody(node) {
  return bitbucketCloudOwnedCommentNode(node, "[data-testid='comment-content'], comment-content");
}

function bitbucketCloudCommentSourceNode(node) {
  var clone = bitbucketCloudVisibleClone(node);
  if (!clone) return null;
  removeAll(clone, "[data-testid='comment']");
  return clone;
}

function bitbucketCloudThreadEntry(node, route) {
  var body = bitbucketCloudCommentBody(node);
  var context = bitbucketCloudOwnedCommentNode(
    node,
    "[data-testid='multiline-comment-header'], [data-testid='inline-comment-context']"
  );
  var markdown = [bitbucketCloudNodeMarkdown(context), bitbucketCloudNodeMarkdown(body)].filter(Boolean).join("\n\n");
  if (!normalizeText(markdown)) return null;

  var permalink = bitbucketCloudThreadPermalink(node, route);
  var kind = permalink && /\/(?:_\/)?diff#comment-\d+$/.test(permalink) ? "Review" : "Comment";
  return {
    sourceNode: bitbucketCloudCommentSourceNode(node),
    kind: kind,
    author: bitbucketCloudThreadAuthor(node),
    markdown: markdown,
    permalink: permalink,
    timestamp: bitbucketCloudThreadTimestamp(node)
  };
}

function bitbucketCloudThreadEntries(root, opening, route) {
  var nodes = Array.prototype.slice.call(root.querySelectorAll("[data-testid='comment']"));
  var records = nodes.filter(function(node) {
    return !elementSubtreeHidden(node) && node !== opening && !node.contains(opening) && !opening.contains(node);
  });
  var seenIdentities = new Set();
  return records.map(function(node) {
    return bitbucketCloudThreadEntry(node, route);
  }).filter(function(entry) {
    if (!entry || !entry.permalink) return !!entry;
    var identity = "";
    try { identity = new URL(entry.permalink).hash; } catch (_error) {}
    if (!identity || seenIdentities.has(identity)) return !identity;
    seenIdentities.add(identity);
    return true;
  });
}

function bitbucketCloudThreadMetadata(root) {
  var selectors = ["[data-testid='pr-cards-list']", "[data-testid='bb-sidebar']"];
  var sections = [];
  var seen = new Set();
  selectors.forEach(function(selector) {
    Array.prototype.slice.call(root.querySelectorAll(selector)).forEach(function(node) {
      if (elementSubtreeHidden(node)) return;
      var markdown = bitbucketCloudNodeMarkdown(node);
      var identity = normalizeText(markdown);
      if (!identity || seen.has(identity)) return;
      seen.add(identity);
      sections.push(markdown);
    });
  });
  return sections.length ? "## Metadata\n\n" + sections.join("\n\n") : "";
}

function bitbucketCloudThreadEntrySections(entries) {
  var sections = [];
  entries.forEach(function(entry) {
    var label = entry.kind + (entry.author ? " by " + entry.author : "");
    sections.push("### " + (entry.permalink ? markdownLink(label, entry.permalink) : label));
    if (entry.timestamp) sections.push("- Time: " + entry.timestamp);
    sections.push(entry.markdown);
  });
  return sections;
}

function bitbucketCloudPullRequestContent(metadata) {
  var route = bitbucketCloudPullRequestRoute();
  if (!route) return null;

  var root = bitbucketCloudPullRequestRoot();
  if (!bitbucketCloudProductMatch(route, root)) return null;
  var opening = bitbucketCloudPullRequestOpening(root);
  if (!opening || elementSubtreeHidden(opening)) return null;

  var title = normalizeText(bitbucketCloudScopedText(root, [
    "[data-testid='pr-header'] h1", "[data-testid='pull-request-title']", "h1"
  ]) || metadata.title || document.title);
  if (!title) return null;

  var openingMarkdown = bitbucketCloudThreadOpeningMarkdown(opening);
  var author = bitbucketCloudThreadAuthor(opening) || bitbucketCloudScopedText(root, ["[data-testid='pull-request-author']"]);
  var entries = bitbucketCloudThreadEntries(root, opening, route);
  var sections = ["# " + title];
  if (author) sections.push("- Author: " + author);
  sections.push("- Pull Request: " + route.community,
                "## " + markdownLink("Opening", bitbucketCloudRouteUrl(route)));
  if (openingMarkdown) sections.push(openingMarkdown);
  var metadataMarkdown = bitbucketCloudThreadMetadata(root);
  if (metadataMarkdown) sections.push(metadataMarkdown);
  if (entries.length) sections.push("## Conversation");
  sections = sections.concat(bitbucketCloudThreadEntrySections(entries));
  sections.push(browsableInventory("Browse this Bitbucket pull request", bitbucketCloudInventoryEntries(route)));

  var visibleNodes = [bitbucketCloudVisibleClone(opening)].concat(entries.map(function(entry) { return entry.sourceNode; }));
  var markdown = sections.filter(Boolean).join("\n\n");
  return {
    title: title,
    byline: author,
    excerpt: normalizeText(openingMarkdown),
    siteName: "Bitbucket",
    publishedTime: bitbucketCloudThreadTimestamp(opening) || metadata.publishedTime,
    html: visibleNodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n"),
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    threadConversation: true,
    platform: "Bitbucket",
    handle: author,
    replyCount: null,
    community: route.community
  };
}

function registerBitbucketCloudThreadProfiles() {
  registerHostAwareProfile(true, bitbucketCloudPullRequestContent);
}
