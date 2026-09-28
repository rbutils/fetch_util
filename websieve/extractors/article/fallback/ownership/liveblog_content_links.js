function liveblogStandaloneShareControl(anchor) {
  if (!liveblogShareOrPermalink(anchor)) return false;
  var identity = [anchor.getAttribute("rel"), anchor.getAttribute("class"), anchor.id].join(" ");
  if (/(?:permalink|canonical|bookmark)/i.test(identity)) return false;
  if (anchor.closest("h1, h2, h3, h4, h5, h6, p, blockquote, figure, [itemprop~='articleBody' i]")) return false;

  var label = normalizeText([
    anchor.getAttribute("aria-label"), anchor.getAttribute("title"), anchor.textContent
  ].filter(Boolean).join(" "));
  var controlLabels = [
    /^share$/i,
    /^share this(?: update| story| article)?$/i,
    /^share (?:on|to) \S+$/i,
    /^copy(?: this)? link$/i,
    /^email$/i,
    /^print$/i
  ];
  var shareContainer = anchor.closest("[class*='share-controls' i], [class*='social-share' i], [class*='share-buttons' i], [class*='share_icon' i]");
  if (!shareContainer || !/share/i.test(identity)) return false;
  if (label && controlLabels.some(function(pattern) { return pattern.test(label); })) return true;

  var icon = anchor.querySelector("img, svg");
  if (!icon || normalizeText(anchor.textContent || "")) return false;
  return !normalizeText(icon.getAttribute("alt") || icon.getAttribute("aria-label") || icon.getAttribute("title") || "");
}

function liveblogSanitizeCredentialPermalink(anchor) {
  if (!liveblogShareOrPermalink(anchor)) return;
  var href = anchor.getAttribute("href");
  if (!href) return;
  try {
    var target = new URL(href, location.href);
    if (target.username || target.password) anchor.removeAttribute("href");
  } catch (_error) {}
}
