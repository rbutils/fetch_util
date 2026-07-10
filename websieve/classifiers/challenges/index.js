function domSignals() {
  var iframeData = Array.prototype.map.call(document.querySelectorAll("iframe"), function(frame) {
    return {
      title: normalizeText(frame.getAttribute("title") || ""),
      src: normalizeText(frame.getAttribute("src") || "")
    };
  });

  return {
    iframeTitles: iframeData.map(function(frame) { return frame.title; }).filter(Boolean),
    iframeSources: iframeData.map(function(frame) { return frame.src; }).filter(Boolean),
    scriptSources: Array.prototype.map.call(document.querySelectorAll("script[src]"), function(script) {
      return normalizeText(script.getAttribute("src") || "");
    }).filter(Boolean),
    textLength: pageReadableText().length,
    htmlLength: (document.body && document.body.innerHTML || "").length,
    bodyHtml: (document.body && document.body.innerHTML || "").slice(0, 8000)
  };
}
