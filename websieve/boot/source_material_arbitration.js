  function sourceMaterialBlocksListCandidate(content, candidate, metadata) {
    return listCandidateLosesArticleMaterial(content, candidate) ||
      listCandidateLosesArticleTableMaterial(content, candidate, metadata);
  }

  function productListLosesArticleMaterial(content, candidate, strongArticle, commerceLikePage, metadata) {
    return listCandidateLosesArticleTableMaterial(content, candidate, metadata) ||
      (strongArticle && (!commerceLikePage || listCandidateLosesArticleMaterial(content, candidate)));
  }
