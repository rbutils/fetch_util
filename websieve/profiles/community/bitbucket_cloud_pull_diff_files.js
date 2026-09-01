function bitbucketCloudSafeSupplementalValue(value) {
  if (Array.isArray(value)) return value.map(bitbucketCloudSafeSupplementalValue).filter(function(item) {
    return item !== null;
  });
  if (value && typeof value === "object") {
    return Object.keys(value).reduce(function(result, key) {
      var safe = bitbucketCloudSafeSupplementalValue(value[key]);
      if (safe !== null) result[key] = safe;
      return result;
    }, {});
  }
  if (typeof value === "string") {
    var candidate = value.trim();
    if (/^[a-z][a-z0-9+.-]*:/i.test(candidate)) return materializedHttpUrl(candidate);
  }
  return value;
}

function bitbucketCloudDiffFilePath(file) {
  return normalizeText(file && file.path);
}

function bitbucketCloudDiffFileLink(file) {
  var links = file && file.links || {};
  return materializedHttpUrl(links.html && links.html.href) || materializedHttpUrl(links.self && links.self.href);
}

function bitbucketCloudDiffFileInventoryEntries(record, index) {
  var entries = [];
  [["Old", record.old], ["New", record.new]].forEach(function(pair) {
    var file = pair[1];
    if (!file || typeof file !== "object") return;
    var url = bitbucketCloudDiffFileLink(file);
    if (url) entries.push({ label: pair[0] + " source for " + bitbucketCloudDiffFilePath(file), url: url });
  });
  var self = materializedHttpUrl(record.links && record.links.self && record.links.self.href);
  if (self) entries.push({ label: "Diffstat record " + (index + 1), url: self });
  return entries;
}

function bitbucketCloudDiffFileSections(record, index) {
  var oldPath = bitbucketCloudDiffFilePath(record.old);
  var newPath = bitbucketCloudDiffFilePath(record.new);
  var title = newPath || oldPath || ("Changed file " + (index + 1));
  var sections = ["### " + title];
  var status = normalizeText(record.status);
  if (status) sections.push("- Status: " + status);
  if (oldPath && oldPath !== newPath) sections.push("- Old path: " + oldPath);
  if (newPath) sections.push("- New path: " + newPath);
  if (Number.isFinite(record.lines_added)) sections.push("- Lines added: " + record.lines_added);
  if (Number.isFinite(record.lines_removed)) sections.push("- Lines removed: " + record.lines_removed);
  if (record.old && record.old.attributes) {
    sections.push("- Old attributes: " + JSON.stringify(bitbucketCloudSafeSupplementalValue(record.old.attributes)));
  }
  if (record.new && record.new.attributes) {
    sections.push("- New attributes: " + JSON.stringify(bitbucketCloudSafeSupplementalValue(record.new.attributes)));
  }
  var completeRecord = bitbucketCloudSafeSupplementalValue(record);
  sections.push("- Complete diffstat record: " + JSON.stringify(completeRecord));
  return sections;
}

function bitbucketCloudLoadedDiffArticles() {
  return Array.prototype.slice.call(document.querySelectorAll("article[data-qa='branch-diff-file']")).filter(function(node) {
    return !elementSubtreeHidden(node);
  });
}
