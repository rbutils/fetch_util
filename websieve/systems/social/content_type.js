  function normalizedSocialText(value) {
    var text = normalizeText(value || "");
    return text || null;
  }

  function socialInteger(value, allowNegative) {
    if (typeof value === "number") {
      if (!isFinite(value) || Math.floor(value) !== value) return null;
      if (!allowNegative && value < 0) return null;
      return value;
    }

    var text = normalizedSocialText(value);
    if (!text || !/^-?\d+$/.test(text)) return null;
    var number = Number(text);
    if (!isFinite(number) || (!allowNegative && number < 0)) return null;
    return number;
  }

  function clearSocialFields(content) {
    content.socialKind = null;
    content.platform = null;
    content.handle = null;
    content.replyCount = null;
    content.community = null;
    content.score = null;
  }

  function applySocialContentType(content) {
    if (!content || content.contentType !== "social") return content;

    var kind = normalizedSocialText(content.socialKind);
    if (["post", "thread", "feed", "profile"].indexOf(kind) === -1) {
      content.contentType = "article";
      clearSocialFields(content);
      return content;
    }

    content.socialKind = kind;
    content.platform = normalizedSocialText(content.platform);
    content.handle = normalizedSocialText(content.handle);
    content.replyCount = socialInteger(content.replyCount, false);
    content.community = normalizedSocialText(content.community);
    content.score = socialInteger(content.score, true);
    return content;
  }
