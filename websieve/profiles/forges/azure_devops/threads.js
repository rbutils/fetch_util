function azureDevopsPullRequestContent(metadata) {
  var route = azureDevopsPullRequestRoute();
  if (!route || !azureDevopsPullRequestProductMatch(route)) return null;
  var state = window.__fetchUtilAzureDevopsPullRequest;
  if (state && state.status === "failed") return azureDevopsFailedPullRequestContent(metadata, route, state);
  var prepared = azureDevopsPreparedPullRequest(route);
  if (!prepared) return null;

  var pullRequest = prepared.metadata;
  var title = normalizeText(pullRequest.title || metadata.title || document.title);
  if (!title) return null;
  var author = azureDevopsAccountName(pullRequest.createdBy);
  var description = String(pullRequest.description || "");
  var sections = ["# " + title].concat(azureDevopsPullRequestMetadata(pullRequest));
  if (author) sections.push("- Author: " + author);
  if (description) sections.push("## Description", azureDevopsLiteralBlock(description));
  var pullRequestData = azureDevopsSupplementalData(pullRequest, {
    title: true, description: true, reviewers: true
  });
  if (pullRequestData) sections.push("## Pull request data", pullRequestData);
  var reviewers = azureDevopsReviewerSections(pullRequest.reviewers);
  if (reviewers.length) sections = sections.concat(["## Reviewers"], reviewers);
  if (prepared.threads.value.length) {
    sections = sections.concat(["## Conversation"], azureDevopsThreadSections(prepared.threads.value));
  }
  if (prepared.commits.length) sections = sections.concat(["## Source commits"], azureDevopsCommitSections(prepared.commits));
  sections.push(azureDevopsPullRequestInventory(prepared));

  var markdown = sections.filter(Boolean).join("\n\n");
  var article = document.createElement("article");
  article.setAttribute("data-fetch-util-azure-devops-pr", route.number);
  var pre = document.createElement("pre");
  pre.textContent = markdown;
  article.appendChild(pre);
  var replies = prepared.threads.value.reduce(function(total, thread) {
    return total + (Array.isArray(thread.comments) ? thread.comments.length : 0);
  }, 0);
  return {
    title: title,
    byline: author,
    excerpt: normalizeText(description || title),
    siteName: "Azure DevOps",
    publishedTime: normalizeText(pullRequest.creationDate) || metadata.publishedTime,
    modifiedTime: normalizeText(pullRequest.closedDate) || metadata.modifiedTime,
    html: article.outerHTML,
    markdown: markdown,
    textContent: normalizeText(markdown),
    hostAware: true,
    readerMode: false,
    contentType: "social",
    socialKind: "thread",
    threadConversation: true,
    platform: "Azure DevOps",
    handle: author,
    replyCount: replies,
    community: route.project + "/" + route.repository
  };
}

function registerAzureDevopsPullRequestProfiles() {
  registerHostAwareProfile(true, azureDevopsPullRequestContent);
}
