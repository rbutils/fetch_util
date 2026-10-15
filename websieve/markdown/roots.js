  function markdownFor(html, allowSerializedOwnedPublicPreviews, allowArticleMailto, preserveCleanedRoot, convertRoot) {
    if (typeof TurndownService !== "function") return html;
    var root = document.createElement("div");
    root.innerHTML = html;
    return convertMarkdownRoot(root, allowSerializedOwnedPublicPreviews, allowArticleMailto, preserveCleanedRoot, convertRoot);
  }

  function markdownFromDisposableRoot(root, allowSerializedOwnedPublicPreviews, allowArticleMailto, preserveCleanedRoot, convertRoot) {
    if (typeof TurndownService !== "function") return root.innerHTML;
    if (!disposableDomRoot(root) || root.namespaceURI !== "http://www.w3.org/1999/xhtml" || root.localName !== "div") {
      return markdownFor(root.innerHTML, allowSerializedOwnedPublicPreviews, allowArticleMailto, preserveCleanedRoot, convertRoot);
    }
    return convertMarkdownRoot(root, allowSerializedOwnedPublicPreviews, allowArticleMailto, preserveCleanedRoot, convertRoot);
  }
