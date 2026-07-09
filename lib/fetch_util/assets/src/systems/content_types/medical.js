  function medicalWebPageStructuredDataNode() {
    return structuredDataNode(["MedicalWebPage"]);
  }

  function medicalStructuredDataNode() {
    return structuredDataNodeMatchingType(function(type) {
      return type === "MedicalWebPage" || type === "MedicalEntity" || /^Medical[A-Z]/.test(type);
    });
  }

  function healthArticleUrlSignal() {
    var host = (location.hostname || "").replace(/^www\./i, "").toLowerCase();
    var path = (location.pathname || "").toLowerCase();

    if (/cdc\.gov$/.test(host) && /\/(?:about|signs-symptoms|symptoms|causes|risk-factors|testing|treatment|prevention|living-with|basics|facts)\b/.test(path)) return true;
    if (/mayoclinic\.org$/.test(host) && /\/diseases-conditions\/[^/]+\/(?:symptoms-causes|diagnosis-treatment|in-depth)\//.test(path)) return true;
    if (/webmd\.com$/.test(host) && /\/(?:depression|anxiety|mental-health|a-to-z-guides?|pain-management|diabetes|heart-disease|cancer|lung)\b/.test(path)) return true;
    if (/nhs\.uk$/.test(host) && /\/conditions\/[^/]+\//.test(path)) return true;
    if (/who\.int$/.test(host) && /\/news-room\/fact-sheets\/detail\//.test(path)) return true;

    return false;
  }

  function substantialMedicalArticleContent(content) {
    if (!content) return false;

    var root = document.createElement("div");
    root.innerHTML = content.html || "";
    var text = normalizeText(root.textContent || content.textContent || content.markdown || "");
    if (text.length < 420) return false;

    var paragraphs = root.querySelectorAll("p").length;
    var headings = root.querySelectorAll("h1, h2, h3").length;
    var longBlocks = Array.prototype.filter.call(root.querySelectorAll("p, li, section, div"), function(node) {
      return normalizeText(node.textContent || "").length >= 120;
    }).length;
    var linkText = Array.prototype.reduce.call(root.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || link.getAttribute("aria-label") || "").length;
    }, 0);
    var linkDensity = text.length > 0 ? linkText / text.length : 0;

    return linkDensity < 0.45 && (paragraphs >= 3 || longBlocks >= 4 || (headings >= 2 && text.length >= 900));
  }

  function medicalArticlePage(metadata, content) {
    if (content && (content.contentType === "interstitial" || content.contentType === "product")) return false;
    if (!substantialMedicalArticleContent(content)) return false;
    if (medicalStructuredDataNode()) return true;
    return healthArticleUrlSignal();
  }

  function applyMedicalContentType(content, metadata) {
    if (!content || content.contentType === "interstitial" || content.contentType === "product") return content;
    if (!medicalWebPageStructuredDataNode()) return content;

    content.contentType = "medical";
    return content;
  }
