function sourcehutListsArchiveThreadContent(metadata) {
  var route = sourcehutListsArchiveThreadRoute();
  if (!route) return null;
  var root = sourcehutListsArchiveThreadRoot();
  if (!sourcehutListsArchiveThreadProductMatch(route, root)) return null;
  var records = sourcehutListsArchiveRecords(root, route);
  var opening = records[0];
  if (!opening) return null;

  var title = opening.subject || normalizeText(metadata.title).replace(/\s*[—-]\s*[^—-]+\s+lists\s*$/i, "") || "SourceHut thread";
  var sections = ["# " + title, "- List: " + route.community];
  if (opening.author) sections.push("- Author: " + opening.author);
  if (opening.timestamp) sections.push("- Started: " + opening.timestamp);
  sections.push("## Opening message", opening.markdown);
  if (records.length > 1) {
    sections.push("## Replies");
    sections = sections.concat(sourcehutListsRecordSections(records.slice(1)));
  }
  sections.push(sourcehutListsArchiveInventory(route, root, records));

  var markdown = sections.filter(Boolean).join("\n\n");
  return {
    title: title,
    byline: opening.author,
    excerpt: normalizeText(opening.markdown),
    siteName: "SourceHut lists",
    publishedTime: opening.timestamp || null,
    html: records.map(function(record) { return record.sourceNode.outerHTML; }).join("\n"),
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    threadConversation: true,
    platform: "SourceHut",
    handle: opening.author,
    replyCount: records.length - 1,
    community: route.community
  };
}

function registerSourcehutListsArchiveThreadProfiles() {
  registerHostAwareProfile(true, sourcehutListsArchiveThreadContent);
}
