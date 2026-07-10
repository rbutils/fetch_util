  function eurLexDocumentContent(metadata) {
    var root = document.querySelector("#MainContent .EurlexContent #document1") ||
      document.querySelector("#MainContent .EurlexContent #textTabContent") ||
      document.querySelector("#MainContent .EurlexContent #PP1Contents") ||
      document.querySelector("#MainContent .EurlexContent");
    if (!root || !document.querySelector("#MainContent .EurlexContent")) return null;
    if (!document.querySelector("#op-header") && !document.querySelector(".PageShare")) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 300,
      docsLike: true,
      title: normalizeText(((document.querySelector("#MainContent .EurlexContent #PP1Contents #title, #MainContent .EurlexContent #PP1Contents #englishTitle") || {}).textContent) || ""),
      titleRoot: document.querySelector("#MainContent") || document,
      strip: function(clone) {
        clone.querySelectorAll("#translatedTitle.hidden, #originalTitle.hidden, .hidden, .PageShare, .AffixSidebarWrapper").forEach(function(el) { el.remove(); });
      }
    });
  }
