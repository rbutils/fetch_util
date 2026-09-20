function sourcehutListsPatchsetContent(metadata) {
  var route = sourcehutListsPatchsetRoute();
  if (!route) return null;
  var root = sourcehutListsRoot();
  if (!sourcehutListsProductMatch(route, root)) return null;
  var identity = sourcehutListsIdentity(root);
  var patchInfos = sourcehutListsPatchInfos(root, route);
  var opening = sourcehutListsOpening(root, route, patchInfos);
  var timeline = sourcehutListsTimelineRecords(root, route);
  var patches = sourcehutListsPatchRecords(root, route);
  if (!opening || !patches.length) return null;

  var sections = [
    "# " + identity.title,
    "- List: " + route.community,
    "- Version: " + identity.version,
    "- Status: " + identity.status
  ];
  if (opening.author) sections.push("- Author: " + opening.author);
  if (opening.timestamp) sections.push("- Submitted: " + opening.timestamp);
  sections.push("## " + (opening.generated ? "Generated patch summary" : "Cover letter"), opening.markdown);
  if (timeline.length) sections.push("## Visible review activity");
  sections = sections.concat(sourcehutListsRecordSections(timeline));
  sections.push("## Patches");
  sections = sections.concat(sourcehutListsRecordSections(patches));
  sections.push(sourcehutListsInventory(route, root, patches));

  var visibleNodes = [opening.sourceNode].concat(timeline.map(function(record) {
    return record.sourceNode;
  })).concat(patches.map(function(record) {
    return record.sourceNode;
  }));
  var markdown = sections.filter(Boolean).join("\n\n");
  return {
    title: identity.title,
    byline: opening.author,
    excerpt: normalizeText(opening.markdown),
    siteName: "SourceHut lists",
    publishedTime: opening.timestamp || null,
    html: visibleNodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n"),
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    threadConversation: true,
    platform: "SourceHut",
    handle: opening.author,
    replyCount: null,
    community: route.community
  };
}

function registerSourcehutListsPatchsetProfiles() {
  registerHostAwareProfile(true, sourcehutListsPatchsetContent);
}
