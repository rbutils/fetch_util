  function ncbiGeneContent(metadata) {
    var ncbiDb = normalizeText(((document.querySelector("meta[name='ncbi_db']") || {}).content) || "").toLowerCase();
    if (ncbiDb && ncbiDb !== "gene") return null;
    if (!/^\/gene\/\d+\/?$/i.test(location.pathname || "")) return null;

    var report = document.querySelector(".rprt.full-rprt");
    var titleNode = report && report.querySelector("#gene-name");
    var summary = report && report.querySelector("#summaryDl");
    var sections = report ? Array.prototype.slice.call(report.querySelectorAll(".rprt-section[data-section]")) : [];
    if (!report || !titleNode || !summary || sections.length < 2) return null;

    var title = normalizeText(titleNode.textContent || "");
    if (!title || !/\bGene ID:\s*\d+/i.test(normalizeText(report.textContent || ""))) return null;

    return profileHtmlContent(metadata, report, {
      title: title,
      excerpt: metadata.excerpt,
      defaultExcerpt: false,
      siteName: metadata.siteName || "NCBI Gene",
      cleanupRoot: false,
      minTextLength: 500,
      rewriteRoot: function(root) {
        root.querySelectorAll("script, style, svg, iframe, noscript, input, button, select, .rprt-section-tools, .download-datasets, .gene-section-help, .gene-top-page, .ui-ncbipopper-wrapper, [aria-hidden='true']").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("[style*='display:none'], [style*='display: none']").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("table").forEach(function(table) {
          if (!normalizeText((table.querySelector("tbody") || table).textContent || "")) table.remove();
        });
      },
      validateMarkdown: function(markdown) {
        return /\bOfficial\s+Symbol\b[\s\S]*\bGene type\b[\s\S]*\bOrganism\b/i.test(markdown) &&
          /\b(Summary|Genomic context|Expression|Interactions|General gene information)\b/i.test(markdown);
      }
    });
  }
