  function searchItemTitle(link) {
    var heading = link.querySelector("h1, h2, h3, h4");
    return normalizeText(heading ? heading.textContent : link.textContent);
  }
  function searchItemDetail(node, title) {
    var clone = node && node.cloneNode ? node.cloneNode(true) : node;
    pruneGenericListControls(clone);
    var detail = normalizeText(clone && clone.textContent).replace(normalizeText(title), "").replace(/\s*[|·]\s*/g, " - ");
    detail = detail
      .replace(/Only include results for this site.*$/i, "")
      .replace(/This search result is provided by Google Learn more Report result/gi, "")
      .replace(/Learn more Report result/gi, "")
      .replace(/Report Ad/gi, "")
      .replace(/\bhttps?:\/\/\S+/gi, "")
      .replace(/\s{2,}/g, " ");
    return normalizeText(detail);
  }
