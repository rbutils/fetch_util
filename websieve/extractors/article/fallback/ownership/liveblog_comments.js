function sourceOwnedLiveblogDiscussionRoots(ownership) {
  var context = ownership.context;
  var owners = [context.parentRoot].concat(context.records.map(function(record) { return record.node; }));
  return visibleCommentThreadRoots(document).filter(function(thread) {
    return commentThreadHasMaterial(thread) && owners.some(function(owner) {
      return focalCommentThreadBelongsToArticle(thread, { node: owner, ownerRoot: owner, proof: "liveblog-parent" });
    });
  });
}

function sourceOwnedLiveblogCommentFooters(ownership, discussions) {
  var footers = [];
  discussions.forEach(function(thread) {
    if (!ownership.node.contains(thread)) return;
    Array.from(thread.querySelectorAll("footer")).forEach(function(footer) { footers.push(footer); });
  });
  return footers;
}

function appendSourceOwnedLiveblogDiscussions(article, ownership, discussions) {
  if (ownership.mode !== "parent") return;
  var before = [];
  var after = [];
  discussions.forEach(function(thread) {
    if (ownership.node.contains(thread)) return;
    var preceding = thread.compareDocumentPosition(ownership.node) & Node.DOCUMENT_POSITION_FOLLOWING;
    (preceding ? before : after).push(cleanFocalCommentClone(thread));
  });
  if (before.length) article.insertAdjacentHTML("afterbegin", before.join(""));
  if (after.length) article.insertAdjacentHTML("beforeend", after.join(""));
}
