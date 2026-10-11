function sourceOwnedCommentInterfaceNotice(node) {
  if (!node || !node.matches("p") || elementSubtreeHidden(node) ||
      !/(?:^|[-_\s])(?:reminder|disclaimer|notice)(?:$|[-_\s])/i.test(node.className || "") ||
      node.querySelector("a, img, picture, video, audio, code, button, input, textarea, select") ||
      node.closest("blockquote, pre, [itemprop~='text' i], [class*='comment-body' i], [class*='reply-body' i]")) return false;
  for (var parent = node.parentElement; parent && parent !== document.body; parent = parent.parentElement) {
    if (commentRecordMarker(parent)) return false;
    if (parent.matches(VISIBLE_COMMENT_RECORD_SELECTOR)) break;
  }
  if (!parent || parent === document.body) return false;
  var editor = node.previousElementSibling;
  return !!(editor && editor.querySelector("form textarea") &&
    !editor.querySelector("p, blockquote, pre, code, table, img, picture, video, audio, [itemprop~='comment' i]"));
}

function sourceOwnedCommentInterfaceOnlyThread(thread) {
  var notices = Array.from(thread.querySelectorAll("p")).filter(sourceOwnedCommentInterfaceNotice);
  if (!notices.length || !thread.querySelector("form textarea")) return false;
  var visible = visibilityPrunedClone(thread, document);
  if (hasMarkedCommentContent(visible)) return false;
  var material = Array.from(thread.querySelectorAll("p, blockquote, pre, code, table, img, picture, video, audio, [itemprop~='text' i]"));
  if (material.some(function(node) {
    return !elementSubtreeHidden(node) && notices.indexOf(node) === -1 && !node.closest("form");
  })) return false;
  var walker = document.createTreeWalker(thread, NodeFilter.SHOW_TEXT);
  var text;
  while ((text = walker.nextNode())) {
    if (!normalizeText(text.nodeValue || "") || elementVisuallyHidden(text.parentElement)) continue;
    if (text.parentElement.closest("script, style, form, button")) continue;
    var navigation = text.parentElement.closest("a[href]");
    if (navigation && /(?:^|[-_\s])(?:show-all|view-all|more|comment-nav)(?:$|[-_\s])/i.test(navigation.className || "")) continue;
    if (notices.some(function(notice) { return notice.contains(text.parentElement); })) continue;
    if (notices.some(function(notice) { return notice.previousElementSibling.contains(text.parentElement); })) continue;
    return false;
  }
  return true;
}

function stripSourceOwnedCommentInterfaceNotices(source, clone, sourceClones) {
  Array.from(source.querySelectorAll("p")).filter(sourceOwnedCommentInterfaceNotice).forEach(function(notice) {
    var mapped = sourceClones.get(notice);
    if (mapped && clone.contains(mapped) && normalizeText(mapped.textContent || "") === normalizeText(notice.textContent || "")) mapped.remove();
  });
}
