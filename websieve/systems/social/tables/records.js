  function tableSocialPlainCommentHeader(row) {
    var headers = Array.from(row.querySelectorAll("span, header")).map(function(node) {
      if (node.children.length || node.closest("tr") !== row || elementSubtreeHidden(node)) return null;
      var text = normalizeText(node.textContent);
      var match = text.match(/^(.+?)\s+(on\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2},\s+\d{4})\s*\|\s*(.+)$/i);
      if (!match) return null;
      var actions = match[3].replace(/\[[-–−+]\]/g, "").split("|").map(normalizeText);
      if (!actions.every(function(action) { return /^(?:parent|next|previous|root|reply)$/i.test(action); })) return null;
      return { node: node, author: normalizeText(match[1]), time: normalizeText(match[2]) };
    }).filter(Boolean);
    return headers.length === 1 ? headers[0] : null;
  }

  function tableSocialMetadata(row) {
    var text = normalizeText(row.innerText || row.textContent || "");
    var timeNode = Array.from(row.querySelectorAll("time[datetime], [itemprop='datePublished'], [class~='time' i], [class~='age' i]")).find(function(node) {
      return !elementSubtreeHidden(node) && node.closest("tr") === row;
    });
    var plainHeader = timeNode ? null : tableSocialPlainCommentHeader(row);
    var relative = text.match(/\b\d+\s+(?:seconds?|minutes?|hours?|days?|weeks?|months?|years?)\s+ago\b|\b(?:yesterday|today)\b/i);
    var time = normalizeText(timeNode ? timeNode.textContent || timeNode.getAttribute("datetime") : relative && relative[0]);
    if (plainHeader) {
      timeNode = plainHeader.node;
      time = plainHeader.time;
    }
    var position = time ? text.indexOf(time) : -1;
    var prefix = position >= 0 ? text.slice(0, position) : "";
    var body = Array.from(row.querySelectorAll("p, blockquote, pre, [itemprop='text']")).find(function(node) { return node.closest("tr") === row; });
    function precedesBody(node) {
      return !time && body && !node.contains(body) && !!(node.compareDocumentPosition(body) & Node.DOCUMENT_POSITION_FOLLOWING);
    }
    var authorNode = Array.from(row.querySelectorAll("[rel~='author' i], [itemprop='author'], [data-author], [class*='author' i]")).find(function(node) {
      var value = normalizeText(node.getAttribute("data-author") || node.textContent);
      return value && (prefix.indexOf(value) !== -1 || precedesBody(node)) && !elementSubtreeHidden(node);
    });
    var author = authorNode && normalizeText(authorNode.getAttribute("data-author") || authorNode.textContent);
    if (!author) {
      var links = Array.from(row.querySelectorAll("a")).filter(function(link) {
        var value = normalizeText(link.textContent);
        return value && (prefix.indexOf(value) !== -1 || precedesBody(link)) && !elementSubtreeHidden(link) &&
          !/^(?:\d+\s+)?(?:points?|votes?|comments?|replies|hide|flag|save|report)$/i.test(value);
      });
      if (links.length === 1) {
        authorNode = links[0];
        author = normalizeText(authorNode.textContent);
      }
    }
    var named = prefix.match(/\bby\s+([^|,;]+?)\s*$/i);
    if (!author && named) author = normalizeText(named[1]);
    if (!author && plainHeader) {
      author = plainHeader.author;
      authorNode = plainHeader.node;
    }
    var score = text.match(/\b(\d+)\s+(?:points?|votes?)\b/i);
    var replies = text.match(/\b(\d+)\s+(?:comments?|repl(?:y|ies))\b/i);
    var action = Array.from(row.querySelectorAll("a")).some(function(link) {
      return !elementSubtreeHidden(link) && /^(?:hide|flag|save|report)$/i.test(normalizeText(link.textContent));
    });
    return { author: author || null, authorNode: authorNode || null, time: time || null, timeNode: timeNode || null,
      score: score ? Number(score[1]) : null, replies: replies ? Number(replies[1]) : null, action: action,
      plainCommentHeader: !!plainHeader };
  }

  function tableSocialTitleLink(row) {
    var links = Array.from(row.querySelectorAll("a[href]")).filter(function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label"));
      return text && materializedHttpUrl(link.getAttribute("href")) && !elementSubtreeHidden(link) &&
        !/^(?:[▲▼↑↓]|upvote|downvote|vote)$/i.test(text);
    });
    if (!links.length) return null;
    var primary = links[0];
    var host = new URL(materializedHttpUrl(primary.getAttribute("href"))).hostname.replace(/^www\./, "");
    if (links.slice(1).some(function(link) {
      return normalizeText(link.textContent).replace(/^\(|\)$/g, "").replace(/^www\./, "") !== host;
    })) return null;
    return primary;
  }

  function tableSocialStory(row) {
    if (row.querySelector("table") || tableSocialIndent(row)) return null;
    var link = tableSocialTitleLink(row);
    var detail = row.nextElementSibling;
    if (!link || !detail || detail.tagName !== "TR" || detail.closest("table") !== row.closest("table") || elementSubtreeHidden(detail)) return null;
    var metadata = tableSocialMetadata(detail);
    if (!metadata.time || (!metadata.author && metadata.score === null && metadata.replies === null && !metadata.action)) return null;
    var title = normalizeText(link.textContent || link.getAttribute("aria-label"));
    var dead = /\[(?:dead|deleted)\]/i.test(normalizeText(row.textContent + " " + detail.textContent));
    return { title: dead ? "[dead] " + title : title, url: materializedHttpUrl(link.getAttribute("href")),
      author: metadata.author, time: metadata.time, score: metadata.score, replyCount: metadata.replies,
      row: row, detail: detail, html: visibilityPrunedClone(row, document).outerHTML + visibilityPrunedClone(detail, document).outerHTML };
  }

  function tableSocialRecords(tables) {
    var records = [];
    tables.forEach(function(table) {
      tableSocialRows(table).forEach(function(row) {
        var record = tableSocialStory(row);
        if (record) records.push(record);
      });
    });
    return records;
  }
