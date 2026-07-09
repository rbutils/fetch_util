  function applyProductPageContent(content, metadata) {
    if (!content || content.contentType === "property" || content.contentType === "list" || content.contentType === "search" || content.contentType === "interstitial" || content.docsLike || content.legalProvision) return content;

    var evidence = productPageEvidence();
    if (!evidence) return content;

    content.contentType = "product";
    if (evidence.title && (!content.title || normalizeText(content.title).length < evidence.title.length)) content.title = evidence.title;
    if (evidence.excerpt && !content.excerpt) content.excerpt = evidence.excerpt;
    if (evidence.price) content.price = evidence.price;
    if (evidence.availability) content.availability = humanizeCommerceAvailability(evidence.availability);
    if (evidence.sku) content.sku = evidence.sku;

    var details = [];
    if (content.price) details.push("Price: " + content.price);
    if (content.availability) details.push("Availability: " + content.availability);
    if (content.sku) details.push("SKU: " + content.sku);
    if (details.length && normalizeText(content.markdown || content.textContent || "").indexOf(details[0]) === -1) {
      var title = content.title || (metadata && metadata.title) || document.title;
      var body = normalizeText(content.markdown || content.textContent || "");
      content.markdown = ["# " + title, details.map(function(detail) { return "- " + detail; }).join("\n"), body].filter(Boolean).join("\n\n");
      content.textContent = normalizeText(content.markdown);
    }

    return content;
  }
