  function statuspagePage(metadata) {
    if (document.body && /\bstatus\b/.test(document.body.className || "") && document.querySelector(".components-section, .component-container, .incident-container")) return true;
    if (document.querySelector("[data-statuspage-id], .components-section, #components, .incidents, .scheduled-maintenance")) return true;

    var signature = normalizeText([
      metadata && metadata.siteName,
      firstText(["meta[property='og:site_name']"], "content"),
      firstText([".powered-by a", "a[href*='atlassian.com/software/statuspage']"]),
      document.title
    ].join(" "));

    return /statuspage/i.test(signature) && !!document.querySelector(".layout-content.status, .components-statuses, .components-container");
  }

  function statuspageComponentStatus(node) {
    var inner = node.querySelector("[data-component-status]") || node;
    var status = normalizeText(inner.getAttribute("data-component-status") || "").replace(/_/g, " ");
    if (!status) status = firstTextFromNode(node, [".component-status", ".status-msg", ".status-icon-button"]);
    if (!status) {
      var statusButton = node.querySelector("[aria-label][class*='status'], [data-original-title][class*='status']");
      status = normalizeText((statusButton && (statusButton.getAttribute("aria-label") || statusButton.getAttribute("data-original-title"))) || "");
    }

    return status;
  }

  function statuspageVisible(node) {
    if (!node) return false;
    if (node.hidden || node.getAttribute("aria-hidden") === "true") return false;
    var style = window.getComputedStyle ? window.getComputedStyle(node) : null;
    return !(style && (style.display === "none" || style.visibility === "hidden" || style.opacity === "0"));
  }

  function statuspageComponents() {
    var seen = {};
    var components = [];

    Array.prototype.slice.call(document.querySelectorAll(".component-container")).forEach(function(node) {
      if (components.length >= 30) return;
      if (!statuspageVisible(node)) return;

      var name = firstTextFromNode(node, [".name", "[data-component-name]", "h3", "h4"]);
      if (!name || /^visit\s+/i.test(name)) return;

      var status = statuspageComponentStatus(node);
      var uptime = firstTextFromNode(node, ["[id^='uptime-percent-']", ".legend-item-uptime-value"]);
      var descriptionNode = node.querySelector("[data-original-title], [aria-label^='More information']");
      var description = normalizeText((descriptionNode && descriptionNode.getAttribute("data-original-title")) || "");
      var key = name.toLowerCase();
      if (seen[key]) return;
      seen[key] = true;

      var line = name;
      if (status) line += " - " + status;
      if (uptime && !/^(% uptime|uptime)$/i.test(uptime)) line += " (" + uptime.replace(/\s*%\s*uptime$/i, "% uptime") + ")";
      if (description && description.toLowerCase() !== name.toLowerCase()) line += " - " + description;
      components.push(line);
    });

    return components;
  }

  function statuspageIncidents() {
    var incidents = [];

    Array.prototype.slice.call(document.querySelectorAll(".incident-container, .scheduled-maintenance-container")).forEach(function(node) {
      if (incidents.length >= 8) return;
      if (!statuspageVisible(node)) return;

      var title = firstTextFromNode(node, [".incident-title a", ".incident-title", "a.whitespace-pre-wrap", "h3", "h4"]);
      if (!title) return;

      var lines = ["- " + title];
      Array.prototype.slice.call(node.querySelectorAll(".update")).slice(0, 4).forEach(function(update) {
        var state = firstTextFromNode(update, ["strong"]);
        var updateText = firstTextFromNode(update, [".whitespace-pre-wrap", "p"]);
        var timestamp = firstTextFromNode(update, ["small", "time"]);
        var detail = [];
        if (state) detail.push(state);
        if (updateText) detail.push(updateText);
        if (timestamp) detail.push(timestamp);
        if (detail.length) lines.push("  - " + detail.join(" - "));
      });

      incidents.push(lines.join("\n"));
    });

    return incidents;
  }

  function statuspageContent(metadata) {
    if (!statuspagePage(metadata)) return null;

    var title = firstText([".status-header h1", "h1"]) || metadata.title || document.title || "Status Page";
    var overall = firstText([".page-status .status", ".page-status", ".status.font-large", ".status-description"]);
    var intro = firstText([".text-section", "meta[name='description']"], "content") || metadata.excerpt;
    var components = statuspageComponents();
    var incidents = statuspageIncidents();

    if (!overall && components.length === 0 && incidents.length === 0) return null;

    var sections = ["# " + title];
    if (intro && intro.toLowerCase() !== title.toLowerCase()) sections.push(intro);
    if (overall) sections.push("- Overall status: " + overall);
    if (components.length) sections.push("## Components\n\n" + components.map(function(component) { return "- " + component; }).join("\n"));
    if (incidents.length) sections.push("## Recent Incidents\n\n" + incidents.join("\n"));

    var markdown = cleanupMarkdownNoise(sections.filter(Boolean).join("\n\n").trim());
    var text = normalizeText(markdown);
    if (text.length < 40) return null;

    return listItemsContentResult(metadata, {
      title: title,
      excerpt: overall || components[0] || incidents[0] || metadata.excerpt,
      html: ((document.querySelector(".layout-content.status") || document.querySelector("main") || document.body || {}).innerHTML) || "",
      markdown: markdown,
      textContent: text,
      contentType: "list",
      hostAware: true,
      statusPage: true
    });
  }

  function registerStatuspageProfiles() {
    registerHostAwareProfile(true, statuspageContent);
  }
