  function listCandidateLosesArticleTableMaterial(content, candidate) {
    if (!content || content.contentType !== "article" || !candidate || candidate.contentType !== "list") return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    if (!root.querySelector("table tr")) return false;

    var candidateMarkdown = candidate.listArbitrationMarkdown == null ?
      candidate.markdown || candidate.textContent || "" : candidate.listArbitrationMarkdown;
    var candidateText = normalizeText(candidateMarkdown
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/\[([^\]]*)\]\([^)]+\)/g, "$1")
      .replace(/[`*_~#>|]/g, " "));
    var cells = [];

    Array.prototype.forEach.call(root.querySelectorAll("table tr"), function(row) {
      Array.prototype.map.call(row.querySelectorAll("th, td"), function(cell) {
        return normalizeText(cell.textContent || "");
      }).filter(function(text) { return text.length > 0; }).forEach(function(text) { cells.push(text.toLowerCase()); });
    });

    var cursor = 0;
    return cells.some(function(text) {
      var index = candidateText.toLowerCase().indexOf(text, cursor);
      if (index === -1) return true;
      cursor = index + text.length;
      return false;
    });
  }
