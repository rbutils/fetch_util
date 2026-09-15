function stripArticleWidgets(root) {
  var contentSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, blockquote, pre, table, figure";
  root.querySelectorAll(".article-call-to-action, .article-cta, [data-role='article-call-to-action']").forEach(function(node) {
    if (!node.closest("article") || codeContentNode(node)) return;
    if (textLength(node) >= 600 || node.querySelector(contentSelector)) return;
    if (node.querySelector("a[href], button")) node.remove();
  });

  root.querySelectorAll(".loader, .main-loader, [role='status'][aria-busy='true']").forEach(function(node) {
    if (codeContentNode(node)) return;
    if (textLength(node) >= 300 || node.querySelector(contentSelector + ", a[href], time, img, picture, video, audio, [itemprop='author'], [itemprop='comment'], .author, .byline, .comment-body, .reply-body")) return;
    var owner = node.parentElement;
    while (owner) {
      var signature = [owner.id, owner.getAttribute("class"), owner.getAttribute("data-role")].filter(Boolean).join(" ");
      if (/(?:^|[\s_-])(?:comments?|recommendations?|related|read-more)(?:$|[\s_-])/i.test(signature)) {
        node.remove();
        return;
      }
      if (owner === root || owner.tagName === "ARTICLE") break;
      owner = owner.parentElement;
    }
  });
  return root;
}
