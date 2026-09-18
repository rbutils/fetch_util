  var PUBLISHER_CTA_NOTE_SELECTOR = "[class~='post-disclaimer' i], [class~='publisher-cta' i], [class~='publisher_cta' i]";
  var PUBLISHER_CTA_SENTENCE_PATTERN = new RegExp("^(?:" + [
    "(?:join|follow) (?:us )?on (?:telegram|whatsapp|instagram|facebook|youtube|twitter|x|viber)",
    "join (?:our )?(?:telegram|whatsapp|viber) (?:group|channel)",
    "(?:download|get|install) (?:our|the) app",
    "subscribe (?:now|today|here)",
    "sign up (?:for|to) (?:our )?(?:newsletter|updates|emails?)",
    "pratite nas na (?:našoj )?(?:facebook|instagram|youtube|twitter|x|telegram|viber)(?: i (?:facebook|instagram|youtube|twitter|x|telegram|viber))*(?: stranici| kanalu)?(?:, ali i na (?:facebook|instagram|youtube|twitter|x|telegram|viber)(?: nalogu)?)?",
    "pretplatite se na (?:naše )?(?:pdf|digitalno|štampano|online) izdanje(?: lista [^\\s.,!?]+)?",
    "пратите нас на (?:нашој )?(?:facebook|instagram|youtube|twitter|x|telegram|viber)(?: и (?:facebook|instagram|youtube|twitter|x|telegram|viber))*(?: страници| каналу)?(?:, али и на (?:facebook|instagram|youtube|twitter|x|telegram|viber)(?: налогу)?)?",
    "претплатите се на (?:наше )?(?:pdf|дигитално|штампано|онлајн) издање(?: листа [^\\s.,!?]+)?"
  ].join("|") + ")$", "iu");

  function publisherCtaSentences(text) {
    var normalized = normalizeText(text || "");
    if (normalized.normalize) normalized = normalized.normalize("NFC");
    return normalized.split(/[.!?。！？؟:;：；]+/u).map(function(sentence) { return sentence.trim(); }).filter(Boolean);
  }

  function publisherCtaHasNonClassAttributes(node) {
    return Array.prototype.some.call(node.attributes || [], function(attribute) {
      return attribute.name.toLowerCase() !== "class";
    });
  }

  function publisherCtaHasStructuredDescendant(note) {
    return Array.prototype.some.call(note.querySelectorAll("*"), function(element) {
      if (element.matches(PUBLISHER_CTA_NOTE_SELECTOR)) return true;
      if (!element.matches("p, strong, em, b, i, span, br")) return true;
      return publisherCtaHasNonClassAttributes(element);
    });
  }

  function stripPublisherCtaNotes(root) {
    root.querySelectorAll(PUBLISHER_CTA_NOTE_SELECTOR).forEach(function(note) {
      if (note.parentElement && note.parentElement.closest(PUBLISHER_CTA_NOTE_SELECTOR)) return;
      if (!note.matches("div, p, section, aside")) return;
      if (note.closest("[data-fetchutil-page-overview], [data-fetchutil-editorial-aside]")) return;
      if (publisherCtaHasNonClassAttributes(note) || publisherCtaHasStructuredDescendant(note)) return;
      if (note.querySelectorAll("p").length > 1) return;

      var text = normalizeText(note.textContent || "");
      if (!text || text.length > 500) return;
      var sentences = publisherCtaSentences(text);
      if (!sentences.length || !sentences.every(function(sentence) { return PUBLISHER_CTA_SENTENCE_PATTERN.test(sentence); })) return;
      note.remove();
    });
    return root;
  }
