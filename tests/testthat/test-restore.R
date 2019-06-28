
context("Restore")

test_that("library permissions are validated before restore", {
  skip_on_os("windows")
  inaccessible <- renv_tempfile()
  dir.create(inaccessible, mode = "0100")
  renv_scope_options(renv.verbose = FALSE)
  expect_false(renv_restore_preflight_permissions(inaccessible))
})

test_that("we can restore packages after init", {

  renv_tests_scope("breakfast")

  renv::init()

  libpath <- renv_paths_library()
  before <- list.files(libpath)

  unlink(renv_paths_library(), recursive = TRUE)
  renv::restore()

  after <- list.files(libpath)
  expect_setequal(before, after)

})