function deduplicateForgeThreadPermalinks(entries) {
  var seenPermalinks = new Set();
  return entries.filter(function(entry) {
    if (!entry) return false;
    if (!entry.permalink) return true;
    if (seenPermalinks.has(entry.permalink)) return false;

    seenPermalinks.add(entry.permalink);
    return true;
  });
}
