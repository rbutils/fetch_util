function publicationSubscriptionInterfaceNode(node) {
  if (!node.matches("div, section, aside, form") ||
      node.closest("blockquote, pre, code, [itemprop~='comment' i], [data-fetchutil-social-comment]") ||
      node.querySelector("article, main, h1, blockquote, pre, code, table, video, audio, [itemprop~='articleBody' i]")) return false;

  var headings = Array.from(node.querySelectorAll("h2, h3, h4, h5, h6, [role='heading'], [class*='headline' i]"));
  var invitations = headings.filter(function(heading) {
    return /^(?:subscribe(?:\s+to)?\b|sign\s+up\b|(?:get|receive)\b.*\b(?:newsletter|updates|emails?|digest)\b)/i.test(normalizeText(heading.textContent || ""));
  });
  if (!invitations.length || headings.some(function(heading) {
    return !invitations.some(function(invitation) { return invitation === heading || invitation.contains(heading); });
  })) return false;

  var links = Array.from(node.querySelectorAll("a[href]"));
  var privacy = links.some(function(link) { return /privacy|datenschutz|confidentialit/i.test(link.getAttribute("href") || ""); });
  var terms = links.some(function(link) {
    return /terms|conditions|nutzungsbedingungen/i.test((link.getAttribute("href") || "") + " " + normalizeText(link.textContent || ""));
  });
  if (!privacy || !terms) return false;

  var controlOwner = publicationSubscriptionControlOwner(node, invitations);
  if (!controlOwner) return false;
  var email = controlOwner.querySelector("input[type='email' i], input[name='email' i]");
  var consent = controlOwner.querySelector("input[type='checkbox' i]");
  var action = Array.from(controlOwner.querySelectorAll("button, input[type='submit' i], [role='button']")).some(function(control) {
    return /(?:subscribe|sign\s+up|abonnier|s'abonner)/i.test(normalizeText(control.textContent || control.getAttribute("value") || ""));
  });
  if (!action || !email && !consent) return false;

  return Array.from(node.querySelectorAll("p")).every(function(paragraph) {
    if (!normalizeText(paragraph.textContent || "") || paragraph.closest("form")) return true;
    if (publicationSubscriptionConsentParagraph(paragraph, controlOwner)) return true;
    return !!paragraph.querySelector("a[href*='privacy' i], a[href*='terms' i], a[href*='conditions' i]") &&
      /(?:agree|acknowledg|subscrib|privacy|terms|consent|confidentialit|datenschutz)/i.test(normalizeText(paragraph.textContent || ""));
  });
}

function publicationSubscriptionConsentParagraph(paragraph, controlOwner) {
  var text = normalizeText(paragraph.textContent || "");
  if (!/offers|promotions|marketing|emails?|updates?|consent/i.test(text)) return false;
  var sources = Array.from(controlOwner.querySelectorAll("p")).filter(function(source) {
    return normalizeText(source.textContent || "") === text;
  });
  if (sources.length !== 1) return false;
  var label = sources[0].parentElement;
  return !!(label && label.querySelector("input[type='checkbox' i]") && label.querySelectorAll("p").length === 1 &&
    !label.querySelector("h1, h2, h3, h4, blockquote, pre, code, table, article"));
}

function publicationSubscriptionControlOwner(node, invitations) {
  if (node.querySelector("input[type='email' i], input[name='email' i], input[type='checkbox' i]")) return node;
  var sources = node.id ? Array.from(document.querySelectorAll("[id=" + JSON.stringify(node.id) + "]")) :
    node.className ? Array.from(document.getElementsByClassName(node.className)) : [];
  var labels = invitations.map(function(heading) { return normalizeText(heading.textContent || ""); });
  sources = sources.filter(function(source) {
    if (source.tagName !== node.tagName || source.getAttribute("class") !== node.getAttribute("class") || elementSubtreeHidden(source)) return false;
    if (source.querySelector("article, main, h1, blockquote, pre, code, table, video, audio, [itemprop~='articleBody' i]")) return false;
    var headings = Array.from(source.querySelectorAll("h2, h3, h4, h5, h6, [role='heading'], [class*='headline' i]"));
    return labels.every(function(label) {
      return headings.some(function(heading) { return normalizeText(heading.textContent || "") === label; });
    });
  });
  return sources.length === 1 ? sources[0] : null;
}
