  function docsSystemInfo(metadata) {
    var signatureInfo = platformSignature(metadata, [function(_metadata, generator, appName) {
      return [docsHostSignature(metadata), generator, appName].join(" ");
    }]);
    var generator = signatureInfo.generator.toLowerCase();
    var appName = signatureInfo.appName.toLowerCase();
    var signature = signatureInfo.signature.toLowerCase();

    signatureInfo = { generator: generator, appName: appName, signature: signature };

    if (document.querySelector("[class*='stldocs-']")) return docsSystemResult("stldocs", signatureInfo);
    if (/astro/.test(generator) && (document.querySelector("#starlight__sidebar, starlight-menu-button, [class*='sl-markdown-content']") || /starlight/.test(signature))) {
      return docsSystemResult("starlight", signatureInfo);
    }
    if (/mkdocs/.test(generator) || (document.querySelector(".md-content") && document.querySelector(".md-sidebar, .md-header, .md-nav"))) {
      return docsSystemResult("mkdocs", signatureInfo);
    }
    if (document.querySelector("meta[name='readme-deploy']") || document.querySelector(".rm-Article, .rm-LandingPage, .rm-ReferenceMain") || /\.readme\.(io|com)$/.test(location.hostname)) {
      return docsSystemResult("readme", signatureInfo);
    }
    if (document.querySelector("redoc, rapi-doc") || /redoc/i.test(generator) || document.querySelector(".redoc-wrap, .api-content[role='main']")) {
      return docsSystemResult("redoc", signatureInfo);
    }
    if (/buildwithfern|fern/.test(generator) || document.querySelector("#fern-sidebar, .fern-page-heading, .fern-prose, .fern-layout-reference, .fern-layout-overview")) {
      return docsSystemResult("fern", signatureInfo);
    }
    if (/nextra/.test(signature) || document.querySelector(".nextra-content, .nextra-breadcrumb, #nextra-skip-nav, .nextra-nav-container")) {
      return docsSystemResult("nextra", signatureInfo);
    }
    if (/\bnext(?:\.js|js)?\b/.test(signature) && document.querySelector("#__next, script#__NEXT_DATA__") && document.querySelector("main article, main .prose, main [data-docs-body], main [data-pagefind-body]")) {
      return docsSystemResult("next", signatureInfo);
    }
    if (/vitepress/.test(generator) || document.querySelector("#VPContent, .VPDoc, .VPSidebar, .VPNav")) {
      return docsSystemResult("vitepress", signatureInfo);
    }
    if (/rspress/.test(generator) || document.querySelector("#__rspress_root, .rspress-doc, .rp-sidebar, .rp-nav")) {
      return docsSystemResult("rspress", signatureInfo);
    }
    if (/mdbook/i.test(generator) || document.querySelector("#sidebar.sidebar, #menu-bar-hover-placeholder, nav.sidebar, #sidebar-toggle")) {
      return docsSystemResult("mdbook", signatureInfo);
    }
    if (/antora/.test(generator) || document.querySelector("article.doc, main.main article.doc, .doc .homecards")) {
      return docsSystemResult("antora", signatureInfo);
    }
    if (/mintlify/.test(generator) || document.querySelector("[class*='mintlify'], [data-testid='table-of-contents'], nav[aria-label='Table of contents']")) {
      return docsSystemResult("mintlify", signatureInfo);
    }
    if (/gitbook/i.test(generator) || /\.gitbook\.io$/.test(location.hostname) || (document.querySelector("main [class*='whitespace-pre-wrap']") && /powered by gitbook/i.test(document.body.innerText))) {
      return docsSystemResult("gitbook", signatureInfo);
    }
    if (document.querySelector(".scalar-api-reference, .scalar-app, [data-scalar]")) {
      return docsSystemResult("scalar", signatureInfo);
    }
    if (/docusaurus/.test(generator) || document.querySelector("meta[name='generator'][content^='Docusaurus'], #__docusaurus, [class*='docusaurus-'], .theme-doc-markdown, .theme-doc-sidebar-container, nav[aria-label='Docs sidebar']")) {
      return docsSystemResult("docusaurus", signatureInfo);
    }
    if (/^(doc\.rust-lang\.org|docs\.rs)$/.test(location.hostname) || document.querySelector(".rustdoc, .sidebar-elems, #crate-search")) {
      return docsSystemResult("rustdoc", signatureInfo);
    }
    var javadocContent = document.querySelector("main .class-description, .contentContainer .description");
    var javadocStructure = document.querySelector("main .summary-table, main .member-summary, main .member-details, .contentContainer .summary-table, .contentContainer .details");
    if (javadocContent && javadocStructure) {
      return docsSystemResult("javadoc", signatureInfo);
    }
    if (document.querySelector("#dartdoc-main-content, .self-name") && document.querySelector("section.summary dt .name a, section.summary dt a")) {
      return docsSystemResult("dartdoc", signatureInfo);
    }
    if (/^pkg\.go\.dev$/.test(location.hostname) || document.querySelector("#main-content .Documentation, #main-content #pkg-index, .go-DetailsHeader")) {
      return docsSystemResult("go_pkg", signatureInfo);
    }
    if (/readthedocs/.test(signature) || document.querySelector(".rst-content, .wy-nav-content, .wy-nav-side")) {
      return docsSystemResult("readthedocs", signatureInfo);
    }
    if (/sphinx/.test(generator) || document.querySelector("body[class*='sphinx'], .document, .sphinxsidebar, [role='navigation'] .sphinxsidebarwrapper, div.body[role='main'], dt.sig, a.headerlink, div.highlight")) {
      return docsSystemResult("sphinx", signatureInfo);
    }
    if (document.querySelector("devsite-header, devsite-content, devsite-toc, devsite-nav") || /devsite/.test(signature)) {
      return docsSystemResult("google_devsite", signatureInfo);
    }
    if (document.querySelector("[class*='elastic-docs'], [data-elastic-docs]") || (/elastic/i.test(signature) && document.querySelector("[class*='docBody'], article[class*='doc']"))) {
      return docsSystemResult("elastic_docs", signatureInfo);
    }
    if (document.querySelector("main .markdown-body, main article, main [data-pagefind-body], main .prose")) {
      return docsSystemResult("generic_docs", signatureInfo);
    }

    return null;
  }

  function docsSystemResult(system, signatureInfo) {
    return {
      system: system,
      generator: signatureInfo.generator,
      appName: signatureInfo.appName,
      signature: signatureInfo.signature
    };
  }
