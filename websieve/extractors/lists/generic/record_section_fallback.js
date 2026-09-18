  function sectionHeadingLinks(region, heading) {
    var links = heading ? Array.from(heading.querySelectorAll("a[href]")) : [];
    var ancestor = heading && heading.closest("a[href]");
    if (ancestor && region.contains(ancestor)) links.unshift(ancestor);
    return links.filter(function(link, index, all) {
      return all.indexOf(link) === index && !elementSubtreeHidden(link) && !elementVisuallyHidden(link);
    });
  }

  function sectionRecordDestination(link) {
    var raw = String(link && link.getAttribute("href") || "").trim();
    var url = materializedHttpUrl(raw);
    if (url) return { kind: "safe", url: url };
    if (/^(?:javascript|vbscript):/i.test(raw)) return { kind: "inert", url: "" };
    return null;
  }

  function simpleRecordCollection(records, parent) {
    if (records.some(function(record) {
      return record.querySelector("article") || record.querySelectorAll("h1, h2, h3, h4").length !== 1;
    })) return false;
    if (Array.prototype.some.call(parent.childNodes, function(node) {
      return node.nodeType === 3 && normalizeText(node.textContent);
    })) return false;

    var pageHeadings = Array.prototype.filter.call(parent.children, function(node) {
      return !elementSubtreeHidden(node) && !elementVisuallyHidden(node) && records.indexOf(node) < 0;
    });
    return pageHeadings.length === 1 && pageHeadings[0].matches("h1");
  }

  function sectionRecordCollectionFallback(region, options) {
    var cache = options && options.recordSectionFallbacks;
    if (!(region && region.matches && region.matches("article") && region.parentElement)) return false;
    var parent = region.parentElement;
    if (cache && cache.has(parent)) return cache.get(parent);
    function result(value) {
      if (cache) cache.set(parent, value);
      return value;
    }
    if (!likelyListPath()) return result(false);

    var heading = sectionHeadingNode(region, options);
    if (!heading || closestGenericListFieldCard(heading) !== region) return result(false);

    var records = Array.prototype.filter.call(parent.children, function(candidate) {
      return candidate.matches && candidate.matches("article") &&
        !elementSubtreeHidden(candidate) && !elementVisuallyHidden(candidate);
    });
    var destinations = records.map(function(record) {
      var recordHeading = sectionHeadingNode(record, options);
      var links = sectionHeadingLinks(record, recordHeading);
      if (!recordHeading || closestGenericListFieldCard(recordHeading) !== record || links.length !== 1) return null;
      return sectionRecordDestination(links[0]);
    });
    var fallback = records.length >= 3 && simpleRecordCollection(records, region.parentElement) &&
      destinations.every(Boolean) &&
      destinations.filter(function(destination) { return destination.kind === "safe"; }).length >= 2 &&
      destinations.some(function(destination) { return destination.kind === "inert"; });
    return result(fallback);
  }
