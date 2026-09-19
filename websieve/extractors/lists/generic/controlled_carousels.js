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

    var links = Array.prototype.map.call(slide.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean);
    links = links.filter(function(url, index) { return links.indexOf(url) === index; });
    if (links.length !== 1 || !slide.querySelector("img[src], img[srcset], picture source[srcset]")) return null;

    var text = normalizeText(slide.textContent);
    if (text.length < minimumListTitleLength(text) || slide.querySelector("form, input, select, textarea, [contenteditable]:not([contenteditable='false'])")) return null;
    return { label: label, url: links[0] };
  }

  function controlledListCarouselRoots(root) {
    var roots = [];
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
      var labels = records.map(function(record) { return record.label; });
      var urls = records.map(function(record) { return listCanonicalKey(record.url); });
      if (new Set(labels).size !== labels.length || new Set(urls).size !== urls.length) return;
      slides.forEach(function(slide) {
        if (roots.indexOf(slide) === -1) roots.push(slide);
      });
    });
    return roots;
  }
