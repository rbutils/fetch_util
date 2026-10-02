  function markReadabilityExcerptSources(root) {
    var values = new Uint32Array(4);
    crypto.getRandomValues(values);
    var marker = Array.from(values).map(function(value) {
      return value.toString(16).padStart(8, "0");
    }).join("");
    var structuredOwner = readabilityStructuredExcerptOwner(root);
    var owned = Array.prototype.filter.call(root.querySelectorAll("p, li"), function(node) {
      return readabilityExcerptOwner(node, structuredOwner) && readabilityExcerptNode(node);
    });
    owned.forEach(function(node) {
      node.setAttribute("data-fetchutil-excerpt-source", marker);
      if (readabilityBodyExcerptNode(node, structuredOwner)) node.setAttribute("data-fetchutil-excerpt-body", marker);
    });
    var summaryContainers = Array.prototype.filter.call(root.querySelectorAll(readabilitySummarySelector()), function(container) {
      return readabilityExcerptNode(container);
    });
    var summaryStack = [];
    var topLevelSummaryContainers = [];
    summaryContainers.forEach(function(container) {
      while (summaryStack.length && !summaryStack[summaryStack.length - 1].contains(container)) {
        summaryStack.pop();
      }
      if (!summaryStack.length) topLevelSummaryContainers.push(container);
      summaryStack.push(container);
    });
    summaryContainers = topLevelSummaryContainers;
    if (summaryContainers.length === 1) {
      var container = summaryContainers[0];
      var parts = [];
      if (container.matches("p, li")) parts.push(container);
      parts = parts.concat(Array.prototype.slice.call(container.querySelectorAll("p, li")));
      parts = parts.filter(function(node) {
        return node.getAttribute("data-fetchutil-excerpt-source") === marker && !node.querySelector("p, li");
      });
      if (parts.length) {
        var group = marker + ":0";
        container.setAttribute("data-fetchutil-excerpt-summary-root", group);
        parts.forEach(function(node) { node.setAttribute("data-fetchutil-excerpt-summary", group); });
      }
    }
    return marker;
  }

  function stripReadabilityExcerptMarkers(html, marker) {
    var template = document.createElement("template");
    template.innerHTML = html;
    template.content.querySelectorAll("[data-fetchutil-excerpt-source], [data-fetchutil-excerpt-body], [data-fetchutil-excerpt-summary], [data-fetchutil-excerpt-summary-root]").forEach(function(node) {
      if (node.getAttribute("data-fetchutil-excerpt-source") === marker) {
        node.removeAttribute("data-fetchutil-excerpt-source");
      }
      if (node.getAttribute("data-fetchutil-excerpt-body") === marker) {
        node.removeAttribute("data-fetchutil-excerpt-body");
      }
      var group = node.getAttribute("data-fetchutil-excerpt-summary") || "";
      if (group.indexOf(marker + ":") === 0) node.removeAttribute("data-fetchutil-excerpt-summary");
      var rootGroup = node.getAttribute("data-fetchutil-excerpt-summary-root") || "";
      if (rootGroup.indexOf(marker + ":") === 0) node.removeAttribute("data-fetchutil-excerpt-summary-root");
    });
    return template.innerHTML;
  }
