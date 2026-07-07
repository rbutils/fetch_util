  function naverBlogContent(metadata) {
    if (!hostMatches(/(^|\.)blog\.naver\.com$/)) return null;

    var frameDoc = naverBlogFrameDocument();
    var doc = frameDoc || document;
    var root = naverBlogArticleRoot(doc);
    if (!root) return null;

    var title = naverBlogFirstText(doc, [
      ".se-module.se-module-text.se-title-text",
      ".se-title-text span",
      ".se-title .se-title-text",
      ".se-title",
      "h3.se_textarea_title",
      ".pcol1.itemSubjectBoldfont",
      ".htitle",
      "h1"
    ]) || metadata.title;

    return profileHtmlContent(metadata, root, {
      title: title,
      byline: naverBlogFirstText(doc, [".nick", ".blog_author", ".writer", ".se_publishDate + .nick"]),
      minTextLength: 120,
      rewriteRoot: function(clone) {
        clone.querySelectorAll(".post_btn, .post_footer_contents, .comment, .u_likeit_module, .wrap_tag, .post_tag, .se-module-oglink, .se-sticker, .se-map, script, style").forEach(function(el) {
          el.remove();
        });
      }
    });
  }

  function naverBlogFrameDocument() {
    var frame = document.querySelector("iframe#mainFrame, iframe[name='mainFrame']");
    if (!frame) return null;

    try {
      var doc = frame.contentDocument || (frame.contentWindow && frame.contentWindow.document) || null;
      if (naverBlogArticleRoot(doc)) return doc;

      var srcdoc = frame.getAttribute("srcdoc");
      if (srcdoc) return new DOMParser().parseFromString(srcdoc, "text/html");
      return doc;
    } catch (e) {
      return null;
    }
  }

  function naverBlogArticleRoot(doc) {
    if (!doc) return null;
    return doc.querySelector("div.se-main-container") ||
      doc.querySelector("#printpost") ||
      doc.querySelector("#postViewArea") ||
      doc.querySelector(".se_component_wrap") ||
      doc.querySelector(".post-view") ||
      null;
  }

  function naverBlogFirstText(doc, selectors) {
    for (var i = 0; i < selectors.length; i++) {
      var node = doc.querySelector(selectors[i]);
      var text = normalizeText(node && node.textContent);
      if (text) return text;
    }
    return "";
  }

  registerHostAwareProfile(true, naverBlogContent);