  function scientificRecordContent(metadata) {
    return oeisSequenceContent(metadata);
  }

  function oeisSequenceContent(metadata) {
    if (!/^\/A\d{6}$/i.test(location.pathname || "")) return null;

    var header = document.querySelector(".seqhead .seqnumname");
    var terms = document.querySelector(".seqdatabox .seqdata");
    var sections = Array.prototype.slice.call(document.querySelectorAll(".entry .section"));
    if (!header || !terms || sections.length < 3) return null;

    var sequenceId = normalizeText((header.querySelector(".seqnum") || {}).textContent || "");
    var sequenceName = normalizeText((header.querySelector(".seqname") || {}).textContent || "").replace(/\s*\(Formerly\s+[^)]*\)\s*$/i, "");
    if (!/^A\d{6}$/i.test(sequenceId) || !sequenceName) return null;

    var wanted = {
      OFFSET: true,
      COMMENTS: true,
      REFERENCES: true,
      FORMULA: true,
      EXAMPLE: true
    };
    var ordered = ["OFFSET", "COMMENTS", "FORMULA", "EXAMPLE", "REFERENCES"];
    var labels = {
      OFFSET: "Offset",
      COMMENTS: "Sequence comments",
      FORMULA: "Formula",
      EXAMPLE: "Example",
      REFERENCES: "References"
    };
    var byName = {};

    sections.forEach(function(section) {
      var name = normalizeText(((section.querySelector(".sectname") || {}).textContent) || "").toUpperCase();
      if (!wanted[name] || byName[name]) return;
      var body = section.querySelector(".sectbody");
      if (!body || normalizeText(body.textContent || "").length < 2) return;
      byName[name] = body;
    });

    if (!byName.COMMENTS && !byName.FORMULA && !byName.EXAMPLE) return null;

    var root = document.createElement("article");
    var heading = document.createElement("h1");
    heading.textContent = sequenceId + " - " + sequenceName;
    root.appendChild(heading);

    var termsHeading = document.createElement("h2");
    termsHeading.textContent = "Terms";
    root.appendChild(termsHeading);
    var termsParagraph = document.createElement("p");
    termsParagraph.textContent = normalizeText(terms.textContent || "");
    root.appendChild(termsParagraph);

    ordered.forEach(function(name) {
      var body = byName[name];
      if (!body) return;

      var section = document.createElement("section");
      var sectionHeading = document.createElement("h2");
      sectionHeading.textContent = labels[name];
      section.appendChild(sectionHeading);

      Array.prototype.slice.call(body.querySelectorAll(".sectline")).forEach(function(line) {
        var text = normalizeText(line.textContent || "");
        if (!text) return;
        var paragraph = document.createElement("p");
        paragraph.innerHTML = cleanClone(line).innerHTML;
        section.appendChild(paragraph);
      });

      if (normalizeText(section.textContent || "").length > sectionHeading.textContent.length) root.appendChild(section);
    });

    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    var text = normalizeText(markdown);
    if (text.length < 300 || !/\bFormula\b[\s\S]*\bExample\b/i.test(markdown)) return null;

    return {
      title: sequenceId + " - " + sequenceName,
      byline: metadata.byline,
      excerpt: sequenceName,
      siteName: metadata.siteName || "OEIS",
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }
