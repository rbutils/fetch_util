function sourcehutTodoEntrySections(entries) {
  var sections = [];
  entries.forEach(function(entry) {
    var heading = entry.kind + (entry.author ? " by " + entry.author : "");
    if (entry.permalink) heading = markdownLink(heading, entry.permalink);
    sections.push("### " + heading);
    if (entry.timestamp) sections.push("- Time: " + entry.timestamp);
    sections.push(entry.markdown);
  });
  return sections;
}

function sourcehutTodoTicketContent(metadata) {
  var route = sourcehutTodoRoute();
  if (!route) return null;
  var root = sourcehutTodoRoot();
  if (!sourcehutTodoProductMatch(route, root)) return null;
  var opening = root.querySelector("#description-field");
  var title = normalizeText((root.querySelector(".ticket-title") || {}).textContent || "");
  var author = sourcehutTodoMetadataField(root, "Submitter");
  var openingMarkdown = sourcehutTodoNodeMarkdown(opening);
  var ticketMetadata = sourcehutTodoMetadata(root);
  var entries = sourcehutTodoEntries(root, route);
  var sections = ["# " + title, "- Ticket: " + route.community + "#" + route.number];
  if (author) sections.push("- Author: " + author);
  sections.push("## " + markdownLink("Opening", location.origin + route.ticketPath));
  if (openingMarkdown) sections.push(openingMarkdown);
  if (ticketMetadata) sections.push("## Metadata", ticketMetadata.markdown);
  if (entries.length) sections.push("## Timeline");
  sections = sections.concat(sourcehutTodoEntrySections(entries));
  var email = sourcehutTodoEmailInstruction(root, route);
  if (email) sections.push(email);
  sections.push(sourcehutTodoInventory(route, root));

  var visibleNodes = [opening && visibilityPrunedClone(opening)].concat(entries.map(function(entry) {
    return entry.sourceNode;
  }));
  if (ticketMetadata) visibleNodes.push(ticketMetadata.node);
  return {
    title: title,
    byline: author,
    excerpt: normalizeText(openingMarkdown),
    siteName: "SourceHut todo",
    publishedTime: null,
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
    platform: "SourceHut",
    handle: author,
    replyCount: null,
    community: route.community
  };
}

function registerSourcehutTodoThreadProfiles() {
  registerHostAwareProfile(true, sourcehutTodoTicketContent);
}
