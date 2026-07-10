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
