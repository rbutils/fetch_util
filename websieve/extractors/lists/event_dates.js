  function eventDateMilestoneText(text) {
    var value = normalizeText(text || "");
    var match = completeEventDateMatch(value);
    var label = match ? value.slice(0, match.index) : value;
    return /\b(?:release(?:d)?\s+(?:of\s+)?(?:the\s+)?(?:training|development|dev|test|data|dataset)|(?:training|development|dev|test)\s+(?:set|data)\s+release)\b/i.test(label) ||
      /\b(?:submissions?|camera[ -]?ready|(?:(?:challenge|paper|author|acceptance)\s+)?notifications?|decisions?|(?:papers?|abstracts?)\s+(?:deadline|due)|deadline)\b/i.test(label) ||
      /\b(?:registration\s+(?:opens?|closes?)|published|updated|copyright)\b/i.test(label);
  }

  function eventDateNodeOwned(node, root) {
    if (!node || elementVisuallyHidden(node) || node.closest("nav, footer, aside, form, pre, code, samp, kbd, script, style, noscript, template")) return false;
    for (var owner = node; owner; owner = owner.parentElement) {
      if (owner.tagName === "DETAILS" && !owner.hasAttribute("open")) {
        var summary = Array.prototype.find.call(owner.children, function(child) { return child.tagName === "SUMMARY"; });
        if (!summary || !summary.contains(node)) return false;
      }
      if (owner === root) break;
    }

    if (/^(?:startDate|endDate)$/.test(node.getAttribute("itemprop") || "")) return true;
    var block = node.closest("p, li, dt, dd, td, th") || node;
    var context = normalizeText(block.textContent || "");
    if (block.tagName === "DD") {
      var label = block.previousElementSibling;
      if (label && label.tagName === "DT") {
        var labelText = normalizeText(label.textContent || "");
        if (/^(?:training|development|dev|test)(?:\s+(?:data|set|dataset))?\s*:?(?:\s*)$/i.test(labelText)) return false;
        context = labelText + " " + context;
      }
    }
    if (/^(?:TD|TH)$/.test(block.tagName)) context = normalizeText((block.closest("tr") || block).textContent || "");
    if (eventDateMilestoneText(context)) return false;

    for (var field = node; field; field = field.parentElement) {
      if (/\b(?:byline|published|modified|updated|publication|copyright)\b/.test(visibleMetadataOwnerText(field))) return false;
      if (field === block || field === root) break;
    }
    return true;
  }

  function completeEventDateMatch(value) {
    var text = normalizeText(value || "");
    var month = "(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)";
    var day = "(?:[12]\\d|3[01]|0?[1-9])(?!\\d)";
    var range = day + "(?:\\s*[-–/]\\s*" + day + ")?";
    var weekday = "(?:(?:Mon(?:day)?|Tue(?:sday)?|Wed(?:nesday)?|Thu(?:rsday)?|Fri(?:day)?|Sat(?:urday)?|Sun(?:day)?)(?:,\\s*|\\s+))?";
    var time = "(?:\\s*,?\\s+(?:at\\s+)?(?:[01]?\\d|2[0-3])(?::[0-5]\\d)?\\s*(?:AM|PM)?(?!\\d))?";
    var patterns = [
      new RegExp("\\b" + range + "\\s+" + month + "\\s+\\d{4}(?!\\d)" + time, "i"),
      new RegExp("\\b" + weekday + month + "\\s+" + range + "(?:(?:\\s*,\\s*|\\s+)\\d{4}(?!\\d))?" + time, "i")
    ];
    var selected = null;
    patterns.forEach(function(pattern) {
      var match = pattern.exec(text);
      if (match && (!selected || match.index < selected.index)) selected = match;
    });
    return selected;
  }

  function eventDateFallbackText(root) {
    var selector = "p, li, dt, dd, td, th, h1, h2, h3, h4, h5, h6, time, span";
    var nodes = Array.prototype.slice.call(root.querySelectorAll(selector));
    if (root.matches && root.matches(selector)) nodes.unshift(root);
    for (var i = 0; i < nodes.length; i += 1) {
      var date = completeEventDateMatch(nodes[i].textContent || "");
      if (date && eventDateNodeOwned(nodes[i], root)) return normalizeText(date[0]);
    }

    if (!root.nodeType || root.nodeType !== 1 || !eventDateNodeOwned(root, root)) return null;
    var inlineText = Array.prototype.map.call(root.childNodes, function(child) {
      if (child.nodeType === 3) return child.nodeValue;
      if (child.nodeType !== 1 || /^(?:P|DIV|SECTION|ARTICLE|MAIN|UL|OL|DL|TABLE|H[1-6]|PRE|CODE)$/.test(child.tagName)) return "";
      return eventDateNodeOwned(child, root) ? child.textContent || "" : "";
    }).join("");
    var match = completeEventDateMatch(inlineText);
    return match && !eventDateMilestoneText(inlineText) ? normalizeText(match[0]) : null;
  }

  function visibleEventDateTime(root) {
    root = root || document;
    var acceptNode = function(node) { return eventDateNodeOwned(node, root); };
    var start = firstScopedText([root], ["[itemprop='startDate']", "time[datetime]"], "datetime", null, acceptNode) ||
      firstScopedText([root], ["[itemprop='startDate']", "[class*='start-date' i]", "[class*='event-date' i]", "[class*='date' i]", "time"], null, null, acceptNode);
    var end = firstScopedText([root], ["[itemprop='endDate']"], "datetime", null, acceptNode) ||
      firstScopedText([root], ["[itemprop='endDate']", "[class*='end-date' i]"], null, null, acceptNode);
    return start || end ? eventDateText(start, end) : eventDateFallbackText(root);
  }
