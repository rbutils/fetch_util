function continuousTickerToken(node) {
  if (!node || node.nodeType !== 1) return false;
  if (node.tagName === "MARQUEE" || continuousTickerRoles(node).indexOf("marquee") !== -1) return true;
  if (node.hasAttribute("data-ticker") || node.hasAttribute("data-news-ticker")) return true;

  return Array.prototype.some.call(node.classList || [], function(token) {
    return /^(?:marquee|news-ticker|breaking-news-ticker|react-marquee-box)$/i.test(token);
  });
}

function continuousTickerExcludedClass(node) {
  return Array.prototype.some.call(node.classList || [], function(token) {
    return /(?:^|[-_])(?:carousel|slider|slideshow|slide|swiper|splide|slick|glide|tab|tabpanel)(?:$|[-_])/i.test(token);
  });
}

function continuousTickerRoles(node) {
  return normalizeText(node && node.getAttribute ? node.getAttribute("role") : "")
    .toLowerCase().split(/\s+/).filter(Boolean);
}

function continuousTickerUnavailableNode(node) {
  if (!node || node.nodeType !== 1) return false;
  if (node.matches("[hidden], [inert], [aria-hidden='true'], [aria-selected='false']")) return true;
  if (/^(?:closed|hidden|inactive)$/i.test(node.getAttribute("data-state") || "")) return true;
  if (node.hasAttribute("data-carousel") || node.hasAttribute("data-slider")) return true;
  if (/^(?:carousel|slide)$/i.test(node.getAttribute("aria-roledescription") || "")) return true;
  if (continuousTickerRoles(node).some(function(role) {
    return /^(?:tab|tablist|tabpanel)$/.test(role);
  })) return true;
  if (continuousTickerExcludedClass(node)) return true;

  var style = window.getComputedStyle ? window.getComputedStyle(node) : null;
  return !!(style && (
    style.display === "none" ||
    style.visibility === "hidden" ||
    style.visibility === "collapse" ||
    parseFloat(style.opacity || "1") === 0 ||
    style.contentVisibility === "hidden"
  ));
}

function continuousTickerRootUnavailable(root) {
  for (var current = root; current; current = composedDomParent(current)) {
    if (continuousTickerUnavailableNode(current)) return true;
  }
  return false;
}

function continuousTickerRecordKey(text, url) {
  return listCanonicalKey(url) + "\u0000" + normalizeText(text).toLowerCase();
}

function continuousTickerRecordText(root) {
  var parts = [];
  var stack = composedDomChildren(root).slice().reverse();
  while (stack.length) {
    var node = stack.pop();
    if (!node) continue;
    if (node.nodeType === 3) {
      parts.push(node.nodeValue || "");
      continue;
    }
    if (node.nodeType !== 1 || continuousTickerUnavailableNode(node)) continue;
    if (node.tagName === "IMG" && node.getAttribute("alt")) parts.push(node.getAttribute("alt"));
    var children = composedDomChildren(node);
    for (var index = children.length - 1; index >= 0; index -= 1) stack.push(children[index]);
  }

  return normalizeText(parts.join(" ")) || normalizeText(root.getAttribute("aria-label") || root.getAttribute("title"));
}

function collectContinuousTickerRecords(root) {
  if (continuousTickerRootUnavailable(root)) return [];

  var records = [];
  var seen = new Set();
  var repeatedRecord = false;
  var stack = composedDomChildren(root).slice().reverse();
  while (stack.length) {
    var node = stack.pop();
    if (!node || node.nodeType !== 1 || continuousTickerUnavailableNode(node)) continue;

    if (node.tagName === "A") {
      var text = continuousTickerRecordText(node);
      var url = materializedHttpUrl(node.getAttribute("href"));
      if (url && text.length >= 8 && !genericListControlText(text)) {
        var key = continuousTickerRecordKey(text, url);
        if (seen.has(key)) {
          repeatedRecord = true;
        } else {
          seen.add(key);
          records.push({ text: text, url: url, key: key });
        }
      }
    }

    var children = composedDomChildren(node);
    for (var index = children.length - 1; index >= 0; index -= 1) stack.push(children[index]);
  }

  var nativeMotion = root.tagName === "MARQUEE" || continuousTickerRoles(root).indexOf("marquee") !== -1;
  return records.length >= 3 && (nativeMotion || repeatedRecord) ? records : [];
}

function continuousTickerRecords() {
  var records = [];
  var seen = new Set();
  var stack = document.body ? [document.body] : [];
  while (stack.length) {
    var node = stack.pop();
    if (!node || node.nodeType !== 1 || continuousTickerUnavailableNode(node)) continue;

    if (continuousTickerToken(node)) {
      collectContinuousTickerRecords(node).forEach(function(record) {
        if (seen.has(record.key)) return;
        seen.add(record.key);
        records.push(record);
      });
      continue;
    }

    var children = composedDomChildren(node);
    for (var index = children.length - 1; index >= 0; index -= 1) stack.push(children[index]);
  }
  return records;
}

