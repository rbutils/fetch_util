  function sourceMaterialBlocksListCandidate(content, candidate, metadata) {
    return sourceOwnedTypedRuntimeDetailListLoss(content, candidate) ||
      listCandidateLosesArticleMaterial(content, candidate) ||
      listCandidateLosesArticleTableMaterial(content, candidate, metadata);
  }

  function productListLosesArticleMaterial(content, candidate, strongArticle, commerceLikePage, metadata) {
    return listCandidateLosesArticleTableMaterial(content, candidate, metadata) ||
      (strongArticle && (!commerceLikePage || listCandidateLosesArticleMaterial(content, candidate)));
  }
