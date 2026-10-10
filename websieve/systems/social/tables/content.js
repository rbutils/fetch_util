  function tableSocialLabels(metadata, records, comments) {
    var title = normalizeText((metadata && metadata.title) || document.title);
    var split = title.match(/^(.*?)\s*[|•·]\s*([^|•·]+)$/);
    if (split) return { platform: normalizeText(split[2]), page: normalizeText(split[1]) };
    var rows = records.map(function(record) { return record.row; }).concat(comments.map(function(comment) { return comment.row; }));
    var masthead = Array.from(document.querySelectorAll("header, nav, [role='banner'], b, strong")).some(function(node) {
      return normalizeText(node.textContent) === title && !elementSubtreeHidden(node) && !rows.some(function(row) { return row.contains(node); });
    });
    return { platform: masthead ? title : socialPlatformLabel(metadata), page: title };
  }

  function tableSocialThreadBody(story, comments) {
    var table = story.row.closest("table");
    var parts = [];
    for (var row = story.detail.nextElementSibling; row; row = row.nextElementSibling) {
      if (elementSubtreeHidden(row) || row.querySelector("form") || comments.some(function(comment) { return row.contains(comment.row); })) continue;
      Array.from(row.cells || []).forEach(function(cell) {
        if (!normalizeText(cell.textContent) && !cell.querySelector("img, video, audio, pre, table")) return;
        var part = document.createElement("div");
        part.innerHTML = visibilityPrunedClone(cell, document).innerHTML;
        parts.push(part);
      });
    }
    for (var node = table.nextElementSibling; node && node.tagName !== "TABLE"; node = node.nextElementSibling) {
      if (elementSubtreeHidden(node) || node.matches("nav, footer, aside, form, dialog, script, style, [role='dialog']")) continue;
      if (normalizeText(node.textContent) || node.querySelector("img, video, audio, pre, table")) parts.push(visibilityPrunedClone(node, document));
    }
    return parts.map(function(node) { return node.outerHTML; }).join("\n");
  }

  function tableSocialContent(metadata) {
    var tables = tableSocialTables();
    if (!tables.length) return null;
    var records = tableSocialRecords(tables);
    var comments = tableSocialComments(tables);
    if (!records.length && !comments.length) return null;
    if (records.length && records.length < 3 && records.every(function(record) { return record.detail === record.row; })) return null;
    if (records.length > 1 && comments.length) return null;
    var labels = tableSocialLabels(metadata, records, comments);
    var story = records.length === 1 ? records[0] : null;
    var focal = comments[0];
    var feed = records.length > 1;
    var author = story ? story.author : !feed && focal ? focal.author : null;
    var title = story ? story.title : feed ? labels.page : "Comment by " + (author || "deleted user");
    var body = story ? tableSocialThreadBody(story, comments) : "";
    var nested = comments.filter(function(comment) { return comment.depth > 0; }).length;
    var replies = story && story.replyCount !== null ? story.replyCount : nested || null;
    var sections = ["# " + title];
    if (feed) {
      sections.push(records.map(function(record) {
        var details = [];
        if (record.score !== null) details.push(record.score + " points");
        if (record.author) details.push("by " + record.author);
        if (record.time) details.push(record.time);
        if (record.replyCount !== null) details.push(record.replyCount + " replies");
        return "- " + markdownLink(record.title, record.url) + (details.length ? " - " + details.join(" - ") : "");
      }).join("\n"));
    } else {
      if (story) {
        var details = ["- Story: " + markdownLink(story.title, story.url)];
        if (author) details.push("- Author: " + author);
        if (story.time) details.push("- Published: " + story.time);
        if (story.score !== null) details.push("- Score: " + story.score);
        if (story.replyCount !== null) details.push("- Replies: " + story.replyCount);
        sections.push(details.join("\n"));
      }
      if (body) sections.push(markdownFor(body).trim());
      if (comments.length) sections.push("## Comments\n\n" + tableSocialCommentMarkdown(comments));
    }
    var markdown = sections.join("\n\n");
    var holder = document.createElement("div");
    holder.innerHTML = body;
    var recordHtml = records.map(function(record) { return record.html; }).join("\n");
    if (feed) recordHtml = "<table><tbody>" + recordHtml + "</tbody></table>";
    return {
      title: title, byline: author, publishedTime: null, siteName: labels.platform, canonicalUrl: metadata.canonicalUrl,
      excerpt: feed ? records[0].title : normalizeText(holder.textContent) || (focal && focal.text) || metadata.excerpt || title,
      html: recordHtml + body + comments.map(function(comment) { return comment.html; }).join("\n"),
      markdown: markdown, textContent: normalizeText(markdown), readerMode: false,
      contentType: "social", socialKind: feed ? "feed" : replies ? "thread" : "post",
      platform: labels.platform, handle: author, replyCount: replies,
      community: feed ? labels.page || null : null, score: story ? story.score : null
    };
  }
