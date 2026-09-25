  function wordpressArticleCommentThreads(body) {
    var article = body && body.closest("article");
    var match = article && /^post-(\d+)$/.exec(article.id || "");
    var postId = article && (match ? match[1] : article.getAttribute("data-post-id"));
    if (!postId || !body.isConnected) return [];

    var threads = Array.from(document.querySelectorAll(
      ".comment-list, .comments-list, .commentlist, .wp-block-comment-template"
    )).filter(function(thread) {
      if (body.contains(thread) || thread.contains(body) || elementVisuallyHidden(thread) ||
          !(body.compareDocumentPosition(thread) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
      if (thread.closest("aside, nav, [role='complementary'], [role='navigation']")) return false;
      var owner = thread.closest("article");
      if (owner && owner !== article) return false;

      var ids = owner === article ? [postId] : [];
      var declared = thread.closest("[data-post-id]");
      if (declared) ids.push(declared.getAttribute("data-post-id"));
      var area = thread.closest("#comments, .comments-area, .wp-block-comments");
      if (area) area.querySelectorAll("input[name='comment_post_ID'], input[name='postID']").forEach(function(input) {
        ids.push(input.value);
      });
      if (!ids.length || ids.some(function(id) { return id !== postId; })) return false;

      return Array.from(thread.querySelectorAll(
        ".comment-content, .comment_content, .comment-body, .comment-text, .wp-block-comment-content"
      )).some(function(comment) {
        return !elementVisuallyHidden(comment) && hasMaterialCommentContent(comment);
      });
    });
    return threads.filter(function(thread) {
      return !threads.some(function(other) { return other !== thread && other.contains(thread); });
    });
  }

  function wordpressArticleAppendComments(content, threads) {
    if (!content || !threads.length) return content;
    threads.forEach(function(thread) {
      var visible = visibilityPrunedClone(thread, document);
      visible.setAttribute("data-fetchutil-social-comment", "true");
      var root = cleanClone(visible, "header, footer");
      cleanupAgentRoot(root);
      var markdown = cleanupMarkdownNoise(markdownFor(root.outerHTML));
      if (!normalizeText(markdown)) return;
      content.html += root.outerHTML;
      content.markdown += "\n\n" + markdown;
    });
    content.textContent = normalizeText(content.markdown);
    return content;
  }