function representedTickerRecordKeys(content) {
  var keys = new Set();
  var pattern = /\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g;
  var match;
  while ((match = pattern.exec(content.markdown || ""))) {
    var url = materializedHttpUrl(match[2]);
    if (url) keys.add(continuousTickerRecordKey(match[1], url));
  }
  return keys;
}

function insertMissingTickerRecordLines(markdown, records, missing) {
  var lines = (markdown || "").split("\n");
  var recordKeys = new Set(records.map(function(record) { return record.key; }));
  var representedKeys = representedTickerRecordKeys({ markdown: markdown });
  var representedLines = [];
  lines.forEach(function(line, index) {
    var match = line.match(/^\s*-\s+\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)\s*$/);
    if (!match) return;
    var url = materializedHttpUrl(match[2]);
    if (!url) return;
    var key = continuousTickerRecordKey(match[1], url);
    if (recordKeys.has(key)) representedLines.push({ index: index, key: key });
  });

  var missingLines = missing.map(function(record) {
    return "- " + markdownLink(record.text, record.url);
  });
  var prefix = representedLines.length === representedKeys.size &&
    representedLines.length > 0 && representedLines.every(function(record, index) {
    return records[index] && records[index].key === record.key;
  });
  if (prefix) {
    var firstFollowingHeading = lines.findIndex(function(line) {
      return /^#{1,6}\s+404(?:\s|$)/i.test(line.trim());
    });
    var contiguous = representedLines.every(function(record, index) {
      return !index || record.index === representedLines[index - 1].index + 1;
    });
    if (!contiguous || (firstFollowingHeading >= 0 &&
        representedLines[representedLines.length - 1].index >= firstFollowingHeading)) {
      return markdown;
    }
    var insertAt = representedLines[representedLines.length - 1].index + 1;
    return lines.slice(0, insertAt).concat(missingLines, lines.slice(insertAt)).join("\n").trim();
  }
  return markdown;
}

function supplementNotFoundTickerHtml(html, records, represented, missing) {
  var container = document.createElement("div");
  container.innerHTML = html || "";
  var recordIndex = new Map();
  records.forEach(function(record, index) { recordIndex.set(record.key, index); });
  var found = [];
  var foundKeys = new Set();
  var duplicate = false;
  Array.from(container.querySelectorAll("a[href]")).forEach(function(link) {
    var url = materializedHttpUrl(link.getAttribute("href"));
    if (!url) return;
    var key = continuousTickerRecordKey(link.textContent, url);
    if (!recordIndex.has(key)) return;
    if (foundKeys.has(key)) {
      duplicate = true;
      return;
    }
    foundKeys.add(key);
    found.push({
      key: key,
      index: recordIndex.get(key),
      link: link,
      record: link.closest("[class~='marquee-container'], article, li, p") || link
    });
  });
  if (duplicate || !found.length || found.length !== represented.size || found.some(function(entry, index) {
    return entry.index !== index;
  })) return null;
  var recordParent = found[0].record.parentElement;
  if (!recordParent || found.some(function(entry, index) {
    return entry.record.parentElement !== recordParent ||
      (index && found[index - 1].record.nextElementSibling !== entry.record);
  })) return null;
  var first404 = Array.from(container.querySelectorAll("h1, h2, h3, h4, h5, h6")).find(function(heading) {
    return /^404(?:\s|$)/i.test(normalizeText(heading.textContent));
  });
  var lastFound = found[found.length - 1];
  if (first404 && !(lastFound.record.compareDocumentPosition(first404) & Node.DOCUMENT_POSITION_FOLLOWING)) {
    return null;
  }

  var supplement = document.createElement("div");
  supplement.setAttribute("data-fetch-util-not-found-ticker", "");
  missing.forEach(function(record) {
    var paragraph = document.createElement("p");
    var link = document.createElement("a");
    link.setAttribute("href", record.url);
    link.textContent = record.text;
    paragraph.appendChild(link);
    supplement.appendChild(paragraph);
  });
  if (found.length) {
    var lastRecord = lastFound.record;
    if (!lastRecord.parentNode) return null;
    lastRecord.parentNode.insertBefore(supplement, lastRecord.nextSibling);
  } else {
    container.appendChild(supplement);
  }
  return container.innerHTML;
}

function supplementNotFoundTickerRecords(content, metadata, pageText) {
  if (!content || interstitialPageType(metadata, pageText) !== "not_found") return content;

  var records = continuousTickerRecords();
  if (!records.length) return content;
  var represented = representedTickerRecordKeys(content);
  var missing = records.filter(function(record) { return !represented.has(record.key); });
  if (!missing.length) return content;

  var markdown = insertMissingTickerRecordLines(content.markdown, records, missing);
  if (markdown === content.markdown) return content;
  var html = supplementNotFoundTickerHtml(content.html, records, represented, missing);
  if (html === null) return content;
  var result = Object.assign({}, content);
  result.html = html;
  result.markdown = markdown;
  result.textContent = normalizeText(result.markdown);
  return result;
}
