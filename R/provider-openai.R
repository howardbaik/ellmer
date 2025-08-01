#' @include provider.R
#' @include content.R
#' @include turns.R
#' @include tools-def.R
NULL

#' Chat with an OpenAI model
#'
#' @description
#' [OpenAI](https://openai.com/) provides a number of chat-based models,
#' mostly under the [ChatGPT](https://chat.openai.com/) brand.
#' Note that a ChatGPT Plus membership does not grant access to the API.
#' You will need to sign up for a developer account (and pay for it) at the
#' [developer platform](https://platform.openai.com).
#'
#' @param system_prompt A system prompt to set the behavior of the assistant.
#' @param base_url The base URL to the endpoint; the default uses OpenAI.
#' @param api_key `r api_key_param("OPENAI_API_KEY")`
#' @param model `r param_model("gpt-4.1", "openai")`
#' @param params Common model parameters, usually created by [params()].
#' @param seed Optional integer seed that ChatGPT uses to try and make output
#'   more reproducible.
#' @param api_args Named list of arbitrary extra arguments appended to the body
#'   of every chat API call. Combined with the body object generated by ellmer
#'   with [modifyList()].
#' @param api_headers Named character vector of arbitrary extra headers appended
#'   to every chat API call.
#' @param echo One of the following options:
#'   * `none`: don't emit any output (default when running in a function).
#'   * `output`: echo text and tool-calling output as it streams in (default
#'     when running at the console).
#'   * `all`: echo all input and output.
#'
#'   Note this only affects the `chat()` method.
#' @family chatbots
#' @export
#' @returns A [Chat] object.
#' @examples
#' \dontshow{ellmer:::vcr_example_start("chat_openai")}
#' chat <- chat_openai()
#' chat$chat("
#'   What is the difference between a tibble and a data frame?
#'   Answer with a bulleted list
#' ")
#'
#' chat$chat("Tell me three funny jokes about statisticians")
#' \dontshow{ellmer:::vcr_example_end()}
chat_openai <- function(
  system_prompt = NULL,
  base_url = "https://api.openai.com/v1",
  api_key = openai_key(),
  model = NULL,
  params = NULL,
  seed = lifecycle::deprecated(),
  api_args = list(),
  api_headers = character(),
  echo = c("none", "output", "all")
) {
  model <- set_default(model, "gpt-4.1")
  echo <- check_echo(echo)

  params <- params %||% params()
  if (lifecycle::is_present(seed) && !is.null(seed)) {
    lifecycle::deprecate_warn(
      when = "0.2.0",
      what = "chat_openai(seed)",
      with = "chat_openai(params)"
    )
    params$seed <- seed
  }

  provider <- ProviderOpenAI(
    name = "OpenAI",
    base_url = base_url,
    model = model,
    params = params,
    extra_args = api_args,
    extra_headers = api_headers,
    api_key = api_key
  )
  Chat$new(provider = provider, system_prompt = system_prompt, echo = echo)
}
chat_openai_test <- function(
  system_prompt = "Be terse.",
  ...,
  model = "gpt-4.1-nano",
  params = NULL,
  echo = "none"
) {
  params <- params %||% params()
  params$seed <- params$seed %||% 1014
  params$temperature <- params$temperature %||% 0

  chat_openai(
    system_prompt = system_prompt,
    model = model,
    params = params,
    ...,
    echo = echo
  )
}

ProviderOpenAI <- new_class(
  "ProviderOpenAI",
  parent = Provider,
  properties = list(
    prop_redacted("api_key"),
    # no longer used by OpenAI itself; but subclasses still need it
    seed = prop_number_whole(allow_null = TRUE)
  )
)

openai_key_exists <- function() {
  key_exists("OPENAI_API_KEY")
}

openai_key <- function() {
  key_get("OPENAI_API_KEY")
}

# Base request -----------------------------------------------------------------

