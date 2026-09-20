function gerritFileResourceContent(metadata) {
  var route = gerritFileResourceRoute();
  if (!route || !gerritChangeProductMatch()) return null;
  var prepared = gerritPreparedFileResource(route);
  if (!prepared) return null;

  var subject = normalizeText(prepared.detail.subject) || metadata.title || "Gerrit change";
  var title = subject + " - " + prepared.filePath;
  var sections = ["# " + title].concat(gerritDiffMetadataSections(prepared));
  sections.push("## Complete diff", gerritDiffMarkdown(prepared));
  if (prepared.firstParentDiff) {
    sections.push("## Alternative first-parent comparison",
      "This target-only merge route does not encode a base preference, so both Gerrit's default comparison and the explicit first-parent comparison are included.",
      gerritDiffMarkdown(prepared, prepared.firstParentDiff));
  }
  var comments = gerritFileCommentRecords(prepared);
  if (comments.length) sections = sections.concat(["## File comments"], gerritTimelineSections(comments, prepared));
  sections.push(gerritFileResourceInventory(prepared));
  var markdown = sections.filter(Boolean).join("\n\n");

  var article = document.createElement("article");
  article.setAttribute("data-fetch-util-gerrit-file", prepared.filePath);
  var heading = document.createElement("h1");
  heading.textContent = title;
  article.appendChild(heading);
  var pre = document.createElement("pre");
  pre.textContent = markdown;
  article.appendChild(pre);
  return {
    title: title,
    siteName: "Gerrit",
    author: gerritAccountName(prepared.detail.owner),
    publishedTime: normalizeText(prepared.detail.created),
    modifiedTime: normalizeText(prepared.detail.updated),
    excerpt: normalizeText(prepared.detail.subject),
    html: article.outerHTML,
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "list",
    platform: "Gerrit",
    community: normalizeText(prepared.detail.project)
  };
}

function registerGerritFileResourceProfiles() {
  registerHostAwareProfile(true, gerritFileResourceContent);
}
