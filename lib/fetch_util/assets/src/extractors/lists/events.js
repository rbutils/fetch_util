  function eventStructuredDataNodes() {
    return structuredDataNodes().filter(function(node) {
      return nodeTypes(node).some(function(type) {
        return /(?:^|\/)(?:Event|EventReservation|WorkEvent)$/i.test(type);
      });
    });
  }

  function eventStructuredDataNode() {
    var nodes = eventStructuredDataNodes();
    if (nodes.length > 1 && eventListingPage()) return null;
    return nodes[0] || null;
  }

  function eventListingPage() {
    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    var title = normalizeText([document.title || "", (document.querySelector("h1") || {}).textContent || ""].join(" ")).toLowerCase();
    if (hostMatches(/(^|\.)eventbrite\.com$/) && /^\/e\//i.test(location.pathname || "")) return false;
    if (/\/events?\/[^/?#]+\/\d+\/?$/i.test(path)) return false;
    if (/\b(?:schedule|agenda|program(?:me)?)\b/.test(path + " " + title)) return true;
    if (/\/(?:events?|conferences?|calendar)\/?$/i.test(path)) return true;
    if (/\/events\/[^/]*events?\/?$/i.test(path)) return true;
    if (/\b(?:our events|upcoming events|event calendar|python events)\b/.test(title)) return true;

    var eventCards = document.querySelectorAll("[class*='event-card' i], [class*='event-list' i] article, [class*='event' i] article, li[class*='event' i]").length;
    var eventLinks = Array.prototype.filter.call(document.querySelectorAll("a[href*='/events/'], a[href*='/event/']"), function(link) {
      return normalizeText(link.textContent || "").length >= 8;
    }).length;
    return eventCards >= 3 || eventLinks >= 4;
  }

  function eventDateText(startDate, endDate) {
    var start = entityText(startDate);
    var end = entityText(endDate);
    if (start && end && start !== end) return start + " - " + end;
    return start || end || null;
  }

  function eventLocationText(value) {
    if (!value) return null;
    if (typeof value === "string") return normalizeText(value);
    if (Array.isArray(value)) return normalizeText(value.map(eventLocationText).filter(Boolean).join("; "));
    if (typeof value !== "object") return null;

    var address = value.address;
    var addressText = structuredPostalAddressText(address);

    return normalizeText([entityName(value), addressText].filter(Boolean).join(" - ")) || entityText(value);
  }

  function visibleEventDateTime(root) {
    root = root || document;
    var start = firstScopedText([root], ["[itemprop='startDate']", "time[datetime]"], "datetime") ||
      firstScopedText([root], ["[itemprop='startDate']", "[class*='start-date' i]", "[class*='event-date' i]", "[class*='date' i]", "time"]);
    var end = firstScopedText([root], ["[itemprop='endDate']"], "datetime") ||
      firstScopedText([root], ["[itemprop='endDate']", "[class*='end-date' i]"]);
    if (start || end) return eventDateText(start, end);

    var text = normalizeText((root && root.textContent) || "");
    var match = text.match(/\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)?\s*(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\s+\d{1,2}(?:\s*[-–]\s*\d{1,2})?,?\s+\d{4}(?:\s+(?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)?/);
    if (match) return normalizeText(match[0]);
    match = text.match(/\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\s+\d{4}(?:\s*,?\s*\d{1,2}:\d{2})?/);
    return match ? normalizeText(match[0]) : null;
  }

  function visibleEventLocation(root) {
    root = root || document;

    function cleanLocationText(node) {
      if (!node || /^(?:INPUT|TEXTAREA|SELECT|OPTION)$/i.test(node.tagName || "")) return null;
      var text = normalizeText(node.textContent || node.getAttribute("aria-label") || "");
      if (text.length < 5 || text.length > 260) return null;
      if (/^(?:location|autocomplete|search|use my current location|online event|virtual event)$/i.test(text)) return null;
      if (/\b(?:autocomplete|search events|find events|log in|sign up)\b/i.test(text)) return null;
      return text;
    }

    var selectors = [
      "[itemprop='location']",
      "[data-testid*='location' i]",
      "[class*='event-location' i]",
      "[class*='venue' i]",
      "[class*='address' i]",
      "[class*='location' i]"
    ];

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = root.querySelectorAll(selectors[i]);
      for (var n = 0; n < nodes.length; n += 1) {
        var text = cleanLocationText(nodes[n]);
        if (text) return text;
      }
    }

    var headings = root.querySelectorAll("h2, h3, h4, strong, dt");
    for (var h = 0; h < headings.length; h += 1) {
      if (!/^location$/i.test(normalizeText(headings[h].textContent || ""))) continue;
      var sibling = headings[h].nextElementSibling;
      while (sibling) {
        var siblingText = cleanLocationText(sibling);
        if (siblingText) return siblingText;
        sibling = sibling.nextElementSibling;
      }
    }

    return null;
  }

  function conferenceSchedulePage() {
    var context = normalizeText([location.hostname, location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" ")).toLowerCase();
    if (!/\b(schedule|agenda|program(?:me)?|world-congress|rubyconf|conference|summit)\b/.test(context)) return false;
    if (!/\b(schedule|agenda|program(?:me)?|conference|congress|summit|rubyconf)\b/.test(context)) return false;

    var text = normalizeText(document.body && document.body.textContent);
    var timeMatches = (text.match(/\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\b/g) || []).length;
    var sessionNodes = document.querySelectorAll("[class*='session' i], [class*='schedule' i], [class*='agenda' i], [class*='talk' i], [class*='speaker' i]").length;
    return timeMatches >= 3 || sessionNodes >= 4;
  }

  function genericEventListContent(metadata) {
    if (!conferenceSchedulePage()) return null;

    var root = document.querySelector("main, [role='main'], article, #content") || document.body;
    var clone = cleanClone(root);
    cleanupAgentRoot(clone);
    cleanupListRoot(clone);
    removeAll(clone, "form, script, style, noscript, [class*='modal' i], [class*='newsletter' i]");

    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    if (normalizeText(markdown).length < 300) return null;

    return listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: metadata.excerpt || firstText(["main h1", "h1"]),
      html: clone.innerHTML,
      textContent: markdown,
      markdown: markdown
    });
  }
