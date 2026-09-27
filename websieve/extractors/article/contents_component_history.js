function contentsComponentDateKey(value) {
  var text = normalizeText(value || "");
  var iso = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (iso) return iso[1] + "-" + iso[2] + "-" + iso[3];

  var months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
  var dayFirst = text.match(/\b(\d{1,2})\s+([a-z]+)\s+(\d{4})\b/i);
  var monthFirst = text.match(/\b([a-z]+)\s+(\d{1,2}),?\s+(\d{4})\b/i);
  var match = dayFirst || monthFirst;
  if (!match) return null;
  var month = months.indexOf((dayFirst ? match[2] : match[1]).toLowerCase()) + 1;
  if (!month) return null;
  var day = dayFirst ? match[1] : match[2];
  var year = dayFirst ? match[3] : match[3];
  return year + "-" + String(month).padStart(2, "0") + "-" + String(day).padStart(2, "0");
}

function contentsComponentParseInstant(value) {
  var text = normalizeText(value || "");
  var match = text.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{1,2}):(\d{1,2})(\.\d+)?(Z|[+-]\d{2}:\d{2})$/);
  if (!match) return NaN;
  var year = Number(match[1]);
  var month = Number(match[2]);
  var day = Number(match[3]);
  var hour = Number(match[4]);
  var minute = Number(match[5]);
  var second = Number(match[6]);
  var offset = match[8].match(/^[+-](\d{2}):(\d{2})$/);
  if (month < 1 || month > 12 || day < 1 || day > new Date(Date.UTC(year, month, 0)).getUTCDate() ||
      hour > 23 || minute > 59 || second > 59 ||
      (offset && (Number(offset[1]) > 23 || Number(offset[2]) > 59))) return NaN;
  var canonical = match[1] + "-" + match[2] + "-" + match[3] + "T" + match[4] + ":" +
    String(minute).padStart(2, "0") + ":" + String(second).padStart(2, "0") +
    (match[7] || "") + match[8];
  return Date.parse(canonical);
}

function contentsComponentVisibleLastUpdatedKey(node) {
  var text = normalizeText(visibleMetadataNodeText(node));
  var matches = text.match(/\bLast updated\s+\d{1,2}\s+[A-Za-z]+\s+\d{4}\b/gi) || [];
  if (matches.length !== 1) return null;
  return contentsComponentDateKey(matches[0].replace(/^Last updated\s+/i, ""));
}

function contentsComponentControlledHiddenHistory(component, branch, list) {
  for (var target = list && list.parentElement; target && target !== branch; target = target.parentElement) {
    if (!target.id || !elementSubtreeHidden(target)) continue;
    var matchingIds = Array.prototype.filter.call(document.querySelectorAll("[id]"), function(node) {
      return node.id === target.id;
    });
    if (matchingIds.length !== 1 || matchingIds[0] !== target) continue;
    var controls = Array.prototype.filter.call(branch.querySelectorAll("a[aria-controls]"), function(link) {
      var ids = normalizeText(link.getAttribute("aria-controls") || "").split(/\s+/);
      return !elementVisuallyHidden(link) && ids.indexOf(target.id) !== -1 &&
        link.getAttribute("href") === "#" + target.id && link.getAttribute("aria-expanded") === "false" &&
        normalizeText(visibleMetadataNodeText(link)).toLowerCase() === "show all updates";
    });
    if (controls.length === 1 && branch.contains(controls[0]) && target.contains(list)) {
      return { target: target, control: controls[0] };
    }
  }
  return null;
}

function contentsComponentBefore(first, second) {
  return !!(first && second && (first.compareDocumentPosition(second) & 4));
}
