  function telegramContent(metadata, pageText) {
    // Handle t.me (channel/group links), telegram.org (blog/apps), and telegra.ph (articles)
    if (!hostMatches(/(^|\.)(t\.me|telegram\.(org|me)|telegra\.ph)$/)) return null;

    var pt = pageText || "";

    // telegra.ph (Telegraph) — standalone article platform
    if (hostMatches(/(^|\.)telegra\.ph$/)) {
      var articleBody = document.querySelector("article, .tl_article");
      if (articleBody) {
        var clone = cleanClone(articleBody);
        if (clone) {
          // Strip "Report content on this page" footer chrome
          removeNodesByText(clone, "a, span, div, p", /^(report content on this page|report|edit)$/i);
          var md = markdownFor(clone.innerHTML) || normalizeText(clone.textContent);
          if (md && normalizeText(md).length > 20) {
            return {
              title: metadata.title || firstText(["h1", ".tl_article_header h1"]),
              excerpt: metadata.excerpt,
              siteName: "Telegraph",
              html: clone.innerHTML,
              markdown: md,
              textContent: normalizeText(md),
              readerMode: false,
              contentType: "article",
              hostAware: true
            };
          }
        }
      }
      return null;
    }

    if (hostMatches(/(^|\.)telegram\.org$/)) return null;

    var isPublicPreview = /^\/s\//i.test(location.pathname);
    var channelName = (location.pathname || "").split("/").filter(Boolean);
    if (isPublicPreview) channelName = channelName.slice(1);
    channelName = channelName[0] || "";

    if (isPublicPreview) {
      var messageContainer = document.querySelector(".tgme_channel_history, .tgme_body, main");
      if (messageContainer) {
        var previewClone = cleanClone(messageContainer);
        if (previewClone) {
          removeNodesByText(previewClone, "a, span, div, i", /^(view in telegram|preview channel|join|open|if you have telegram|you can contact|you can view and join|load more)$/i);
          previewClone.querySelectorAll("[class*='widget_message_author'], [class*='tgme_widget_message_date']").forEach(function(el) {
          });
          var previewMd = markdownFor(previewClone.innerHTML) || normalizeText(previewClone.textContent);
          if (previewMd && normalizeText(previewMd).length > 50) {
            var channelTitle = firstText([".tgme_channel_info_header_title", ".tgme_header_title", "h1"]) || metadata.title || channelName;
            var channelDescEl = document.querySelector(".tgme_channel_info_description");
            var channelDesc = channelDescEl ? normalizeText(channelDescEl.textContent) : "";
            var counterEls = document.querySelectorAll(".counter_value");
            var subscriberCount = counterEls.length > 0 ? normalizeText(counterEls[0].textContent) : "";
            var headerParts = [];
            headerParts.push("# " + channelTitle);
            var headerMeta = ["- Platform: Telegram"];
            if (subscriberCount) headerMeta.push("- " + subscriberCount + " subscribers");
            if (metadata.image) headerMeta.push("- Image: " + metadata.image);
            headerParts.push(headerMeta.join("\n"));
            if (channelDesc) headerParts.push(channelDesc);
            headerParts.push("---\n\n" + previewMd);

            var fullMd = headerParts.join("\n\n");
            return {
              title: channelTitle,
              excerpt: channelDesc || metadata.excerpt,
              siteName: "Telegram",
              html: previewClone.innerHTML,
              markdown: fullMd,
              textContent: normalizeText(fullMd),
              readerMode: false,
              contentType: "article",
              hostAware: true
            };
          }
        }
      }
    }

    var title = firstText([".tgme_page_title", ".tgme_channel_info_header_title", "h1"]) || metadata.title || channelName;
    var descriptionEl = document.querySelector(".tgme_page_description");
    var description = (descriptionEl ? normalizeText(descriptionEl.textContent) : "") || metadata.excerpt || "";
    if (/you can contact .+ right away|if you have telegram/i.test(description)) description = "";

    var extraEl = document.querySelector(".tgme_page_extra");
    var extraText = extraEl ? normalizeText(extraEl.textContent) : "";
    var subscriberMatch = extraText.match(/([\d\s,.]+)\s*(?:subscribers?|members?|online)/i) ||
                          pt.match(/([\d\s,.]+)\s*(?:subscribers?|members?|подписчик|участник)/i);

    var details = ["Platform: Telegram"];
    if (subscriberMatch) details.push(normalizeText(subscriberMatch[1]) + " subscribers");
    if (metadata.image) details.push("Image: " + metadata.image);

    if (!description && !title) return null;

    return articleContentFromParts({
      title: title,
      description: description || "Telegram channel. View in Telegram for full content.",
      details: details,
      siteName: "Telegram",
      hostAware: true
    });
  }
