
context("Preflight")

test_that("snapshot preflight tests catch common issues", {

  renv_tests_scope()

  libpath <- renv_paths_library()
  ensure_parent_directory(libpath)

  # library is a file, not directory
  file.create(libpath)
  expect_error(renv::snapshot(library = libpath))
  unlink(libpath)

  # project library does not exist
  expect_error(renv::snapshot(library = libpath))

  # arbitrary library does not exist
  expect_error(renv::snapshot(library = tempfile()))

})

test_that("renv warns when snapshotting missing dependencies", {

  renv_tests_scope("breakfast")
  renv::init()

  remove.packages("oatmeal")

  output <- tempfile("renv-output-")
  lockfile <- tempfile("renv-lockfile-")
  local({
    renv_scope_sink(output)
    renv::snapshot(lockfile = lockfile, confirm = FALSE)
  })

  contents <- readLines(output)
  expect_true(length(contents) > 1)

})
