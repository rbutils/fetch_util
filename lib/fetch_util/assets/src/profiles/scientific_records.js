  function scientificRecordContent(metadata) {
    return oeisSequenceContent(metadata) ||
      rcsbStructureContent(metadata) ||
      nistReferenceDataContent(metadata);
  }

  function scientificRecordLabelValue(pageText, label, stopLabels) {
    var stops = (stopLabels || []).map(function(stop) {
      return stop.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s*:?";
    }).join("|");
    var pattern = new RegExp(label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ":\\s*([\\s\\S]*?)(?=" + (stops || "$^") + "|$)", "i");
    var match = pageText.match(pattern);
    return match ? normalizeText(match[1]).replace(/\s+Search on .*$/i, "") : "";
  }

  function rcsbStructureContent(metadata) {
    if (!/^\/structure\/[A-Za-z0-9]{4}$/i.test(location.pathname || "")) return null;

    var idText = normalizeText(((document.querySelector("#structureID") || {}).textContent) || "").replace(/&nbsp;/g, " ");
    var idMatch = idText.match(/\b[A-Za-z0-9]{4}\b/);
    var structureId = idMatch && idMatch[0].toUpperCase();
    var title = normalizeText(((document.querySelector("#structureTitle") || {}).textContent) || "");
    if (!structureId || !title) return null;

    var pageText = normalizeText(document.body && document.body.textContent || "");
    var headerStops = ["Classification", "Organism(s)", "Mutation(s)", "Deposited", "Released", "Deposition Author(s)", "Method", "Resolution"];
    var details = [
      "PDB ID: " + structureId,
      scientificRecordLabelValue(pageText, "Classification", headerStops),
      scientificRecordLabelValue(pageText, "Organism(s)", headerStops),
      scientificRecordLabelValue(pageText, "Method", ["Resolution", "R-Value Free", "R-Value Work", "Space Group"]),
      scientificRecordLabelValue(pageText, "Resolution", ["R-Value Free", "R-Value Work", "R-Value Observed", "Space Group"]),
      scientificRecordLabelValue(pageText, "Deposited", headerStops),
      scientificRecordLabelValue(pageText, "Released", headerStops)
    ].filter(Boolean);

    var citationTitle = "";
    var citationNode = document.querySelector("#primarycitation, [id*='citation' i], [class*='citation' i]");
    if (citationNode) citationTitle = normalizeText(citationNode.textContent || "").replace(/^Primary Citation\s*/i, "").replace(/\s*PubMed(?: Abstract)?:[\s\S]*$/i, "");
    if (!citationTitle) {
      var citationMatch = pageText.match(/Structure of [\s\S]{20,260}?(?=PubMed Abstract:|PDB DOI:|Experimental Data|$)/i);
      citationTitle = citationMatch ? normalizeText(citationMatch[0]) : "";
    }

    var abstractText = scientificRecordLabelValue(pageText, "PubMed Abstract", ["PDB DOI", "Experimental Data", "Deposition Data", "Ligands", "Clicking the button"]).replace(/\s+View More[\s\S]*$/i, "").replace(/\s+\/\/ Used for[\s\S]*$/i, "");
    var highlights = [];
    if (citationTitle) highlights.push("Primary citation: " + citationTitle);
    if (abstractText) highlights.push("PubMed abstract: " + abstractText);

    var result = articleContentFromParts({
      title: structureId + " - " + title,
      details: details,
      highlights: highlights,
      siteName: metadata.siteName || "RCSB PDB",
      contentType: "article",
      hostAware: true
    });
    if (normalizeText(result.markdown).length < 180 || !/\bPDB ID:\s*[A-Z0-9]{4}\b/.test(result.markdown)) return null;
    return result;
  }

  function nistReferenceDataContent(metadata) {
    if (!/\.nist\.gov$/i.test(location.hostname || "") && !/^nist\.gov$/i.test(location.hostname || "")) return null;

    var main = document.querySelector("main#main, #main");
    var title = normalizeText(((main && main.querySelector("h1#Top, h1")) || {}).textContent || "");
    if (!main || !title) return null;

    var mainText = normalizeText(main.textContent || "");
    var hasCompoundData = /\bFormula:\s*\S/i.test(mainText) && /\bMolecular weight:\s*[0-9.]+/i.test(mainText) && /\bCAS Registry Number:\s*\S/i.test(mainText);
    if (!hasCompoundData) return null;

    var root = cleanClone(main);
    root.querySelectorAll(".copy-prior-text, svg, img, form, .sr-only").forEach(function(el) {
      el.remove();
    });
    root.querySelectorAll("li").forEach(function(item) {
      var text = normalizeText(item.textContent || "");
      if (/^Chemical structure:/i.test(text) || /^Permanent link/i.test(text)) item.remove();
    });

    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    var text = normalizeText(markdown);
    if (text.length < 220 || !/\bFormula\b[\s\S]*\bMolecular weight\b[\s\S]*\bCAS Registry Number\b/i.test(markdown)) return null;

    return {
      title: title,
      byline: metadata.byline,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "NIST",
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
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
