function gerritChangeMetadata(detail, prepared) {
  var owner = gerritAccountName(detail.owner);
  var sections = ["- Project: " + detail.project, "- Change: " + detail._number];
  if (detail.branch) sections.push("- Branch: " + detail.branch);
  if (detail.status) sections.push("- Status: " + detail.status);
  if (owner) sections.push("- Owner: " + owner);
  if (detail.topic) sections.push("- Topic: " + detail.topic);
  if (detail.created) sections.push("- Created: " + detail.created);
  if (detail.updated) sections.push("- Updated: " + detail.updated);
  sections.push("- Current patch set: " + gerritCurrentPatchset(prepared));
  if (detail.total_comment_count != null) sections.push("- Inline comments reported: " + detail.total_comment_count);
  if (detail.unresolved_comment_count != null) sections.push("- Unresolved comments reported: " + detail.unresolved_comment_count);
  return sections;
}

function gerritChangeDescription(prepared) {
  var revision = gerritCurrentRevision(prepared);
  return String(revision && revision.commit && revision.commit.message || prepared.detail.subject || "");
}

function gerritChangeContent(metadata) {
  var route = gerritChangeRoute();
  if (!route || !gerritChangeProductMatch()) return null;
  var prepared = gerritPreparedChange(route);
  if (!prepared) return null;

  var detail = prepared.detail;
  var title = normalizeText(detail.subject || metadata.title || document.title);
  if (!title) return null;
  var owner = gerritAccountName(detail.owner);
  var description = gerritChangeDescription(prepared);
  var records = gerritTimelineRecords(prepared);
  var sections = ["# " + title].concat(gerritChangeMetadata(detail, prepared));
  if (description) sections.push("## Change description", gerritLiteralBlock(description));
  var labels = gerritLabelSections(detail);
  if (labels.length) sections = sections.concat(["## Labels"], labels);
  if (records.length) sections = sections.concat(["## Timeline"], gerritTimelineSections(records, prepared));
  var files = gerritFileSections(prepared);
  if (files.length) sections = sections.concat(["## Changed files"], files);
  sections.push(gerritChangeInventory(prepared));

  var markdown = sections.filter(Boolean).join("\n\n");
  var article = document.createElement("article");
  article.setAttribute("data-fetch-util-gerrit-change", route.number);
  var pre = document.createElement("pre");
  pre.textContent = markdown;
  article.appendChild(pre);
  var replies = records.filter(function(record) { return record.kind !== "Event"; }).length;
  return {
    title: title,
    byline: owner,
    excerpt: normalizeText(description || title),
    siteName: "Gerrit",
    publishedTime: normalizeText(detail.created) || metadata.publishedTime,
    html: article.outerHTML,
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    threadConversation: true,
    platform: "Gerrit",
    handle: owner,
    replyCount: replies,
    community: detail.project
  };
}

function registerGerritChangeProfiles() {
  registerHostAwareProfile(true, gerritChangeContent);
}
