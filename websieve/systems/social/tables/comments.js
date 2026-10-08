  function tableSocialCommentBody(row, metadata) {
    var candidates = Array.from(row.querySelectorAll("p, blockquote, pre, ul, ol, table, div, span, [itemprop='text'], img[src], video[src], audio[src], iframe[src]")).filter(function(node) {
      if (node.closest("tr") !== row || elementSubtreeHidden(node)) return false;
      if (!normalizeText(node.textContent) && !node.matches("img[src], video[src], audio[src], iframe[src]") && !node.querySelector("img[src], video[src], audio[src], iframe[src]")) return false;
      if (node.closest("form, button, nav, footer, aside, [role='toolbar']")) return false;
      if (metadata.authorNode && node.contains(metadata.authorNode)) return false;
      if (metadata.timeNode && (node.contains(metadata.timeNode) || !(metadata.timeNode.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING))) return false;
      if (/^(?:reply|parent|next|previous|flag|hide|save|report)$/i.test(normalizeText(node.textContent)) &&
          node.querySelector("a[href], button") && !/^(?:P|PRE|BLOCKQUOTE)$/.test(node.tagName) && !node.matches("[itemprop='text']")) return false;
      return true;
    });
    return candidates.filter(function(node) {
      return !candidates.some(function(other) { return other !== node && other.contains(node); });
    });
  }

  function tableSocialComment(row) {
    var indent = tableSocialIndent(row);
    if (!indent) return null;
    var metadata = tableSocialMetadata(row);
    var body = tableSocialCommentBody(row, metadata);
    var text = normalizeText(body.map(function(node) { return node.textContent; }).join(" "));
    var deleted = /^\[(?:deleted|dead)\]$/i.test(text);
    var html = body.map(function(node) {
      var clone = visibilityPrunedClone(node, document);
      [clone].concat(Array.from(clone.querySelectorAll("span, div"))).forEach(function(material) {
        if (!material.matches("a, button") && !material.querySelector("a, button, input, select, textarea")) {
          material.setAttribute("data-fetchutil-social-comment", "true");
        }
      });
      return clone.outerHTML;
    }).join("\n");
    var markdown = deleted ? text : markdownFor(html).trim();
    if (!markdown) return null;
    return { row: row, author: metadata.author, time: metadata.time, indent: indent,
      deleted: deleted, text: text, markdown: markdown,
      html: visibilityPrunedClone(row, document).outerHTML };
  }

  function tableSocialComments(tables) {
    var comments = [];
    tables.forEach(function(table) {
      var entries = tableSocialRows(table).map(tableSocialComment).filter(Boolean);
      if (!entries.some(function(entry) { return entry.author && entry.time; })) return;
      var levels = Array.from(new Set(entries.map(function(entry) { return entry.indent.value; }))).sort(function(a, b) { return a - b; });
      entries.forEach(function(entry) {
        entry.depth = entry.indent.explicit ? entry.indent.value - levels[0] : levels.indexOf(entry.indent.value);
        comments.push(entry);
      });
    });
    return comments;
  }

  function tableSocialCommentMarkdown(comments) {
    return comments.map(function(comment) {
      var heading = comment.deleted ? "Deleted comment" : comment.author || "Comment";
      if (comment.time) heading += " (" + comment.time + ")";
      return "#".repeat(Math.min(6, 3 + comment.depth)) + " " + heading + "\n\n" + comment.markdown;
    }).join("\n\n");
  }
