  function skyNewsArabiaArticleContent(metadata) {
    if (!skyNewsArabiaArticlePage()) return null;

    var body = skyNewsArabiaArticleBody();
    if (!body) return null;

    return profileArticleContent(metadata, body, {
      title: firstText([".sna_content_heading", "h1.article-title", ".slide-title", "main h1", "h1"]) || (metadata && metadata.title),
      byline: firstText([".article-sub-heading", "[rel='author']"]) || (metadata && metadata.byline),
      publishedTime: skyNewsArabiaPublishedTime(metadata),
      minTextLength: 250,
      rewriteRoot: function(root) {
        removeAll(root, [
          ".dfp-inread-article",
          "[data-ng-dfp-ad]",
          "[data-ng-dfp-ad-container]",
          "sna-share",
          "sna-related-article",
          ".noprint",
          ".rel_article_cont",
          ".rel_article_group",
          ".rel_article_group_title",
          ".rel_article_item",
          ".related_contents_cont",
          ".related_contents",
          ".article-widget",
          "[class*='widget' i]",
          "[class*='share' i]",
          "[class*='social' i]",
          "[class*='ad_' i]",
          "[id*='ad-' i]"
        ].join(", "));

        root.querySelectorAll("a[href*='/keyword-search']").forEach(function(link) {
          link.removeAttribute("href");
        });

        root.querySelectorAll("p, div, section, h2, h3, a").forEach(function(el) {
          var text = normalizeText(el.textContent || "");
          if (/^(أخبار ذات صلة|الأكثر قراءة|شرق أوسط|اشترك في خدمة الإشعارات|لم تفعّل خدمة إشعارات الأخبار العاجلة)$/i.test(text)) el.remove();
        });
      }
    });
  }

  function skyNewsArabiaArticlePage() {
    if (!hostMatches(/(^|\.)skynewsarabia\.com$/)) return false;
    if (homepageRootPath()) return false;
    return !!document.querySelector(".article-content .article-body, .article-body, [itemprop='articleBody']");
  }

  function skyNewsArabiaArticleBody() {
    var frame = document.querySelector(".article_detail_page") || document.querySelector(".sna_content_body") || document;
    var article = document.createElement("article");

    [".sna_content_heading", "h1.article-title", ".slide-title", "main h1", "h1"].some(function(selector) {
      var node = frame.querySelector(selector) || document.querySelector(selector);
      if (!node) return false;
      article.appendChild(safeDeepClone(node, document));
      return true;
    });

    var meta = frame.querySelector(".article-sub-heading");
    if (meta) article.appendChild(safeDeepClone(meta, document));

    var mediaCaption = frame.querySelector(".article_image_heading_bg, .article-image-caption, .media-caption");
    if (mediaCaption && normalizeText(mediaCaption.textContent || "")) article.appendChild(safeDeepClone(mediaCaption, document));

    var summary = frame.querySelector(".article-summary");
    if (summary && normalizeText(summary.textContent || "")) article.appendChild(safeDeepClone(summary, document));

    var body = frame.querySelector(".article-content .article-body") ||
      frame.querySelector(".article-body") ||
      frame.querySelector("[itemprop='articleBody']") ||
      document.querySelector(".article-content .article-body, .article-body, [itemprop='articleBody']");
    if (body) article.appendChild(safeDeepClone(body, document));

    return normalizeText(article.textContent || "").length >= 250 ? article : null;
  }

  function skyNewsArabiaPublishedTime(metadata) {
    var value = normalizeText((metadata && metadata.publishedTime) || "");
    if (!value) return value;
    return value.replace(/[٠-٩۰-۹]/g, function(ch) {
      var arabicIndic = "٠١٢٣٤٥٦٧٨٩".indexOf(ch);
      if (arabicIndic >= 0) return String(arabicIndic);
      return String("۰۱۲۳۴۵۶۷۸۹".indexOf(ch));
    });
  }

  registerHostAwareProfile(true, skyNewsArabiaArticleContent);