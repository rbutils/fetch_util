  function productMetaPrice() {
    return normalizedCommercePrice(
      firstText([
        "meta[property='product:price:amount']",
        "meta[property='og:price:amount']",
        "meta[name='twitter:data1']",
        "meta[itemprop='price']"
      ], "content"),
      firstText([
        "meta[property='product:price:currency']",
        "meta[property='og:price:currency']",
        "meta[itemprop='priceCurrency']"
      ], "content")
    );
  }

  function visibleProductPrice(entity) {
    var selectors = [
      "[itemprop='price']",
      "meta[itemprop='price'][content]",
      "[data-testid*='price' i]",
      "[class*='price' i]",
      "[id*='price' i]",
      "[aria-label*='price' i]"
    ];
    var currency = firstText(["[itemprop='priceCurrency']", "meta[itemprop='priceCurrency'][content]"], "content");

    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = entity.querySelectorAll(selectors[i]);
      for (var n = 0; n < nodes.length; n += 1) {
        var node = nodes[n];
        if (node.closest && node.closest("nav, footer, aside, [hidden], [aria-hidden='true']")) continue;
        var value = node.getAttribute("content") || node.getAttribute("aria-label") || node.textContent;
        var price = normalizedCommercePrice(value, currency);
        if (price) return price;
      }
    }

    return "";
  }

  function productPageStructuredData() {
    return productStructuredDataItems().find(function(product) {
      var offer = productOffer(product);
      return commerceEntityText(product && product.name) || productOfferPrice(offer) || commerceEntityText(product && product.sku);
    }) || null;
  }

  function focalProductEntity(title) {
    var heading = document.querySelector("main h1, article h1, h1");
    if (!heading || !normalizeText(title)) return null;
    if (normalizeText(heading.textContent).toLowerCase() !== normalizeText(title).toLowerCase()) return null;
    return heading.closest("main, article, [itemscope], [data-testid*='product' i], [class*='product-detail' i]") || heading.parentElement;
  }

  function finalProductUrlMatches(product) {
    var value = product && (product.url || product.mainEntityOfPage);
    if (!value) return true;
    try {
      var parsed = new URL(typeof value === "object" ? value.url : value, location.href);
      return parsed.origin === location.origin && parsed.pathname === location.pathname;
    } catch (_error) {
      return false;
    }
  }

  function productRedirectPage() {
    var path = (location.pathname || "").toLowerCase();
    var query = (location.search || "").toLowerCase();
    return /(?:^|[?&])(q|query|search|searchtext|keyword|k|d)=/.test(query) ||
      /\/(search|s|browse|category|categories|collections?|catalog|keyword|wholesale|shop)\b/.test(path) ||
      /\/p\/pl\b/.test(path);
  }

  function productPageEvidence() {
    var structuredProduct = productPageStructuredData();
    var offer = productOffer(structuredProduct);
    var structuredName = commerceEntityText(structuredProduct && structuredProduct.name);
    var focalEntity = focalProductEntity(structuredName || firstText(["main h1", "article h1", "h1"]));
    if (productRedirectPage() || !focalEntity || (structuredProduct && !finalProductUrlMatches(structuredProduct))) return null;

    var price = productOfferPrice(offer) || productMetaPrice() || visibleProductPrice(focalEntity);
    var ogType = normalizeText(metadataValue("og:type", "property") || "").toLowerCase();
    var productMarkup = !!focalEntity.querySelector("[itemtype*='schema.org/Product' i], [typeof*='Product' i], [itemprop='sku'], [itemprop='gtin'], [itemprop='mpn']");
    var addToCart = !!focalEntity.querySelector("button[name*='add' i], button[id*='add-to-cart' i], button[class*='add-to-cart' i], button[data-testid*='add-to-cart' i], [aria-label*='add to cart' i], [aria-label*='add to bag' i]");
    var sku = firstTextFromNode(focalEntity, ["[itemprop='sku']", "[class*='sku' i]", "[data-testid*='sku' i]"]);
    var productOgType = /\bproduct\b/.test(ogType);
    var focalTitle = firstText(["main h1", "article h1", "h1", "[itemprop='name']"]);
    var focalImage = !!focalEntity.querySelector("img[alt], [itemprop='image']");
    structuredName = structuredName.toLowerCase();
    var structuredSku = commerceEntityText(structuredProduct && (structuredProduct.sku || structuredProduct.mpn || structuredProduct.gtin13));
    var focalName = normalizeText(focalTitle || "").toLowerCase();
    var structuredIdentity = !!structuredProduct && !!focalName && (structuredName === focalName || structuredName.indexOf(focalName) !== -1 || focalName.indexOf(structuredName) !== -1);
    var visibleIdentity = !!focalTitle && (productMarkup || addToCart || sku) &&
      !!focalEntity.querySelector("[itemtype*='schema.org/Product' i], [typeof*='Product' i], [itemprop='sku'], [itemprop='gtin'], [itemprop='mpn'], button[name*='add' i], button[id*='add-to-cart' i], button[class*='add-to-cart' i], button[data-testid*='add-to-cart' i], [aria-label*='add to cart' i], [aria-label*='add to bag' i], [class*='sku' i], [data-testid*='sku' i]");
    var focalIdentity = structuredIdentity || visibleIdentity;
    var detailEvidence = [offer, sku || structuredSku, addToCart, focalImage].filter(Boolean).length;

    if (productStructuredDataItems().length > 1 && !productOgType && !addToCart && !sku) return null;
    if (!focalIdentity || detailEvidence < 2) return null;
    return {
      title: commerceEntityText(structuredProduct && structuredProduct.name),
      excerpt: commerceEntityText(structuredProduct && structuredProduct.description),
      price: price,
      availability: commerceEntityText(offer && offer.availability),
      sku: commerceEntityText((structuredProduct && (structuredProduct.sku || structuredProduct.mpn || structuredProduct.gtin13)) || sku)
    };
  }
