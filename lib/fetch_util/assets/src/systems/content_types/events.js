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
      description: structuredDescriptionMarkdown(event.description) || metadata.excerpt,
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
