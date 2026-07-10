  function institutionalTopicCardListContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll("[id*='listView' i], [role='list'], [class*='topic' i][class*='list' i], [class*='card' i][class*='grid' i]"));
    var best = null;

    roots.forEach(function(root) {
      var seen = {};
      var items = [];
      var topicishRoot = /topic|taxonomy|listview/i.test((root.id || "") + " " + (root.className || "") + " " + root.getAttribute("data-sf-element"));

      root.querySelectorAll("a[href]").forEach(function(link) {
        var href = link.getAttribute("href") || "";
        var url = absoluteUrl(href);
        var title = normalizeText(link.getAttribute("aria-label") || ((link.querySelector("h2, h3, h4") || {}).textContent) || "");
        var paragraphs = Array.prototype.slice.call(link.querySelectorAll("p"));
        var detail = "";

        if (!title && paragraphs.length) title = normalizeText(paragraphs[paragraphs.length - 1].textContent || link.textContent || "");
        if (paragraphs.length > 1) detail = normalizeText(paragraphs[0].textContent || "");
        if (!detail && title) detail = searchItemDetail(link, title);

        if (!title || !url || title.length < 3 || title.length > 180 || seen[url]) return;
        if (!topicishRoot && !/\btopics?\b/i.test(url + " " + title + " " + detail)) return;
        if (/^(home|health topics|topics|news|headlines|menu|search|more)$/i.test(title)) return;

        seen[url] = true;
        items.push({ text: title, url: url, detail: detail });
      });

      if (items.length < 8) return;
      var score = items.length * 100 + (topicishRoot ? 1000 : 0);
      if (!best || score > best.score) best = { root: root, items: items, score: score };
    });

    if (!best) return null;
    var title = normalizeText(((document.querySelector("h1") || {}).textContent) || metadata.title || document.title || "Topics");

    return listItemsContentResult(metadata, {
      title: title,
      excerpt: metadata.excerpt,
      items: best.items,
      html: cleanClone(best.root).innerHTML,
      textContent: title + "\n" + listMarkdown(best.items)
    });
  }
