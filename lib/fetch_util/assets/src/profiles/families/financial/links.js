  function financialStatementLinkCandidates() {
    var candidates = [];
    var seen = [];
    var financialContext = /\b(?:financial statements?|condensed consolidated|consolidated statements?|balance sheets?|income statements?|cash flows?|earnings(?: release)?|results|quarterly report|annual report|form\s*(?:10-k|10-q|8-k)|sec filing|pdf)\b/i;

    function push(url, label, context) {
      var text = normalizeText([label, context].join(" "));
      if (!url || seen.indexOf(url) !== -1 || !financialContext.test(text + " " + url)) return;
      seen.push(url);
      candidates.push({ url: url, label: normalizeText(label) || url });
    }

    document.querySelectorAll("a[href]").forEach(function(link) {
      var href = link.getAttribute("href") || "";
      var url;
      try { url = new URL(href, location.href); } catch (_error) { return; }
      var path = url.pathname || "";
      var label = normalizeText(link.textContent || link.getAttribute("aria-label") || link.getAttribute("title") || "");
      var contextNode = link.closest("p, li, figure, figcaption, section, article, div") || link;
      var context = normalizeText(contextNode.textContent || "").slice(0, 500);
      if (/\.(?:pdf|xlsx?|csv)(?:$|[?#])/i.test(path) || /\b(?:pdf|xls|xlsx|csv|download)\b/i.test(label + " " + context)) {
        push(url.href, label, context);
      }
    });

    document.querySelectorAll("figure img[src], picture img[src], img[src]").forEach(function(image) {
      var contextNode = image.closest("figure, picture, section, article, div") || image;
      var label = normalizeText(image.getAttribute("alt") || image.getAttribute("aria-label") || "Financial statement image");
      var context = normalizeText(contextNode.textContent || label).slice(0, 500);
      if (!financialContext.test(label + " " + context)) return;

      try { push(new URL(image.getAttribute("src"), location.href).href, label, context); } catch (_error) {}
    });

    return candidates.slice(0, 12);
  }

  function financialStatementLinksMarkdown(existingMarkdown) {
    var links = financialStatementLinkCandidates();
    if (!links.length) return existingMarkdown;

    var markdown = existingMarkdown || "";
    if (/^## Financial Statement Links$/m.test(markdown)) return existingMarkdown;

    var lines = links.map(function(link) {
      return "- [" + (link.label || "Financial statement") + "](" + link.url + ")";
    });

    return markdown.replace(/\s+$/g, "") + "\n\n## Financial Statement Links\n\n" + lines.join("\n");
  }
