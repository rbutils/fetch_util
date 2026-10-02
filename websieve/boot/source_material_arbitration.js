  function sourceMaterialBlocksListCandidate(content, candidate) {
    return listCandidateLosesArticleMaterial(content, candidate) ||
      listCandidateLosesArticleTableMaterial(content, candidate);
  }

  function productListLosesArticleMaterial(content, candidate, strongArticle, commerceLikePage) {
    return listCandidateLosesArticleTableMaterial(content, candidate) ||
      (strongArticle && (!commerceLikePage || listCandidateLosesArticleMaterial(content, candidate)));
  }
