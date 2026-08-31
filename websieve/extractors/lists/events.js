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

  function eventDetailPage() {
    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    return (hostMatches(/(^|\.)eventbrite\.com$/) && /^\/e\//i.test(location.pathname || "")) ||
      /\/events?\/[^/?#]+\/\d+\/?$/i.test(path);
  }

  function eventIndexPage() {
    var path = safeDecodeURI(location.pathname || "").toLowerCase();
    if (eventDetailPage()) return false;
    if (/(?:^|\/)(?:schedule|agenda|program(?:me)?)(?:\/|$)/.test(path)) return true;
    if (/\/(?:events?|conferences?|calendar)\/?$/i.test(path)) return true;
    return /\/events\/[^/]*events?\/?$/i.test(path);
  }

  function explicitEventListingPage() {
    if (eventIndexPage()) return true;
    var context = normalizeText([location.pathname || "", document.title || "", (document.querySelector("h1") || {}).textContent || ""].join(" ")).toLowerCase();
    return /\b(?:schedule|agenda|program(?:me)?|our events|upcoming events|event calendar|python events)\b/.test(context);
  }

  function eventListingPage() {
    if (eventDetailPage()) return false;
    if (explicitEventListingPage()) return true;

    var eventCards = eventCardItems().filter(function(item) { return item.admission; }).length;
    var eventLinks = Array.prototype.filter.call(document.querySelectorAll("a[href*='/events/'], a[href*='/event/'], a[href*='/e/'], a[href*='tickets-']"), function(link) {
      return !elementVisuallyHidden(link) && normalizeText(link.textContent || "").length >= 8 && !!materializedHttpUrl(link.getAttribute("href"));
    }).length;
    return eventCards >= 3 || eventLinks >= 4;
  }

  function eventCardItems() {
    var items = [];
    var seen = {};
    var selectors = "[class*='event-card' i], [class*='event-list' i] article, [class*='event' i] article, li[class*='event' i], [data-testid*='event' i]";
    var records = [];
    var recordsByCard = new Map();

    function collectCard(card, link) {
      if (!card) return;
      var existing = recordsByCard.get(card);
      if (existing) {
        if (!existing.link && link) existing.link = link;
        return;
      }

      var record = { card: card, link: link || null, index: records.length };
      recordsByCard.set(card, record);
      records.push(record);
    }

    function addCard(card, link) {
      if (elementVisuallyHidden(card) || card.closest("nav, header, footer, aside, form, [aria-hidden='true'], [hidden]")) return;
      if (!link || elementVisuallyHidden(link)) {
        link = Array.prototype.find.call(card.querySelectorAll("a[href]"), function(candidate) {
          return !elementVisuallyHidden(candidate);
        });
      }
      var title = normalizeText((card.querySelector("h2, h3, h4, [class*='title' i]") || link || {}).textContent || "");
      var parent = card.parentElement || card;
      var dateText = visibleEventDateTime(card) || visibleEventDateTime(parent);
      var locationText = visibleEventLocation(card) || visibleEventLocation(parent);
      var href = (link && link.getAttribute("href")) || "";
      var url = materializedHttpUrl(href);
      var item = { text: title, url: url, detail: [dateText, locationText].filter(Boolean).join(" - "), admission: !href || !!url };
      var key = listItemMaterialIdentity(item, href);
      if (!title || !dateText || seen[key]) return;
      seen[key] = true;
      items.push(item);
    }

    Array.prototype.forEach.call(document.querySelectorAll(selectors), function(card) {
      collectCard(card);
    });
    Array.prototype.forEach.call(document.querySelectorAll("a[href*='/e/'], a[href*='tickets-']"), function(link) {
      if (elementVisuallyHidden(link)) return;
      var card = link.closest("article, li, [role='listitem'], [data-testid*='event' i], [class*='event' i], [class*='card' i]") || link.parentElement;
      collectCard(card, link);
    });
    records.sort(function(left, right) {
      if (left.card === right.card) return left.index - right.index;
      var position = left.card.compareDocumentPosition(right.card);
      if (position & Node.DOCUMENT_POSITION_FOLLOWING) return -1;
      if (position & Node.DOCUMENT_POSITION_PRECEDING) return 1;
      return left.index - right.index;
    });
    records.forEach(function(record) {
      addCard(record.card, record.link);
    });

    return items;
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
    var match = text.match(/\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)?\s*(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\s+\d{1,2}(?:\s*[-–]\s*\d{1,2})?(?:,?\s+\d{4})?(?:\s+(?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)?/);
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

    var timeMatches = Math.max(conferenceScheduleTimeCount(), conferenceScheduleTimedNodeCount());
    var sessionNodes = document.querySelectorAll("[class*='session' i], [class*='schedule' i], [class*='agenda' i], [class*='talk' i], [class*='speaker' i]").length;
    return timeMatches >= 3 || sessionNodes >= 4;
  }

  function conferenceScheduleTimeCount() {
    var text = normalizeText(document.body && document.body.textContent);
    return (text.match(/\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\b/g) || []).length;
  }

  function eventScheduleEvidenceNode(node) {
    if (node.closest(RELATED_CONTAINER_SELECTOR)) return false;

    var section = node.closest("section, aside");
    var heading = section && section.querySelector("h1, h2, h3, h4");
    return !heading || !/^(?:related|recommended|similar|more|other)\s+(?:events?|sessions?)\b/i.test(normalizeText(heading.textContent));
  }

  function conferenceScheduleTimedNodeCount() {
    var root = document.querySelector("main") || document.body;
    var semanticTimes = root ? root.querySelectorAll("time") : [];
    var semanticCount = Array.prototype.filter.call(semanticTimes, function(node) {
      return eventScheduleEvidenceNode(node) &&
        /\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\b/.test(normalizeText(node.textContent));
    }).length;
    if (semanticCount >= 3) return semanticCount;

    var nodes = root ? root.querySelectorAll("[class*='session' i], [class*='schedule' i], [class*='agenda' i], [class*='talk' i]") : [];
    return Array.prototype.filter.call(nodes, function(node) {
      return eventScheduleEvidenceNode(node) &&
        /\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\b/.test(normalizeText(node.textContent));
    }).length;
  }

  function strongEventListingPage() {
    return eventIndexPage() ||
      (!eventDetailPage() && conferenceSchedulePage() && conferenceScheduleTimedNodeCount() >= 3);
  }

  function genericEventListContent(metadata) {
    var items = eventCardItems();
    var admissionCount = items.filter(function(item) { return item.admission; }).length;
    if (items.length >= 3 && admissionCount >= 3) {
      var genericEvidence = listContent(metadata, { portalRoot: true });
      return listItemsContentResult(metadata, {
        excerpt: items[0].text,
        html: genericEvidence.html,
        portalRootEvidence: genericEvidence.portalRootEvidence,
        items: items
      });
    }

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
