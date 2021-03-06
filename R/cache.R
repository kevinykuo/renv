
# tools for interacting with the renv global package cache
renv_cache_version <- function() {
  "v4"
}

renv_cache_package_path <- function(record) {

  # validate required fields -- if any are missing, we can't use the cache
  required <- c("Package", "Version")
  missing <- renv_vector_diff(required, names(record))
  if (length(missing))
    return("")

  # if we have a hash, use it directly
  if (!is.null(record$Hash)) {
    path <- with(record, renv_paths_cache(Package, Version, Hash, Package))
    return(path)
  }

  # figure out the R version to be used when constructing
  # the cache package path
  built <- record$Built
  version <- if (is.null(built))
    getRversion()
  else
    substring(built, 3, regexpr(";", built, fixed = TRUE) - 1L)

  # if the record doesn't have a hash, check to see if we can still locate a
  # compatible package version within the cache
  root <- with(record, renv_paths_cache(Package, Version, version = version))
  hashes <- list.files(root, full.names = TRUE)
  packages <- list.files(hashes, full.names = TRUE)

  # iterate over package paths, read DESCRIPTION, and look
  # for something compatible with the requested record
  for (package in packages) {

    dcf <- catch(as.list(renv_description_read(package)))
    if (inherits(dcf, "error"))
      next

    # if we're requesting an install from CRAN,
    # and the cached package has a "Repository" field,
    # then use it
    cran <-
      identical(record$Source, "CRAN") &&
      "Repository" %in% names(dcf)

    if (cran)
      return(package)

    # otherwise, match on other fields
    fields <- renv_record_names(record, c("Package", "Version"))

    # drop unnamed fields
    record <- record[nzchar(record)]; dcf <- dcf[nzchar(dcf)]

    # check identical
    if (identical(record[fields], dcf[fields]))
      return(package)

  }

  # failed; return "" as proxy for missing file
  ""

}

renv_cache_synchronize <- function(record, linkable = FALSE) {

  # construct path to package in library
  library <- renv_libpaths_default()
  path <- file.path(library, record$Package)
  if (!file.exists(path))
    return(FALSE)

  # bail if the package source is unknown (assume that packages with an
  # unknown source are not cacheable)
  desc <- renv_description_read(path)
  source <- renv_snapshot_description_source(desc)
  if (identical(source, "unknown"))
    return(FALSE)

  # bail if record not cacheable
  if (!renv_record_cacheable(record))
    return(FALSE)

  # if we don't have a hash, compute it now
  record$Hash <- record$Hash %||% renv_hash_description(path)

  # construct cache entry
  cache <- renv_cache_package_path(record)
  if (!nzchar(cache))
    return(FALSE)

  # if our cache -> path link is already up to date, then nothing to do
  if (renv_file_same(cache, path))
    return(TRUE)

  # if we already have a cache entry, back it up
  callback <- renv_file_backup(cache)
  on.exit(callback(), add = TRUE)

  # copy into cache and link back into requested directory
  ensure_parent_directory(cache)
  if (linkable) {
    renv_file_move(path, cache)
    renv_file_link(cache, path, overwrite = TRUE)
  } else {
    vprintf("* Copying '%s' into the cache ... ", record$Package)
    renv_file_copy(path, cache)
    vwritef("Done!")
  }

  TRUE

}

renv_cache_list <- function(packages = NULL) {
  cache <- renv_paths_cache()
  names <- file.path(cache, packages %||% list.files(cache))
  versions <- list.files(names, full.names = TRUE)
  hashes <- list.files(versions, full.names = TRUE)
  paths <- list.files(hashes, full.names = TRUE)
  paths
}

renv_cache_diagnose_missing_descriptions <- function(paths, problems, verbose) {

  descpaths <- file.path(paths, "DESCRIPTION")
  info <- file.info(descpaths, extra_cols = FALSE)
  missing <- is.na(info$isdir)
  bad <- rownames(info)[missing]
  if (empty(bad))
    return(paths)

  # nocov start
  if (verbose) {
    renv_pretty_print(
      renv_cache_format_path(dirname(bad)),
      "The following packages are missing DESCRIPTION files in the cache:",
      "These packages should be purged and re-installed.",
      wrap = FALSE
    )
  }
  # nocov end

  path    <- dirname(bad)
  package <- path_component(bad, 1)
  version <- path_component(bad, 3)

  data <- data.frame(
    Package = package,
    Version = version,
    Path    = path,
    Reason  = "missing",
    stringsAsFactors = FALSE
  )

  problems$push(data)
  paths[!missing]

}

renv_cache_diagnose_bad_hash <- function(paths, problems, verbose) {

  hash <- path_component(paths, 2)
  computed <- map_chr(paths, renv_hash_description)
  diff <- hash != computed

  bad <- names(computed)[diff]
  if (empty(bad))
    return(paths)

  package <- path_component(bad, 1)
  version <- path_component(bad, 3)

  # nocov start
  if (verbose) {

    fmt <- "%s %s [Hash: %s != %s]"
    entries <- sprintf(
      fmt,
      format(package),
      format(version),
      format(hash[diff]),
      format(computed[diff])
    )

    renv_pretty_print(
      entries,
      "The following packages have incorrect hashes:",
      "These packages should be purged and re-installed.",
      wrap = FALSE
    )
  }
  # nocov end

  data <- data.frame(
    Package = package,
    Version = version,
    Path    = dirname(bad),
    Reason  = "badhash",
    stringsAsFactors = FALSE
  )

  problems$push(data)
  paths

}

renv_cache_diagnose <- function(verbose = NULL) {

  verbose <- verbose %||% renv_verbose()

  problems <- stack()
  paths <- renv_cache_list()
  paths <- renv_cache_diagnose_missing_descriptions(paths, problems, verbose)
  paths <- renv_cache_diagnose_bad_hash(paths, problems, verbose)

  invisible(bind_list(problems$data()))

}

renv_cache_move <- function(source, target, overwrite = FALSE) {
  file.exists(source) || renv_file_move(target, source)
  renv_file_link(source, target, overwrite = TRUE)
}

# nocov start
renv_cache_format_path <- function(paths) {

  names    <- format(path_component(paths, 1))
  hashes   <- format(path_component(paths, 2))
  versions <- format(path_component(paths, 3))

  fmt <- "%s %s [Hash: %s]"
  sprintf(fmt, names, versions, hashes)

}
# nocov end

renv_cache_clean_empty <- function() {

  # move to cache root
  root <- renv_paths_cache()
  owd <- setwd(root)
  on.exit(setwd(owd), add = TRUE)

  # try using find utility
  command <- case(
    nzchar(Sys.which("find"))     ~ "find . -type d -empty -delete",
    nzchar(Sys.which("robocopy")) ~ "robocopy . . /S /MOVE"
  )

  if (is.null(command))
    return(FALSE)

  system(command, ignore.stdout = TRUE, ignore.stderr = TRUE)
  TRUE

}
