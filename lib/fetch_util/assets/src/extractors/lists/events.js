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
    var addressText = null;
    if (typeof address === "string") {
      addressText = normalizeText(address);
    } else if (address && typeof address === "object") {
      addressText = normalizeText([
        address.streetAddress,
        address.addressLocality,
        address.addressRegion,
        address.postalCode,
        address.addressCountry && entityText(address.addressCountry)
      ].filter(Boolean).join(", "));
    }

    return normalizeText([entityName(value), addressText].filter(Boolean).join(" - ")) || entityText(value);
  }

  function eventDescriptionMarkdown(value) {
    var text = typeof value === "string" ? value : entityText(value);
    if (!normalizeText(text)) return null;

    if (/<[a-z][\s\S]*>/i.test(text) && typeof markdownFor === "function") {
      var root = document.createElement("div");
      root.innerHTML = text;
      return cleanupMarkdownNoise(markdownFor(root.innerHTML));
    }

    return cleanupMarkdownNoise(text);
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

  function eventContentResult(options) {
    var title = normalizeText(options.title || "");
    var dateText = normalizeText(options.dateText || "");
    var locationText = normalizeText(options.location || "");
    var description = cleanupMarkdownNoise(String(options.description || "")).trim();
    if (!title || (!dateText && normalizeText(description).length < 80)) return null;

    var details = [];
    if (dateText) details.push("Date: " + dateText);
    if (locationText) details.push("Location: " + locationText);

    var markdown = [
      "# " + title,
      details.length ? details.map(function(item) { return "- " + item; }).join("\n") : null,
      description
    ].filter(Boolean).join("\n\n").trim();

    return {
      title: title,
      byline: null,
      excerpt: normalizeText(description) || dateText || null,
      siteName: options.siteName || location.hostname,
      publishedTime: dateText || null,
      location: locationText || null,
      description: description || null,
      html: options.html || "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "event"
    };
  }

  function structuredEventContent(metadata) {
    if (eventListingPage()) return null;

    var event = eventStructuredDataNode();
    if (!event) return null;

    return eventContentResult({
      title: entityText(event.name) || entityText(event.title) || metadata.title || document.title,
      dateText: eventDateText(event.startDate, event.endDate),
      location: eventLocationText(event.location),
      description: eventDescriptionMarkdown(event.description) || metadata.excerpt,
      siteName: metadata.siteName,
      html: typeof event.description === "string" ? event.description : ""
    });
  }

  function likelyEventDetailPage() {
    if (eventListingPage()) return false;
    if (eventStructuredDataNode()) return true;
    if (eventStructuredDataNodes().length > 1 && eventListingPage()) return false;
    if (conferenceSchedulePage()) return false;

    var context = normalizeText([location.hostname, location.pathname, document.title, metadataValue("og:type", "property")].join(" ")).toLowerCase();
    if (!/\b(eventbrite|events?|conference|summit|workshop|webinar|meetup|tickets?)\b/.test(context)) return false;

    if (hostMatches(/(^|\.)eventbrite\.com$/) && /^\/e\//i.test(location.pathname || "")) return true;

    var body = normalizeText(document.body && document.body.textContent).toLowerCase();
    var cues = 0;
    var dateText = visibleEventDateTime(document.querySelector("main, article, [role='main']") || document.body) || metadataValue("startDate", "itemprop") || metadataValue("date", "name");
    if (dateText) cues += 1;
    if (document.querySelector("[itemprop='location'], [class*='location' i], [data-testid*='location' i]")) cues += 1;
    if (/\b(add to calendar|date and time|location|refund policy|about this event|register|tickets?)\b/.test(body)) cues += 1;
    if (dateText && /\/events?\/[^/?#]+\/\d+\/?$/i.test(location.pathname || "")) return true;
    return cues >= 2;
  }

  function domEventContent(metadata) {
    if (!likelyEventDetailPage()) return null;

    var root = document.querySelector("main, article, [role='main'], [class*='event' i], #content") || document.body;
    var clone = cleanClone(root);
    cleanupAgentRoot(clone);
    removeAll(clone, "nav, header, footer, aside, form, script, style, noscript, [class*='ticket' i], [class*='checkout' i], [class*='modal' i]");

    var descriptionRoot = root.querySelector("[data-testid*='description' i], [class*='description' i], [class*='about' i], [class*='summary' i], article, section") || root;
    var descriptionClone = cleanClone(descriptionRoot);
    cleanupAgentRoot(descriptionClone);
    removeAll(descriptionClone, "nav, header, footer, aside, form, script, style, noscript, [class*='ticket' i], [class*='checkout' i]");

    return eventContentResult({
      title: firstText(["main h1", "article h1", "h1"]) || metadata.title || document.title,
      dateText: visibleEventDateTime(root) || metadata.publishedTime,
      location: visibleEventLocation(root),
      description: cleanupMarkdownNoise(markdownFor(descriptionClone.innerHTML)) || metadata.excerpt,
      siteName: metadata.siteName,
      html: clone.innerHTML
    });
  }

  function eventContent(metadata) {
    return structuredEventContent(metadata) || domEventContent(metadata);
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
