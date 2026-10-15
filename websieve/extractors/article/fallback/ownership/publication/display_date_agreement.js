function sourceOwnedPublishedDisplayDate(value) {
  var display = normalizeText(value);
  if (/^updated\b/i.test(display)) return { kind: "updated" };
  var match = display.match(/^(?:published|posted)(?:\s+on)?\s*(?=(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d))/i);
  if (match) display = display.slice(match[0].length).trim();
  var month = "(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)";
  var months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
  var named = display.match(new RegExp("^" + month + "\\s+(\\d{1,2}),?\\s+(\\d{4})", "i"));
  var reversed = !named && display.match(new RegExp("^(\\d{1,2})\\s+" + month + "\\s+(\\d{4})", "i"));
  var iso = !named && !reversed && display.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!named && !reversed && !iso) return { kind: "opaque" };
  var year = Number(iso ? iso[1] : named ? named[3] : reversed[3]);
  var monthNumber = iso ? Number(iso[2]) : months.indexOf((named ? named[1] : reversed[2]).slice(0, 3).toLowerCase()) + 1;
  var dayNumber = Number(iso ? iso[3] : named ? named[2] : reversed[1]);
  var local = new Date(Date.UTC(year, monthNumber - 1, dayNumber));
  if (local.getUTCFullYear() !== year || local.getUTCMonth() + 1 !== monthNumber || local.getUTCDate() !== dayNumber) {
    return { kind: "opaque" };
  }
  var remainder = display.slice((named || reversed || iso)[0].length);
  var clock = remainder.match(iso ? /^(?:T|\s+)(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?/i :
    /^\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?/i);
  if (clock) remainder = remainder.slice(clock[0].length);
  var zone = remainder.match(/^\s*(Z|[+-]\d{2}:?\d{2})$/i);
  if (remainder.trim() && !zone || clock &&
      (Number(clock[1]) > (clock[4] ? 12 : 23) || Number(clock[1]) < (clock[4] ? 1 : 0) ||
       Number(clock[2]) > 59 || Number(clock[3] || 0) > 59)) return { kind: "unsupported" };
  var hour = clock && Number(clock[1]);
  if (clock && clock[4]) hour = hour % 12 + (/pm/i.test(clock[4]) ? 12 : 0);
  var day = String(year).padStart(4, "0") + "-" + String(monthNumber).padStart(2, "0") + "-" + String(dayNumber).padStart(2, "0");
  return { kind: "calendar", day: day, clock: clock ? String(hour).padStart(2, "0") + ":" + clock[2] : "",
    seconds: clock && clock[3] || "", zone: zone && zone[1] || "" };
}

function sourceOwnedDisplayAgreesWithPreciseDate(visible, precise) {
  var display = sourceOwnedPublishedDisplayDate(visible);
  if (display.kind !== "calendar") return display.kind === "opaque";
  var localDate = normalizeText(precise).match(/^(\d{4}-\d{2}-\d{2})(?:[T ](\d{2}:\d{2})(?::(\d{2}))?)?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/i);
  if (!localDate || display.day !== localDate[1]) return false;
  // An unzoned display clock cannot be equated with a zoned record clock.
  // Compare clock components only when both are in the same declared zone.
  if (display.zone && (!localDate[4] || display.zone !== localDate[4] ||
      display.clock && display.clock !== localDate[2] || display.seconds && display.seconds !== localDate[3])) return false;
  if (!display.zone && !localDate[4] && display.clock &&
      (display.clock !== localDate[2] || display.seconds && display.seconds !== localDate[3])) return false;
  return true;
}

function sourceOwnedPairedPublicationTime(nodes, records) {
  if (!records || records.length !== 1 || nodes.length !== 1) return null;
  var node = nodes[0];
  if (!node || typeof node === "string" || !node.children) return null;
  var fields = Array.from(node.children);
  if (fields.length < 2 || fields.some(function(field) { return !field.matches("time[datetime]"); })) return null;
  if (normalizeText(node.textContent || "") !== normalizeText(fields.map(function(field) {
    return field.textContent || "";
  }).join(" "))) return null;
  var publicationSelector = "[itemprop~='datePublished' i], .published, .dt-published";
  var modificationSelector = "[itemprop~='dateModified' i], .updated, .dt-updated";
  var published = fields.filter(function(field) { return field.matches(publicationSelector); });
  if (published.length !== 1 || published[0].matches(modificationSelector) || fields.some(function(field) {
    return field !== published[0] && !field.matches(modificationSelector);
  })) return null;
  var visible = sourceOwnedPublicationNodeDate(published[0]);
  var precise = entityText(records[0].datePublished);
  if (sourceOwnedPublishedDisplayDate(visible).kind !== "calendar" || !Number.isFinite(Date.parse(precise)) ||
      !sourceOwnedDisplayAgreesWithPreciseDate(visible, precise)) return null;
  var head = sourceOwnedHeadPublicationTime();
  return head.ambiguous || head.value && !sourceOwnedPublicationDatesEquivalent(head.value, precise) ?
    { publishedTime: null } : { publishedTime: precise };
}
