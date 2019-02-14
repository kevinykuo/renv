
renv_remotes_read <- function(remotes = NULL) {
  remotes <- remotes %||% renv_remotes_path()
  contents <- readLines(remotes, warn = FALSE)
  parsed <- lapply(contents, renv_remotes_parse)
  names(parsed) <- map_chr(parsed, `[[`, "Package")
  parsed
}

renv_remotes_parse <- function(entry) {

  # check for pre-supplied type
  type <- NULL
  parts <- strsplit(entry, "::", fixed = TRUE)[[1]]
  if (length(parts) == 2) {
    type <- parts[[1]]
    entry <- parts[[2]]
  }

  # if we don't have at type, infer from entry (can be either CRAN or GitHub)
  type <- type %||% if (grepl("/", entry)) "github" else "cran"

  # generate entry from type
  switch(type,
    cran   = renv_remotes_parse_cran(entry),
    github = renv_remotes_parse_github(entry),
    stopf("unhandled type '%s'", type %||% "unknown")
  )

}

renv_remotes_parse_cran <- function(entry) {
  parts <- strsplit(entry, "@", fixed = TRUE)[[1]]
  list(Package = parts[[1]], Version = parts[[2]], Source = "CRAN")
}

renv_remotes_parse_github <- function(entry) {
  parts <- strsplit(entry, "[@/]")[[1]]
  list(
    Package        = parts[[2]],
    Source         = "GitHub",
    RemoteUsername = parts[[1]],
    RemoteRepo     = parts[[2]],
    RemoteSha      = parts[[3]]
  )
}

renv_remotes_snapshot <- function(project = NULL, libpaths = NULL) {

  # resolve variables
  project <- project %||% renv_state$project()
  libpaths <- libpaths %||% renv_remotes_libpaths()

  # serialize DESCRIPTIONs for installed packages
  entries <- uapply(libpaths, function(libpath) {
    packages <- list.files(libpath, full.names = TRUE)
    descriptions <- file.path(packages, "DESCRIPTION")
    map_chr(descriptions, renv_remotes_serialize)
  })

  # write to remotes.txt
  writeLines(entries, con = renv_remotes_path())

}

renv_remotes_path <- function(project = NULL) {
  project <- project %||% renv_state$project()
  file.path(project, "remotes.txt")
}

renv_remotes_libpaths <- function(libpaths = NULL) {
  setdiff(renv_libpaths_all(), normalizePath(.Library, winslash = "/"))
}

renv_remotes_serialize <- function(description) {

  if (!file.exists(description))
    return(NULL)

  if (is.character(description))
    description <- renv_description_read(description)

  # infer the remote type
  type <- tolower(description$RemoteType) %||% ""
  switch(type,
    cran     = renv_remotes_serialize_cran(description),
    github   = renv_remotes_serialize_github(description),
    standard = renv_remotes_serialize_standard(description),
    url      = renv_remotes_serialize_url(description),
    renv_remotes_serialize_unknown(description, type)
  )

}

renv_remotes_serialize_cran <- function(description) {
  with(description, {
    sprintf("%s@%s", Package, Version)
  })
}

renv_remotes_serialize_github <- function(description) {
  with(description, {
    sprintf("%s/%s@%s", RemoteUsername, RemoteRepo, RemoteSha)
  })
}

renv_remotes_serialize_standard <- function(description) {
  with(description, {
    sprintf("%s@%s", Package, Version)
  })
}

renv_remotes_serialize_url <- function(description) {
  with(description, {
    sprintf("%s", RemoteUrl)
  })
}

renv_remotes_serialize_unknown <- function(description, type) {

  # if we have a repository field, assume CRAN
  if (!is.null(description$Repository))
    return(renv_remotes_serialize_cran(description))

  # otherwise, write as unknown
  with(description, {
    sprintf("%s@%s", Package, Version)
  })

}