method(base_request, ProviderOpenAI) <- function(provider) {
  req <- request(provider@base_url)
  req <- req_auth_bearer_token(req, provider@api_key)
  req <- ellmer_req_robustify(req)
  req <- ellmer_req_user_agent(req)
  req <- base_request_error(provider, req)
  req
}

method(base_request_error, ProviderOpenAI) <- function(provider, req) {
  req_error(req, body = function(resp) {
    if (resp_content_type(resp) == "application/json") {
      error <- resp_body_json(resp)$error
      if (is_string(error)) {
        error
      } else if (is.list(error)) {
        error$message
      } else {
        prettify(resp_body_string(resp))
      }
    } else if (resp_content_type(resp) == "text/plain") {
      resp_body_string(resp)
    }
  })
}

# Chat endpoint ----------------------------------------------------------------

method(chat_path, ProviderOpenAI) <- function(provider) {
  "/chat/completions"
}

# https://platform.openai.com/docs/api-reference/chat/create
method(chat_body, ProviderOpenAI) <- function(
  provider,
  stream = TRUE,
  turns = list(),
  tools = list(),
  type = NULL
) {
  messages <- compact(unlist(as_json(provider, turns), recursive = FALSE))
  tools <- as_json(provider, unname(tools))

  if (!is.null(type)) {
    response_format <- list(
      type = "json_schema",
      json_schema = list(
        name = "structured_data",
        schema = as_json(provider, type),
        strict = TRUE
      )
    )
  } else {
    response_format <- NULL
  }

  params <- chat_params(provider, provider@params)
  params$seed <- params$seed %||% provider@seed

  compact(list2(
    messages = messages,
    model = provider@model,
    !!!params,
    stream = stream,
    stream_options = if (stream) list(include_usage = TRUE),
    tools = tools,
    response_format = response_format
  ))
}


method(chat_params, ProviderOpenAI) <- function(provider, params) {
  standardise_params(
    params,
    c(
      temperature = "temperature",
      top_p = "top_p",
      frequency_penalty = "frequency_penalty",
      presence_penalty = "presence_penalty",
      seed = "seed",
      max_tokens = "max_completion_tokens",
      logprobs = "log_probs",
      stop = "stop_sequences"
    )
  )
}

# OpenAI -> ellmer --------------------------------------------------------------

method(stream_parse, ProviderOpenAI) <- function(provider, event) {
  if (is.null(event) || identical(event$data, "[DONE]")) {
    return(NULL)
  }

  jsonlite::parse_json(event$data)
}
method(stream_text, ProviderOpenAI) <- function(provider, event) {
  if (length(event$choices) == 0) {
    NULL
  } else {
    event$choices[[1]]$delta[["content"]]
  }
}
method(stream_merge_chunks, ProviderOpenAI) <- function(
  provider,
  result,
  chunk
) {
  if (is.null(result)) {
    chunk
  } else {
    merge_dicts(result, chunk)
  }
}
method(value_turn, ProviderOpenAI) <- function(
  provider,
  result,
  has_type = FALSE
) {
  if (has_name(result$choices[[1]], "delta")) {
    # streaming
    message <- result$choices[[1]]$delta
  } else {
    message <- result$choices[[1]]$message
  }

  if (has_type) {
    if (is_string(message$content)) {
      json <- jsonlite::parse_json(message$content[[1]])
    } else {
      json <- message$content
    }
    content <- list(ContentJson(json))
  } else {
    content <- lapply(message$content, as_content)
  }
  if (has_name(message, "tool_calls")) {
    calls <- lapply(message$tool_calls, function(call) {
      name <- call$`function`$name
      # TODO: record parsing error
      args <- tryCatch(
        jsonlite::parse_json(call$`function`$arguments),
        error = function(cnd) list()
      )
      ContentToolRequest(name = name, arguments = args, id = call$id)
    })
    content <- c(content, calls)
  }

  cached_tokens <- result$usage$prompt_tokens_details$cached_tokens %||% 0
  tokens <- tokens_log(
    provider,
    input = result$usage$prompt_tokens - cached_tokens,
    output = result$usage$completion_tokens,
    cached_input = cached_tokens
  )
  assistant_turn(
    content,
    json = result,
    tokens = tokens
  )
}

