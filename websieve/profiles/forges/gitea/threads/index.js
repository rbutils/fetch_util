function giteaFamilyThreadContent(metadata) {
  var route = giteaFamilyThreadRoute();
  if (!route) return null;

  var root = giteaFamilyThreadRoot(route);
  if (!giteaFamilyProductMatch(route, root)) return null;
  var opening = giteaFamilyOpening(root);
  var author = giteaFamilyThreadAuthor(opening);
  var title = normalizeText(firstText([
    ".issue-title-header h1",
    ".issue-title h1",
    "main h1"
  ]) || metadata.title || document.title);
  if (!opening || !title) return null;

  var openingMarkdown = giteaFamilyThreadNodeMarkdown(opening);
  var openingLink = giteaFamilyThreadPermalink(opening, route);
  var entries = giteaFamilyThreadEntries(root, opening, route);
  var metadataRecord = giteaFamilyThreadMetadata(root);
  var label = route.kind === "pulls" ? "Pull Request" : "Issue";
  var sections = [
    "# " + title,
    "- " + label + ": " + route.community
  ];
  if (author) sections.push("- Author: " + author);
  sections.push("## " + (openingLink ? markdownLink("Opening", openingLink) : "Opening"));
  var openingTime = giteaFamilyThreadTimestamp(opening);
  if (openingTime) sections.push("- Time: " + openingTime);
  if (openingMarkdown) sections.push(openingMarkdown);
  if (metadataRecord.markdown) sections.push("## Metadata", metadataRecord.markdown);
  if (entries.length) sections.push("## Timeline");
  sections = sections.concat(giteaFamilyThreadEntrySections(entries));
  sections.push(giteaFamilyThreadInventory(route));

  var openingClone = visibilityPrunedClone(opening);
  var visibleNodes = [openingClone].concat(entries.map(function(entry) {
    return entry.sourceNode;
  }));
  if (metadataRecord.sourceNode) visibleNodes.push(metadataRecord.sourceNode);
  return {
    title: title,
    byline: author,
    excerpt: normalizeText((visibilityPrunedClone(giteaFamilyThreadBody(opening)) || {}).textContent || ""),
    siteName: metadata.siteName || location.hostname,
    publishedTime: openingTime || metadata.publishedTime,
    html: visibleNodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n"),
    markdown: sections.filter(Boolean).join("\n\n"),
    textContent: normalizeText([title, openingMarkdown].concat(entries.map(function(entry) {
      return entry.markdown;
    })).join(" ")),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    threadConversation: true,
    platform: giteaFamilyPlatform(),
    handle: author,
    replyCount: null,
    community: route.community
  };
}

function registerGiteaFamilyThreadProfiles() {
  registerHostAwareProfile(true, giteaFamilyThreadContent);
}
