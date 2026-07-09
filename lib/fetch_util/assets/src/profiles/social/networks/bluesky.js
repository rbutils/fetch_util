  function blueskyContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)bsky\.(app|social)$/)) return null;

    var isProfilePage = !!document.querySelector('[data-testid="profileScreen"], [data-testid="profileView"]');
    var isPostPage = /^\/profile\/[^/]+\/post\//.test(location.pathname);

    if (!isProfilePage && !isPostPage) return null;

    if (isProfilePage && !isPostPage) {
      var nameEl = document.querySelector('[data-testid="profileHeaderDisplayName"]');
      var descEl = document.querySelector('[data-testid="profileHeaderDescription"]');
      var followersEl = document.querySelector('[data-testid="profileHeaderFollowersButton"]');
      var followingEl = document.querySelector('[data-testid="profileHeaderFollowsButton"]');

      var displayName = nameEl ? normalizeText(nameEl.textContent) : "";
      var bio = descEl ? normalizeText(descEl.textContent) : "";

      var handle = "";
      var pathParts = (location.pathname || "").split("/").filter(Boolean);
      if (pathParts[0] === "profile" && pathParts[1]) {
        handle = "@" + pathParts[1];
      }

      var followers = "";
      var following = "";
      if (followersEl) {
        var fAria = followersEl.getAttribute("aria-label") || "";
        var fMatch = fAria.match(/^([\d,]+)\s+followers/i);
        if (fMatch) {
          followers = fMatch[1];
        } else {
          followers = normalizeText(followersEl.textContent).replace(/\s*followers?$/i, "").trim();
        }
      }
      if (followingEl) {
        var fgAria = followingEl.getAttribute("aria-label") || "";
        var fgMatch = fgAria.match(/^([\d,]+)\s+following/i);
        if (fgMatch) {
          following = fgMatch[1];
        } else {
          following = normalizeText(followingEl.textContent).replace(/\s*following$/i, "").trim();
        }
      }

      var postCount = "";
      var pt = bodyInnerText(pageText);
      var postCountMatch = pt.match(/([\d,.]+[KMB]?)\s+posts?\b/i);
      if (postCountMatch) postCount = postCountMatch[1];

      var profileImage = metadata.image || "";
      if (!profileImage) {
        var avatarImg = document.querySelector('[data-testid="userAvatarImage"]');
        if (avatarImg) profileImage = avatarImg.src || "";
      }

      var posts = [];
      var postTextEls = document.querySelectorAll('[data-testid="postText"]');
      for (var pi = 0; pi < Math.min(postTextEls.length, 5); pi++) {
        var postEl = postTextEls[pi];
        var postText = normalizeText(postEl.textContent);
        if (!postText || postText.length < 5) continue;

        var feedItem = postEl.closest('[data-testid^="feedItem-by-"]');
        var engagement = [];
        if (feedItem) {
          var replyBtn = feedItem.querySelector('[data-testid="replyBtn"]');
          var repostCount = feedItem.querySelector('[data-testid="repostCount"]');
          var likeCount = feedItem.querySelector('[data-testid="likeCount"]');

          if (replyBtn) {
            var replyAria = replyBtn.getAttribute("aria-label") || "";
            var replyMatch = replyAria.match(/\((\d[\d,]*)\s+repl/i);
            if (replyMatch) engagement.push(replyMatch[1] + " replies");
          }
          if (repostCount) {
            var rpText = normalizeText(repostCount.textContent);
            if (rpText && rpText !== "0") engagement.push(rpText + " reposts");
          }
          if (likeCount) {
            var lkText = normalizeText(likeCount.textContent);
            if (lkText && lkText !== "0") engagement.push(lkText + " likes");
          }

          var feedTestId = feedItem.getAttribute("data-testid") || "";
          var feedAuthor = feedTestId.replace("feedItem-by-", "");
          var handleClean = handle.replace("@", "");
          var isRepost = feedAuthor && handleClean && feedAuthor !== handleClean;
        }

        var entry = "";
        if (isRepost) entry += "Repost @" + feedAuthor + ": ";
        entry += postText;
        if (engagement.length) entry += " [" + engagement.join(", ") + "]";
        posts.push(entry);
      }

      var details = [];
      if (handle) details.push("Handle: " + handle);
      if (followers) details.push("Followers: " + socialCompactCount(followers, true));
      if (following) details.push("Following: " + socialCompactCount(following, true));
      if (postCount) details.push("Posts: " + postCount);
      if (profileImage) details.push("Image: " + profileImage);

      var descParts = [];
      if (bio) descParts.push(bio);
      if (posts.length) descParts.push("## Recent Posts\n\n" + posts.join("\n\n"));
      if (!displayName && !bio && !posts.length) return null;

      var profileContent = articleContentFromParts({
        title: displayName || handle || "Bluesky Profile",
        description: descParts.join("\n\n"),
        details: details,
        siteName: "Bluesky",
        hostAware: true,
        contentType: "article"
      });
      profileContent.contentType = "social";
      profileContent.socialKind = "profile";
      profileContent.platform = "Bluesky";
      profileContent.handle = handle || null;
      return profileContent;
    }

    var focalPost = document.querySelector('[data-testid="postText"]');
    if (!focalPost) return null;

    var focalText = normalizeText(focalPost.textContent);
    if (!focalText) return null;
    var focalAuthor = "";
    var focalHandle = "";

    var postPathParts = (location.pathname || "").split("/").filter(Boolean);
    if (postPathParts[0] === "profile" && postPathParts[1]) {
      focalHandle = "@" + postPathParts[1];
    }

    var postNameEl = document.querySelector('[data-testid="profileHeaderDisplayName"]');
    if (postNameEl) focalAuthor = normalizeText(postNameEl.textContent);
    if (!focalAuthor) focalAuthor = (metadata.title || "").replace(/\s*[-–—|].*$/, "").trim();

    var focalFeedItem = focalPost.closest('[data-testid^="feedItem-by-"]') || document.querySelector('[data-testid^="feedItem-by-"]');
    var focalEngagement = [];
    var focalReplyCount = null;
    if (focalFeedItem) {
      var fReply = focalFeedItem.querySelector('[data-testid="replyBtn"]');
      var fRepost = focalFeedItem.querySelector('[data-testid="repostCount"]');
      var fLike = focalFeedItem.querySelector('[data-testid="likeCount"]');
      if (fReply) {
        var frAria = fReply.getAttribute("aria-label") || "";
        var frMatch = frAria.match(/\((\d[\d,]*)\s+repl/i);
        if (frMatch) {
          focalEngagement.push(frMatch[1] + " replies");
          focalReplyCount = parseInt(frMatch[1].replace(/,/g, ""), 10);
        }
      }
      if (fRepost) {
        var frpText = normalizeText(fRepost.textContent);
        if (frpText && frpText !== "0") focalEngagement.push(frpText + " reposts");
      }
      if (fLike) {
        var flkText = normalizeText(fLike.textContent);
        if (flkText && flkText !== "0") focalEngagement.push(flkText + " likes");
      }
    }

    var postDetails = [];
    if (focalHandle) postDetails.push("Author: " + (focalAuthor ? focalAuthor + " (" + focalHandle + ")" : focalHandle));
    if (focalEngagement.length) postDetails.push("Engagement: " + focalEngagement.join(", "));

    var allPostTexts = document.querySelectorAll('[data-testid="postText"]');
    var replies = [];
    for (var ri = 1; ri < Math.min(allPostTexts.length, 8); ri++) {
      var replyText = normalizeText(allPostTexts[ri].textContent);
      if (replyText && replyText.length > 3) {
        replies.push(replyText);
      }
    }

    var postDesc = focalText;
    if (replies.length) postDesc += "\n\n## Replies\n\n" + replies.join("\n\n");

    var postContent = articleContentFromParts({
      title: focalAuthor || "Post on Bluesky",
      description: postDesc,
      details: postDetails,
      siteName: "Bluesky",
      hostAware: true,
      contentType: "article"
    });
    postContent.contentType = "social";
    postContent.socialKind = replies.length ? "thread" : "post";
    postContent.platform = "Bluesky";
    postContent.handle = focalHandle || null;
    postContent.replyCount = focalReplyCount;
    return postContent;
  }

  function registerBlueskyProfiles() {
    registerHostAwareProfile(true, blueskyContent);
  }