# ellmer -> OpenAI --------------------------------------------------------------

method(as_json, list(ProviderOpenAI, Turn)) <- function(provider, x) {
  if (x@role == "system") {
    list(
      list(role = "system", content = x@contents[[1]]@text)
    )
  } else if (x@role == "user") {
    # Each tool result needs to go in its own message with role "tool"
    is_tool <- map_lgl(x@contents, S7_inherits, ContentToolResult)
    content <- as_json(provider, x@contents[!is_tool])
    if (length(content) > 0) {
      user <- list(list(role = "user", content = content))
    } else {
      user <- list()
    }

    tools <- lapply(x@contents[is_tool], function(tool) {
      list(
        role = "tool",
        content = tool_string(tool),
        tool_call_id = tool@request@id
      )
    })

    c(user, tools)
  } else if (x@role == "assistant") {
    # Tool requests come out of content and go into own argument
    is_tool <- map_lgl(x@contents, is_tool_request)
    content <- as_json(provider, x@contents[!is_tool])
    tool_calls <- as_json(provider, x@contents[is_tool])

    list(
      compact(list(
        role = "assistant",
        content = content,
        tool_calls = tool_calls
      ))
    )
  } else {
    cli::cli_abort("Unknown role {x@role}", .internal = TRUE)
  }
}

method(as_json, list(ProviderOpenAI, ContentText)) <- function(provider, x) {
  list(type = "text", text = x@text)
}

method(as_json, list(ProviderOpenAI, ContentImageRemote)) <- function(
  provider,
  x
) {
  list(type = "image_url", image_url = list(url = x@url))
}

method(as_json, list(ProviderOpenAI, ContentImageInline)) <- function(
  provider,
  x
) {
  list(
    type = "image_url",
    image_url = list(
      url = paste0("data:", x@type, ";base64,", x@data)
    )
  )
}

method(as_json, list(ProviderOpenAI, ContentPDF)) <- function(
  provider,
  x
) {
  list(
    type = "file",
    file = list(
      filename = x@filename,
      file_data = paste0("data:application/pdf;base64,", x@data)
    )
  )
}

method(as_json, list(ProviderOpenAI, ContentToolRequest)) <- function(
  provider,
  x
) {
  json_args <- jsonlite::toJSON(x@arguments)
  list(
    id = x@id,
    `function` = list(name = x@name, arguments = json_args),
    type = "function"
  )
}

method(as_json, list(ProviderOpenAI, ToolDef)) <- function(provider, x) {
  list(
    type = "function",
    "function" = compact(list(
      name = x@name,
      description = x@description,
      strict = TRUE,
      parameters = as_json(provider, x@arguments)
    ))
  )
}


method(as_json, list(ProviderOpenAI, TypeObject)) <- function(provider, x) {
  if (x@additional_properties) {
    cli::cli_abort("{.arg .additional_properties} not supported for OpenAI.")
  }

  names <- names2(x@properties)
  properties <- lapply(x@properties, function(x) {
    out <- as_json(provider, x)
    if (!x@required) {
      out$type <- c(out$type, "null")
    }
    out
  })

  names(properties) <- names

  list(
    type = "object",
    description = x@description %||% "",
    properties = properties,
    required = as.list(names),
    additionalProperties = FALSE
  )
}


# Batched requests -------------------------------------------------------------

method(has_batch_support, ProviderOpenAI) <- function(provider) {
  # Only enable for OpenAI, not subclasses
  provider@name == "OpenAI"
}

