
#' Bootstrap an renv Installation
#'
#' Bootstrap an `renv` installation, making the requested version of
#' `renv` available for projects on the system.
#'
#' Normally, this function does not need to be called directly by the user; it
#' will be invoked as required by [init()] and [activate()].
#'
#' @inheritParams renv-params
#'
#' @param version The version of `renv` to install. If `NULL`, the version
#'   of `renv` currently installed will be used. The requested version of
#'   `renv` will be retrieved from the `renv` public GitHub repository,
#'   at <https://github.com/rstudio/renv>.
#'
bootstrap <- function(version = NULL) {
  renv_scope_error_handler()

  vtext <- version %||% renv_package_version("renv")
  vwritef("Bootstrapping renv [%s] ...", vtext)
  status <- renv_bootstrap_impl(version)
  vwritef("* Done! renv has been successfully bootstrapped.")

  invisible(status)

}

renv_bootstrap_impl <- function(version = NULL, force = FALSE) {

  # don't bootstrap during tests unless explicitly requested
  if (renv_testing() && !force)
    return()

  # NULL version means bootstrap this version of renv
  if (is.null(version))
    return(renv_bootstrap_self())

  # otherwise, try to download and install the requested version
  # of renv from GitHub
  remote <- paste("rstudio/renv", version %||% "master", sep = "@")
  record <- renv_remotes_resolve(remote)
  records <- list(renv = record)

  renv_restore_begin(records = records, packages = "renv", recursive = FALSE)
  on.exit(renv_restore_end(), add = TRUE)

  # retrieve renv
  records <- renv_retrieve("renv")
  record <- records[[1]]

  # set library paths temporarily to install into bootstrap library
  library <- renv_paths_bootstrap("renv", record$Version)
  ensure_directory(library)
  renv_scope_libpaths(library)

  vwritef("Installing renv [%s] ...", version)
  status <- with(record, r_cmd_install(Package, Path, library))
  vwritef("\tOK [built source]")

  invisible(status)

}

renv_bootstrap_self <- function() {

  # construct source, target paths
  source <- find.package("renv")
  target <- renv_paths_bootstrap("renv", renv_package_version("renv"), "renv")
  if (renv_file_same(source, target))
    return(TRUE)

  # if we're working with package sources, we'll need to explicitly
  # install the package to the bootstrap directory
  type <- renv_package_type(source, quiet = TRUE)
  switch(type,
         source = renv_bootstrap_self_source(source, target),
         binary = renv_bootstrap_self_binary(source, target))

}

renv_bootstrap_self_source <- function(source, target) {

  # if the package already exists, just skip
  if (file.exists(target))
    return(TRUE)

  # otherwise, install it
  library <- dirname(target)
  ensure_directory(library)
  r_cmd_install("renv", source, library)

}

renv_bootstrap_self_binary <- function(source, target) {
  ensure_parent_directory(target)
  renv_file_copy(source, target, overwrite = TRUE)
}
