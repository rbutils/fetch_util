  function controlledListCarouselControl(owner, region, direction) {
    var pattern = direction === "previous" ? /\b(?:previous|prev|back)\b/i : /\b(?:next|forward)\b/i;
    var controls = Array.prototype.filter.call(
      owner.querySelectorAll("button[aria-label], [role='button'][aria-label]"),
      function(control) {
        if (region.contains(control) || control.closest("[hidden], [inert], [aria-hidden='true']")) return false;
        return pattern.test(normalizeText(control.getAttribute("aria-label")));
      }
    );
    return controls.length === 1 ? controls[0] : null;
  }

  function controlledListCarouselControlDisabled(control) {
    return !!control.disabled || control.hasAttribute("disabled") ||
      normalizeText(control.getAttribute("aria-disabled")).toLowerCase() === "true";
  }

  function controlledListCarouselSlideRecord(slide) {
    var role = normalizeText(slide.getAttribute("role")).toLowerCase();
    var roleDescription = normalizeText(slide.getAttribute("aria-roledescription")).toLowerCase();
    var label = normalizeText(slide.getAttribute("aria-label"));
    if (role !== "group" || roleDescription !== "slide" || !label || slide.hidden || slide.hasAttribute("inert")) return null;
    var labelNumbers = label.match(/\d+/g) || [];
    if (labelNumbers.length !== 2) return null;
    var ordinal = Number(labelNumbers[0]);
    var total = Number(labelNumbers[1]);
    if (!Number.isInteger(ordinal) || !Number.isInteger(total) || ordinal < 1 || total < 4) return null;

    var links = Array.prototype.map.call(slide.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean);
    links = links.filter(function(url, index) { return links.indexOf(url) === index; });
    if (links.length !== 1 || !slide.querySelector("img[src], img[srcset], picture source[srcset]")) return null;

    var titles = [];
    Array.prototype.forEach.call(slide.querySelectorAll("h1, h2, h3, h4, h5, h6, [role='heading']"), function(heading) {
      if (elementVisuallyHiddenWithin(heading, slide)) return;
      var text = normalizeText(heading.textContent || heading.getAttribute("aria-label") || "");
      if (text && titles.indexOf(text) === -1) titles.push(text);
    });
    if (titles.length !== 1 || titles[0].length < minimumListTitleLength(titles[0]) || titles[0].length > 240 ||
        slide.querySelector("form, input, select, textarea, [contenteditable]:not([contenteditable='false'])")) return null;
    return {
      label: label,
      ordinal: ordinal,
      total: total,
      url: links[0],
      text: titles[0],
      detail: "",
      controlledRoot: slide
    };
  }

  function controlledListCarouselCollections(root) {
    var collections = [];
    Array.prototype.forEach.call(root.querySelectorAll("[role='region'][aria-label]"), function(region) {
      if (!/\bcarousel\b/i.test(normalizeText(region.getAttribute("aria-label"))) || !region.parentElement) return;
      var owner = region.parentElement;
      var previousControl = controlledListCarouselControl(owner, region, "previous");
      var nextControl = controlledListCarouselControl(owner, region, "next");
      if (owner === document.body || !previousControl || !nextControl ||
          (controlledListCarouselControlDisabled(previousControl) && controlledListCarouselControlDisabled(nextControl))) return;

      var trackCandidates = [];
      Array.prototype.forEach.call(region.querySelectorAll("[role='group'][aria-roledescription]"), function(slide) {
        if (slide.parentElement && trackCandidates.indexOf(slide.parentElement) === -1) trackCandidates.push(slide.parentElement);
      });
      var tracks = trackCandidates.filter(function(track) {
        return track.children.length >= 4 && Array.prototype.every.call(track.children, function(slide) {
          return !!controlledListCarouselSlideRecord(slide);
        });
      });
      if (tracks.length !== 1) return;

      var slides = Array.prototype.slice.call(tracks[0].children);
      var records = slides.map(controlledListCarouselSlideRecord);
      if (records.some(function(record) { return !record; })) return;
      if (records.some(function(record, index) {
        return record.total !== slides.length || record.ordinal !== index + 1;
      })) return;
      var labels = records.map(function(record) { return record.label; });
      var urls = records.map(function(record) { return listCanonicalKey(record.url); });
      if (new Set(labels).size !== labels.length || new Set(urls).size !== urls.length) return;
      collections.push({ slides: slides, records: records });
    });
    return collections;
  }

  function controlledListCarouselRoots(root) {
    var roots = [];
    controlledListCarouselCollections(root).forEach(function(collection) {
      collection.slides.forEach(function(slide) {
        if (roots.indexOf(slide) === -1) roots.push(slide);
      });
    });
    return roots;
  }

  function controlledListCarouselItems(root) {
    var items = [];
    controlledListCarouselCollections(root).forEach(function(collection) {
      collection.records.forEach(function(record) { items.push(record); });
    });
    return items;
  }
