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

  function visibleProductPrice() {
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
      var nodes = document.querySelectorAll(selectors[i]);
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

  function productPageEvidence() {
    var structuredProduct = productPageStructuredData();
    var offer = productOffer(structuredProduct);
    var price = productOfferPrice(offer) || productMetaPrice() || visibleProductPrice();
    var ogType = normalizeText(metadataValue("og:type", "property") || "").toLowerCase();
    var productMarkup = !!document.querySelector("[itemtype*='schema.org/Product' i], [typeof*='Product' i], [itemprop='sku'], [itemprop='gtin'], [itemprop='mpn']");
    var addToCart = !!document.querySelector("button[name*='add' i], button[id*='add-to-cart' i], button[class*='add-to-cart' i], button[data-testid*='add-to-cart' i], [aria-label*='add to cart' i], [aria-label*='add to bag' i]");
    var sku = firstText(["[itemprop='sku']", "[class*='sku' i]", "[data-testid*='sku' i]"]);
    var productOgType = /\bproduct\b/.test(ogType);
    var evidenceCount = [structuredProduct, productOgType, productMarkup, addToCart, sku, price].filter(Boolean).length;

    if (productStructuredDataItems().length > 1 && !productOgType && !addToCart && !sku) return null;
    if (!structuredProduct && !productOgType && !productMarkup && evidenceCount < 2) return null;
    if (!price && !addToCart && !sku && !productMarkup && !structuredProduct) return null;

    return {
      title: commerceEntityText(structuredProduct && structuredProduct.name),
      excerpt: commerceEntityText(structuredProduct && structuredProduct.description),
      price: price,
      availability: commerceEntityText(offer && offer.availability),
      sku: commerceEntityText((structuredProduct && (structuredProduct.sku || structuredProduct.mpn || structuredProduct.gtin13)) || sku)
    };
  }
