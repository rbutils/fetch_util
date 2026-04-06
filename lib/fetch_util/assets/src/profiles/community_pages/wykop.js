  function wykopContent(metadata) {
    var signature = normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
    if (!hostMatches(/(^|\.)wykop\.pl$/) && !/wykop/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/") return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("section.prerender section.link-block.stream-home[id^='link-'], section.home-page section.link-block.stream-home[id^='link-'], section.stream.home-stream.from-pagination-home-stream section.link-block.stream-home[id^='link-']").forEach(function(card) {
      if (items.length >= 12) return;

      var link = card.querySelector("h2.heading a[href^='/link/'], h2 a[href^='/link/'], a[href^='/link/']");
      if (!link) return;

      var title = normalizeText(link.textContent || link.getAttribute("title") || "");
      var url = absoluteUrl(link.getAttribute("href"));
      if (!title || !url || title.length < 12 || title.length > 220 || seen[url]) return;
      if (/^(załóż konto|zaloguj się|ustawienia prywatności)$/i.test(title)) return;

      seen[url] = true;

      var detailParts = [];
      var summary = normalizeText(Array.prototype.map.call(card.querySelectorAll("p, .description, .text, .content"), function(node) {
        return normalizeText(node.textContent || "");
      }).join(" "));
      if (summary && summary !== title && !/we value your privacy|manage choices|privacy settings|ustawienia prywatności|polityka prywatności i cookies|nie widzisz nawet do 30% treści dostępnych w serwisie/i.test(summary)) detailParts.push(summary);

      var counters = normalizeText(Array.prototype.map.call(card.querySelectorAll("a.comment-counter, [class*='vote'], [class*='comment']"), function(node) {
        return normalizeText(node.textContent || "");
      }).join(" ")).replace(/\s{2,}/g, " ");
      if (counters) detailParts.push(counters);

      items.push({ text: title, url: url, detail: normalizeText(detailParts.join(" - ")) });
    });

    if (items.length < 4) return null;

    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "Wykop",
      publishedTime: null,
      html: "",
      textContent: listMarkdown(items),
      markdown: listMarkdown(items),
      readerMode: false,
      contentType: "list"
    };
  }
