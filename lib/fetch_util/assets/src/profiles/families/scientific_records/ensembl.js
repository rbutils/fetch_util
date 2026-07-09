  function ensemblGeneContent(metadata) {
    if (!/^\/[A-Za-z_]+\/Gene\/Summary\/?$/i.test(location.pathname || "")) return null;

    var main = document.querySelector("#main");
    var heading = main && main.querySelector("h1.summary-heading");
    var summaryPanel = main && main.querySelector(".summary_panel");
    var geneSummary = main && main.querySelector("#GeneSummary");
    var transcriptTable = main && main.querySelector("#transcripts_table");
    var title = normalizeText((heading && heading.textContent) || "");
    if (!main || !heading || !summaryPanel || !geneSummary || !/^Gene:\s+\S+\s+ENS[A-Z]*G\d+/i.test(title)) return null;

    return profileHtmlContent(metadata, main, {
      title: title,
      excerpt: metadata.excerpt,
      defaultExcerpt: false,
      siteName: metadata.siteName || "Ensembl",
      cleanupRoot: false,
      minTextLength: 500,
      rewriteRoot: function(root) {
        root.querySelectorAll("script, style, svg, iframe, noscript, input, button, select, .navbar, .image_panel, .image_toolbar, .json_, .label_layer, .hover_label, .boundaries_wrapper, .drag_select, .session_messages, .dataTables_top, .data_table_config, .floating_popup, .tool_buttons, .invisible, .hidden, ._ht_tip, .button.toggle").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll("img").forEach(function(img) {
          if (!normalizeText(img.alt || img.title || "")) img.remove();
        });
      },
      validateMarkdown: function(markdown) {
        return /\bDescription\b[\s\S]*\bLocation\b[\s\S]*\bAbout this gene\b/i.test(markdown) &&
          /\b(Transcripts|MANE|UniProtKB|RefSeq|CCDS)\b/i.test(markdown);
      }
    });
  }
