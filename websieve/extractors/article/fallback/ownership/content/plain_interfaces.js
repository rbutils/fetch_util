function sourceOwnedPlainArticleInterfaceNodes(ownership) {
  var body = ownership.body.sourceNode;
  var owner = ownership.ownerRoot;
  var threads = visibleCommentThreadRoots(owner);
  var controls = Array.from(owner.querySelectorAll("div, section")).filter(function(node) {
    if (node === owner || node.contains(body) || body.contains(node) || elementSubtreeHidden(node) ||
        !sourceOwnedHeaderPrecedesBody(node, body)) return false;
    var visible = visibilityPrunedClone(node, document);
    if (visible.querySelector("p, h1, h2, h3, blockquote, pre, code, table, figure, img[src], video, audio, form")) return false;
    var sharing = Array.from(node.querySelectorAll("[class*='share' i]")).some(function(child) {
      return /(?:^|[-_\s])share(?:$|[-_\s])/i.test(child.className || "");
    });
    var commentLink = Array.from(node.querySelectorAll("a[href]")).some(function(link) {
      var href = link.getAttribute("href") || "";
      return href.charAt(0) === "#" && threads.some(function(thread) { return thread.id && href === "#" + thread.id; });
    });
    var ownedBranches = Array.from(node.children).filter(function(child) { return !elementSubtreeHidden(child); }).every(function(child) {
      if (/(?:^|[-_\s])share(?:$|[-_\s])/i.test(child.className || "")) return true;
      var links = Array.from(child.querySelectorAll("a[href]"));
      return links.some(function(link) {
        return threads.some(function(thread) { return thread.id && link.getAttribute("href") === "#" + thread.id; });
      }) && /^[\d\s]*$/.test(normalizeText(child.textContent || ""));
    });
    return sharing && commentLink && ownedBranches && !Array.from(node.childNodes).some(function(child) {
      return child.nodeType === Node.TEXT_NODE && normalizeText(child.nodeValue || "");
    });
  });
  var crumbs = Array.from(owner.querySelectorAll("div, section, nav")).filter(function(node) {
    if (!/(?:^|[-_\s])(?:crumb|breadcrumbs?)(?:$|[-_\s])/i.test(node.className || "") ||
        !sourceOwnedHeaderPrecedesBody(node, ownership.heading) || elementSubtreeHidden(node)) return false;
    return node.querySelectorAll("a[href]").length > 1 && !node.querySelector("p, h1, h2, h3, blockquote, pre, code, table, figure, img, video, audio");
  });
  return controls.concat(crumbs, threads.filter(sourceOwnedCommentInterfaceOnlyThread));
}

function sourceOwnedPlainArticleInterfaceNode(node, ownership) {
  return ownership.proof === "unique-canonical-headed-body-branch" &&
    (ownership.interfaceNodes || []).some(function(root) { return root === node || root.contains(node); });
}
