function azureDevopsPullRequestMetadata(metadata) {
  var repository = metadata.repository || {};
  var project = repository.project || {};
  var sections = [
    "- Project: " + normalizeText(project.name),
    "- Repository: " + normalizeText(repository.name),
    "- Pull request: " + normalizeText(metadata.pullRequestId)
  ];
  if (metadata.status) sections.push("- Status: " + metadata.status);
  if (metadata.isDraft != null) sections.push("- Draft: " + (metadata.isDraft ? "yes" : "no"));
  if (metadata.sourceRefName) sections.push("- Source: " + metadata.sourceRefName.replace(/^refs\/heads\//, ""));
  if (metadata.targetRefName) sections.push("- Target: " + metadata.targetRefName.replace(/^refs\/heads\//, ""));
  if (metadata.creationDate) sections.push("- Created: " + metadata.creationDate);
  if (metadata.closedDate) sections.push("- Closed: " + metadata.closedDate);
  if (metadata.mergeStatus) sections.push("- Merge status: " + metadata.mergeStatus);
  if (metadata.mergeId) sections.push("- Merge ID: " + metadata.mergeId);
  return sections;
}

function azureDevopsVoteLabel(vote) {
  return {
    "10": "Approved",
    "5": "Approved with suggestions",
    "0": "No vote",
    "-5": "Waiting for author",
    "-10": "Rejected"
  }[String(vote)] || String(vote);
}

function azureDevopsSupplementalValue(key, value) {
  if (Array.isArray(value)) {
    return value.map(function(entry) {
      return azureDevopsSupplementalValue(key, entry);
    }).filter(function(entry) { return entry !== undefined; });
  }
  if (value && typeof value === "object") {
    var result = {};
    Object.keys(value).forEach(function(childKey) {
      var child = azureDevopsSupplementalValue(childKey, value[childKey]);
      if (child !== undefined) result[childKey] = child;
    });
    return result;
  }
  if (typeof value === "string" && /(?:urls?|hrefs?|links?)$/i.test(key)) {
    return materializedHttpUrl(value) || undefined;
  }
  return value;
}

function azureDevopsSafeDataBlock(value) {
  return azureDevopsLiteralBlock(JSON.stringify(azureDevopsSupplementalValue("", value), null, 2));
}

function azureDevopsSupplementalData(value, excludedKeys) {
  var data = {};
  Object.keys(value || {}).forEach(function(key) {
    if (excludedKeys[key] || value[key] == null) return;
    var supplemental = azureDevopsSupplementalValue(key, value[key]);
    if (supplemental !== undefined) data[key] = supplemental;
  });
  return Object.keys(data).length ? azureDevopsLiteralBlock(JSON.stringify(data, null, 2)) : "";
}

function azureDevopsReviewerSections(reviewers) {
  var sections = [];
  (Array.isArray(reviewers) ? reviewers : []).forEach(function(reviewer) {
    var name = azureDevopsAccountName(reviewer) || "Unknown reviewer";
    sections.push("### " + name, "- Vote: " + azureDevopsVoteLabel(reviewer.vote));
    if (reviewer.isRequired != null) sections.push("- Required: " + (reviewer.isRequired ? "yes" : "no"));
    if (reviewer.hasDeclined != null) sections.push("- Declined: " + (reviewer.hasDeclined ? "yes" : "no"));
    if (reviewer.isFlagged != null) sections.push("- Flagged: " + (reviewer.isFlagged ? "yes" : "no"));
    if (reviewer.uniqueName) sections.push("- Identity: " + reviewer.uniqueName);
    var data = azureDevopsSupplementalData(reviewer, {
      displayName: true, uniqueName: true, vote: true, isRequired: true, hasDeclined: true, isFlagged: true
    });
    if (data) sections.push("#### Reviewer data", data);
  });
  return sections;
}

function azureDevopsThreadContext(thread) {
  var sections = [];
  var context = thread.threadContext || {};
  var pullContext = thread.pullRequestThreadContext || {};
  if (context.filePath) sections.push("- File: " + context.filePath);
  ["rightFileStart", "rightFileEnd", "leftFileStart", "leftFileEnd"].forEach(function(name) {
    var position = context[name];
    if (position && position.line != null) {
      sections.push("- " + name + ": " + position.line + (position.offset != null ? ":" + position.offset : ""));
    }
  });
  if (pullContext.changeTrackingId != null) sections.push("- Change tracking ID: " + pullContext.changeTrackingId);
  if (Object.keys(context).length) sections.push("#### Thread context", azureDevopsSafeDataBlock(context));
  if (Object.keys(pullContext).length) {
    sections.push("#### Pull request thread context", azureDevopsSafeDataBlock(pullContext));
  }
  if (thread.properties && Object.keys(thread.properties).length) {
    sections.push("#### Properties", azureDevopsSafeDataBlock(thread.properties));
  }
  return sections;
}

function azureDevopsThreadSections(threads) {
  var sections = [];
  (Array.isArray(threads) ? threads : []).forEach(function(thread) {
    var comments = Array.isArray(thread && thread.comments) ? thread.comments : [];
    var threadData = azureDevopsSupplementalData(thread, {
      comments: true, threadContext: true, pullRequestThreadContext: true, properties: true
    });
    if (!comments.length) {
      sections.push("### Thread " + normalizeText(thread.id));
      if (thread.status) sections.push("- Status: " + thread.status);
      if (thread.isDeleted) sections.push("- Deleted thread: yes");
      if (thread.publishedDate) sections.push("- Published: " + thread.publishedDate);
      if (thread.lastUpdatedDate) sections.push("- Updated: " + thread.lastUpdatedDate);
      sections = sections.concat(azureDevopsThreadContext(thread));
      if (threadData) sections.push("#### Thread data", threadData);
      return;
    }
    comments.forEach(function(comment, index) {
      var type = comment.isDeleted ? "Deleted comment" : (normalizeText(comment.commentType) || "Comment");
      var author = azureDevopsAccountName(comment.author);
      sections.push("### " + type + (author ? " by " + author : ""));
      if (thread.id != null) sections.push("- Thread ID: " + thread.id);
      if (comment.id != null) sections.push("- Comment ID: " + comment.id);
      if (comment.parentCommentId) sections.push("- Parent comment ID: " + comment.parentCommentId);
      if (thread.status) sections.push("- Thread status: " + thread.status);
      if (thread.isDeleted) sections.push("- Deleted thread: yes");
      if (thread.publishedDate) sections.push("- Thread published: " + thread.publishedDate);
      if (thread.lastUpdatedDate) sections.push("- Thread updated: " + thread.lastUpdatedDate);
      if (comment.publishedDate) sections.push("- Published: " + comment.publishedDate);
      if (comment.lastUpdatedDate) sections.push("- Updated: " + comment.lastUpdatedDate);
      if (comment.isDeleted) sections.push("- Deleted: yes");
      sections = sections.concat(azureDevopsThreadContext(thread));
      if (index === 0 && threadData) sections.push("#### Thread data", threadData);
      var commentData = azureDevopsSupplementalData(comment, { content: true, author: true });
      if (commentData) sections.push("#### Comment data", commentData);
      if (comment.content) sections.push(azureDevopsLiteralBlock(comment.content));
      else if (comment.isDeleted) sections.push("    [Deleted comment body unavailable.]");
    });
  });
  return sections;
}

function azureDevopsCommitSections(commits) {
  var sections = [];
  (Array.isArray(commits) ? commits : []).forEach(function(commit) {
    sections.push("### Commit " + normalizeText(commit.commitId));
    if (commit.author && azureDevopsAccountName(commit.author)) {
      sections.push("- Author: " + azureDevopsAccountName(commit.author));
    }
    if (commit.author && commit.author.date) sections.push("- Authored: " + commit.author.date);
    if (commit.committer && azureDevopsAccountName(commit.committer)) {
      sections.push("- Committer: " + azureDevopsAccountName(commit.committer));
    }
    if (commit.committer && commit.committer.date) sections.push("- Committed: " + commit.committer.date);
    if (commit.changeCounts) {
      Object.keys(commit.changeCounts).forEach(function(kind) {
        sections.push("- " + kind + ": " + commit.changeCounts[kind]);
      });
    }
    if (commit.commentTruncated) sections.push("- Commit message incomplete: yes");
    if (commit.comment) sections.push(azureDevopsLiteralBlock(commit.comment));
    var data = azureDevopsSupplementalData(commit, { comment: true });
    if (data) sections.push("#### Commit data", data);
  });
  return sections;
}
