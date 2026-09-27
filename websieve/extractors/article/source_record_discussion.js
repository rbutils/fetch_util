function sourceRecordDiscussionChrome(node) {
  return !node || !node.closest || node.closest(
    "nav, aside, footer, [role='navigation'], [role='complementary'], " +
    "[class*='sidebar' i], [id^='utility-nav-' i], [class*='utility-nav' i], " +
    "[id*='utility-navigation' i], [class*='utility-navigation' i]"
  );
}

function sourceRecordDiscussionCandidates(record) {
  if (!record || !record.recordContainer || !record.recordContainer.querySelectorAll) return [];
  return visibleCommentCandidates(record.recordContainer).filter(function(node) {
    return !sourceRecordDiscussionChrome(node);
  });
}

function sourceRecordHasVisibleDiscussion(record) {
  return sourceRecordDiscussionCandidates(record).length > 0;
}

function sourceRecordCommentThreadBelongsToContainer(thread, record) {
  if (!record || !record.recordContainer || !record.root ||
      !record.recordContainer.contains(thread) || record.root.contains(thread) ||
      !sourceRecordBefore(record.root, thread) ||
      sourceRecordDiscussionChrome(thread)) return false;
  if (!commentThreadHasMaterial(thread)) return false;

  var threadArticle = thread.closest("article");
  var recordArticle = record.root.matches("article") ? record.root : record.root.closest("article");
  return !threadArticle || threadArticle === recordArticle || commentRecordMarker(threadArticle);
}

function sourceRecordDiscussionMarkup(record) {
  var candidates = sourceRecordDiscussionCandidates(record);
  if (!candidates.length) return "";
  if (candidates.some(function(node) { return record.root.contains(node); })) return null;

  var ownership = {
    node: record.recordContainer,
    proof: "source-record-container",
    sourceRecord: record
  };
  var threads = visibleCommentThreadRoots(record.recordContainer).filter(function(thread) {
    return sourceRecordCommentThreadBelongsToContainer(thread, record);
  });
  if (!threads.length || candidates.some(function(node) {
    return !threads.some(function(thread) { return thread === node || thread.contains(node); });
  })) return null;

  return visibleCommentMarkup(record.recordContainer, ownership);
}
