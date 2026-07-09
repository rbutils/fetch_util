function challengeHostLabel(metadata) {
  var candidates = [location.hostname, metadata && metadata.siteName, metadata && metadata.title];

  for (var i = 0; i < candidates.length; i += 1) {
    var value = normalizeText(candidates[i] || "").replace(/^www\./i, "");
    if (domainLikeText(value)) return value;
  }

  return null;
}

function challengeAssetText(signals) {
  signals = signals || {};
  return normalizeText([
    (signals.iframeTitles || []).join(" "),
    (signals.iframeSources || []).join(" "),
    (signals.scriptSources || []).join(" "),
    signals.bodyHtml || ""
  ].join(" ")).toLowerCase();
}

function challengeEducationalContext(page) {
  return /(this page explains|this is an experiment|example page|demonstrate a webauthn-based interactive challenge|not part of cloudflare challenge production code)/i.test(page || "");
}

function anubisChallengePage(title, page) {
  title = title || "";
  page = page || "";

  return /making sure you're not a bot!?/i.test(title + " " + page) ||
    (/protected by anubis/i.test(page) && /(enable javascript to get past this challenge|please wait a moment while we ensure the security of your connection|loading)/i.test(page));
}

function dataDomeChallengePage(title, page, signals) {
  title = title || "";
  page = page || "";
  var assets = challengeAssetText(signals);
  var nearEmpty = !page || normalizeText(page).length < 80;

  return /datadome captcha/i.test(title + " " + page) ||
    (nearEmpty && /(captcha-delivery\.com|datadome captcha|\bvar dd=)/i.test(assets));
}

function cloudflareChallengePage(title, page, signals) {
  title = title || "";
  page = page || "";
  var assets = challengeAssetText(signals);
  var nearEmpty = !page || normalizeText(page).length < 120;

  if (challengeEducationalContext(page)) return false;

  return /attention required! \| cloudflare/i.test(title) ||
    ((/just a moment/i.test(title) || /verify you are human|checking your browser|performing security verification|verification successful\. waiting for .* to respond|reviewing the security of your connection before proceeding|please enable javascript and cookies to continue|security service to protect/i.test(page)) &&
      !/this page explains/i.test(page)) ||
    (((/turnstile/i.test(title) || /turnstile/i.test(page)) && /managed challenge|interactive challenge/i.test(page)) && !challengeEducationalContext(page)) ||
    (nearEmpty && /(cdn-cgi\/challenge-platform|cloudflare ray id|turnstile|cf challenge)/i.test(assets) && !challengeEducationalContext(assets));
}

function challengePageType(metadata, pageText, signals) {
  var title = normalizeText(metadata.title || document.title);
  var page = normalizeText(pageText || "");

  if (anubisChallengePage(title, page)) return "anubis";
  if (dataDomeChallengePage(title, page, signals)) return "datadome";
  if (cloudflareChallengePage(title, page, signals)) return "cloudflare";
  return null;
}

function challengeFallbackTitle(type, metadata) {
  if (type === "anubis") return "Making sure you're not a bot!";

  var host = challengeHostLabel(metadata);
  if (host) return "Access verification required for " + host;

  if (type === "datadome") return "Access verification required";
  return "Verifying you are human";
}

function challengeFallbackDescription(type, signals) {
  var description = type === "anubis" ?
    "This page is presenting an Anubis challenge before the original content is available." :
    (type === "datadome" ?
      "This page is presenting a DataDome CAPTCHA challenge before the original content is available." :
      "This page is presenting a Cloudflare or Turnstile challenge before the original content is available.");

  if (signals && signals.textLength < 40 && signals.htmlLength > 200) {
    description += " The readable DOM content is effectively empty in this environment.";
  }

  return description;
}

function challengeContent(metadata, pageText, signals) {
  var type = challengePageType(metadata, pageText, signals);
  if (!type) return null;

  var title = normalizeText(metadata.title || document.title);
  if (!title || domainLikeText(title) || /^www\./i.test(title)) {
    title = challengeFallbackTitle(type, metadata);
  }

  var description = challengeFallbackDescription(type, signals);
  var details = [type === "anubis" ? "Challenge: Anubis" : (type === "datadome" ? "Challenge: DataDome" : "Challenge: Cloudflare/Turnstile")];
  if (signals && signals.textLength < 40 && signals.htmlLength > 200) details.push("Readable DOM: challenge page only");

  return articleContentFromParts({
    title: title,
    description: description,
    highlights: [],
    details: details,
    siteName: metadata.siteName || location.hostname,
    contentType: "interstitial"
  });
}
