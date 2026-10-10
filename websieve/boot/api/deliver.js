  if (typeof deliverExtractApi === "function") {
    deliverExtractApi(fetchUtilExtractApi);
  } else {
    global.FetchUtilExtract = fetchUtilExtractApi;
  }
