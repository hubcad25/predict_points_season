#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg="") {
  list(msg = paste0("The message is: '", msg, "'"))
}

#* Get wd
#* @get /wd
function() {
  getwd()
}

#* List models
#* @get /models
function() {
  models <- list.files("models")
  return(models)
}

#* Retrieve a model
#* @get /model
function(model) {
  object <- readRDS(paste0("models/", model, ".rds"))
  call <- object$call
  return(as.character(call))
}