# https://platform.openai.com/docs/api-reference/batch
method(batch_submit, ProviderOpenAI) <- function(
  provider,
  conversations,
  type = NULL
) {
  path <- withr::local_tempfile()

  # First put the requests in a file
  # https://platform.openai.com/docs/api-reference/batch/request-input
  requests <- map(seq_along(conversations), function(i) {
    body <- chat_body(
      provider,
      stream = FALSE,
      turns = conversations[[i]],
      type = type
    )

    list(
      custom_id = paste0("chat-", i),
      method = "POST",
      url = "/v1/chat/completions",
      body = body
    )
  })
  json <- map_chr(requests, jsonlite::toJSON, auto_unbox = TRUE)
  writeLines(json, path)
  # Then upload it
  uploaded <- openai_upload(provider, path)

  # Now we can submit the
  req <- base_request(provider)
  req <- req_url_path_append(req, "/batches")
  req <- req_body_json(
    req,
    list(
      input_file_id = uploaded$id,
      endpoint = "/v1/chat/completions",
      completion_window = "24h"
    )
  )

  resp <- req_perform(req)
  resp_body_json(resp)
}

# https://platform.openai.com/docs/api-reference/batch/retrieve
openai_upload <- function(provider, path, purpose = "batch") {
  req <- base_request(provider)
  req <- req_url_path_append(req, "/files")
  req <- req_body_multipart(
    req,
    purpose = purpose,
    file = curl::form_file(path)
  )
  req <- req_progress(req, "up")

  resp <- req_perform(req)
  resp_body_json(resp)
}

# https://docs.anthropic.com/en/api/retrieving-message-batches
method(batch_poll, ProviderOpenAI) <- function(provider, batch) {
  req <- base_request(provider)
  req <- req_url_path_append(req, "/batches/", batch$id)

  resp <- req_perform(req)
  resp_body_json(resp)
}
method(batch_status, ProviderOpenAI) <- function(provider, batch) {
  list(
    working = batch$status != "completed",
    n_processing = batch$request_counts$total - batch$request_counts$completed,
    n_succeeded = batch$request_counts$completed,
    n_failed = batch$request_counts$failed
  )
}


# https://docs.anthropic.com/en/api/retrieving-message-batch-results
method(batch_retrieve, ProviderOpenAI) <- function(provider, batch) {
  path <- withr::local_tempfile()

  req <- base_request(provider)
  req <- req_url_path_append(req, "/files/", batch$output_file_id, "/content")
  req <- req_progress(req, "down")
  resp <- req_perform(req, path = path)

  lines <- readLines(path, warn = FALSE)
  json <- lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)

  ids <- as.numeric(gsub("chat-", "", map_chr(json, "[[", "custom_id")))
  results <- lapply(json, "[[", "response")
  results[order(ids)]
}

method(batch_result_turn, ProviderOpenAI) <- function(
  provider,
  result,
  has_type = FALSE
) {
  if (result$status_code == 200) {
    value_turn(provider, result$body, has_type = has_type)
  } else {
    NULL
  }
}

# Models -----------------------------------------------------------------------

#' @rdname chat_openai
#' @export
models_openai <- function(
  base_url = "https://api.openai.com/v1",
  api_key = openai_key()
) {
  provider <- ProviderOpenAI(
    name = "OpenAI",
    model = "",
    base_url = base_url,
    api_key = api_key
  )

  req <- base_request(provider)
  req <- req_url_path_append(req, "/models")
  resp <- req_perform(req)

  json <- resp_body_json(resp)

  id <- map_chr(json$data, "[[", "id")
  created <- as.Date(.POSIXct(map_int(json$data, "[[", "created")))
  owned_by <- map_chr(json$data, "[[", "owned_by")

  df <- data.frame(
    id = id,
    created_at = created,
    owned_by = owned_by
  )
  df <- cbind(df, match_prices(provider@name, df$id))
  df[order(-xtfrm(df$created_at)), ]
}
