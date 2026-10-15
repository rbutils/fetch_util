  if (typeof deliverExtractApi === "function") {
    fetchUtilExtractApi.prepareOwnedWork = withComposedDomRead(prepareOwnedExtractionWork);
    deliverExtractApi(fetchUtilExtractApi);
  } else {
    global.FetchUtilExtract = fetchUtilExtractApi;
  }
