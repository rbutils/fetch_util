  function parseInstagramStats(pt) {
    var followerMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Followers|follower|Takipçi|подписчик|متابع)/i);
    var followingMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Following|following)/i);
    var postMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Posts?|post|Gönderi|публикац|منشور)/i);

    return {
      followers: followerMatch && followerMatch[1],
      following: followingMatch && followingMatch[1],
      posts: postMatch && postMatch[1]
    };
  }

  function instagramContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)instagram\.com$/)) return null;
    var pt = bodyInnerText(pageText);

    var pathParts = (location.pathname || "").split("/").filter(Boolean);
    if (/^(accounts|checkpoint|challenge|challenge_required|suspended|restricted)$/i.test(pathParts[0] || "")) {
      var nextParam = (location.search || "").match(/[?&]next=([^&]+)/);
      if (nextParam) {
        var decoded = safeDecodeURI(nextParam[1]);
        decoded = (decoded || "").replace(/^https?:\/\/[^\/]+/, "");
        pathParts = decoded.split("/").filter(Boolean);
      } else {
        pathParts = [];
      }
    }

    var postIndex = -1;
    for (var idx = 0; idx < pathParts.length - 1; idx += 1) {
      if (/^(p|reel|reels|tv)$/i.test(pathParts[idx])) {
        postIndex = idx;
        break;
      }
    }
    var isPostPath = postIndex >= 0;
    var pathSrc = isPostPath ? pathParts[postIndex] : (pathParts[0] || "");
    var pathArg = isPostPath ? (pathParts[postIndex + 1] || "") : (pathParts[1] || "");
    var postPath = isPostPath ? "/" + pathParts.slice(postIndex, postIndex + 2).join("/") + "/" : "";
    var username = safeDecodeURI(pathSrc).replace(/[-_]+/g, " ");
    username = normalizeText(username);
    if (isPostPath || /^(accounts|checkpoint|challenge|challenge_required|explore|stories|direct)$/i.test(username)) username = "";

    if (isPostPath) {
      var rawTitle = normalizeText((metadata.title || "").replace(/\s*[\u2022•|]\s*Instagram.*$/i, "").replace(/\s*\|\s*Instagram\s*$/i, ""));
      var titleMatch = rawTitle.match(/^(.*?)\s+on Instagram:\s*"([\s\S]*)"$/i);
      var authorName = titleMatch ? normalizeText(titleMatch[1]) : "";
      var titleCaption = titleMatch ? normalizeText(titleMatch[2]) : "";
      var rawExcerpt = metadata.excerpt || "";
      if (/create an account|log in to instagram|sign up/i.test(rawExcerpt)) rawExcerpt = "";

      var likesMatch = rawExcerpt.match(/([\d,.]+[MKB]?)\s*likes?\b/i);
      var commentsMatch = rawExcerpt.match(/([\d,.]+[MKB]?)\s*comments?\b/i);
      var handleMatch = rawExcerpt.match(/-\s*([a-z0-9._]+)\s+on\s+/i);
      var publishedMatch = rawExcerpt.match(/\bon\s+([^:]+):\s*"/i);
      var excerptCaptionMatch = rawExcerpt.match(/:\s*"([\s\S]*?)"\.?\s*$/);
      var handle = handleMatch ? normalizeText(handleMatch[1]) : (postIndex > 0 ? normalizeText(pathParts[0]) : "");
      var caption = normalizeText(titleCaption || (excerptCaptionMatch && excerptCaptionMatch[1]) || "");
      var visibleComments = (function() {
        var lines = (pt || "").split(/\n+/).map(normalizeText).filter(Boolean);
        if (!lines.length || !caption) return [];

        var captionIndex = -1;
        var captionNeedle = caption.toLowerCase();
        for (var li = 0; li < lines.length; li += 1) {
          var line = lines[li].toLowerCase();
          if (line.indexOf(captionNeedle) >= 0 || captionNeedle.indexOf(line) >= 0) {
            captionIndex = li;
            break;
          }
        }
        if (captionIndex < 0) return [];

        var comments = [];
        for (var i = captionIndex + 1; i < lines.length; i += 1) {
          var user = lines[i];
          var age = normalizeText(lines[i + 1] || "");
          if (/^(?:\d[\d.,]*[KMB]?|log in to like or comment\.?|more posts from\b|see more posts\b|meta\b|about\b|blog\b|jobs\b|help\b|api\b|privacy\b|terms\b|locations\b|instagram lite\b|meta ai\b|threads\b)/i.test(user)) break;
          if (!/^[a-z0-9._]{2,32}$/i.test(user) || !/^(?:\d+\s*(?:s|m|h|d|w)|just now|now)$/i.test(age)) continue;

          var textLines = [];
          var j = i + 2;
          for (; j < lines.length; j += 1) {
            var lineText = lines[j];
            var nextLine = normalizeText(lines[j + 1] || "");
            if (/^(?:like|reply|follow|following)$/i.test(lineText)) break;
            if (/^(?:\d[\d.,]*[KMB]?|log in to like or comment\.?|more posts from\b|see more posts\b|meta\b|about\b|blog\b|jobs\b|help\b|api\b|privacy\b|terms\b|locations\b|instagram lite\b|meta ai\b|threads\b)/i.test(lineText)) break;
            if (/^[a-z0-9._]{2,32}$/i.test(lineText) && /^(?:\d+\s*(?:s|m|h|d|w)|just now|now)$/i.test(nextLine)) break;
            textLines.push(lineText);
          }

          var commentText = normalizeText(textLines.join(" "));
          if (commentText) comments.push("@" + user + ": " + commentText);
          i = j;
        }

        return comments;
      })();
      var hasVisiblePost = (function() {
        var article = visibleMetaSocialRoot("article");
        if (article) {
          var articleText = normalizeText(article && article.innerText);
          if (/something went wrong|log in to instagram|sign up to see/i.test(articleText)) return false;
          if (article.querySelector('img, video')) return true;
          if (articleText.length > 40) return true;
        }

        return false;
      })();

      var details = [];
      var pathLabel = /^(reel|reels|tv)$/i.test(pathSrc) ? "Reel" : "Post";
      if (handle) details.push("Profile: @" + handle);
      if (postPath) details.push(pathLabel + ": " + postPath);
      if (likesMatch) details.push(normalizeText(likesMatch[1]) + " likes");
      if (commentsMatch) details.push(normalizeText(commentsMatch[1]) + " comments");
      if (metadata.image) details.push("Image: " + metadata.image);
      if (metadata.video) details.push("Video: " + metadata.video);

      if (hasVisiblePost) {
        var content = articleContentFromParts({
          title: authorName ? authorName + " on Instagram" : (rawTitle || "Instagram post"),
          byline: handle ? "@" + handle : (authorName || null),
          publishedTime: publishedMatch ? normalizeText(publishedMatch[1]) : (metadata.publishedTime || null),
          description: caption || "Instagram post",
          details: details,
          siteName: metadata.siteName || "Instagram",
          hostAware: true,
          contentType: "social",
          socialKind: "post",
          platform: "Instagram",
          handle: handle ? "@" + handle.replace(/^@/, "") : null
        });

        if (visibleComments.length) {
          content.markdown += "\n\n## Comments\n\n" + visibleComments.map(function(comment) {
            return "- " + comment;
          }).join("\n");
          content.textContent = normalizeText(content.markdown);
        }

        return content;
      }

      return null;
    }

    var hasProfileContent = (function() {
      var headerSection = visibleMetaSocialRoot('header section');
      if (!headerSection) return false;
      var headerText = headerSection.innerText || "";
      if (/([\d,.]+[MKB]?)\s*(followers?|following|posts?)/i.test(headerText)) return true;
      var imgs = document.querySelectorAll('article img, main img[srcset]');
      if (imgs.length >= 3) return true;
      return false;
    })();

    if (hasProfileContent) {
      var title = normalizeText((metadata.title || "").replace(/\s*[\u2022•|]\s*Instagram.*$/i, "")) || metadata.title;

      var headerSection = document.querySelector('header section');
      var bioText = "";
      if (headerSection) {
        var spans = headerSection.querySelectorAll('span');
        for (var i = 0; i < spans.length; i++) {
          var spanText = normalizeText(spans[i].innerText || "");
          if (spanText.length > 30 && !/^\d/.test(spanText) && !/follow/i.test(spanText)) {
            bioText = spanText;
            break;
          }
        }
      }

      var stats = [];
      var parsedStats = parseInstagramStats(pt);
      if (parsedStats.posts) stats.push(parsedStats.posts + " posts");
      if (parsedStats.followers) stats.push(parsedStats.followers + " followers");
      if (parsedStats.following) stats.push(parsedStats.following + " following");

      var description = bioText || metadata.excerpt || "";
      if (/create an account|log in to instagram|sign up/i.test(description)) description = "";
      if (stats.length) {
        description = (description ? description + "\n\n" : "") + stats.join(", ") + ".";
      }

      var details = [];
      if (username) details.push("Profile: @" + pathSrc);

      return articleContentFromParts({
        title: title || ("Instagram" + (username ? " - " + username : "")),
        description: description,
          details: details,
          siteName: metadata.siteName || "Instagram",
          hostAware: true,
          contentType: "social",
          socialKind: "profile",
          platform: "Instagram",
          handle: username ? "@" + pathSrc : null
      });
    }
    return null;
  }

  function registerInstagramProfiles() {
    registerHostAwareProfile(true, instagramContent);
  }
