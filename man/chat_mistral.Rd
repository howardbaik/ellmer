% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/provider-mistral.R
\name{chat_mistral}
\alias{chat_mistral}
\title{Chat with a model hosted on Mistral's La Platforme}
\usage{
chat_mistral(
  system_prompt = NULL,
  params = NULL,
  api_key = mistral_key(),
  model = NULL,
  seed = NULL,
  api_args = list(),
  echo = NULL,
  api_headers = character()
)
}
\arguments{
\item{system_prompt}{A system prompt to set the behavior of the assistant.}

\item{params}{Common model parameters, usually created by \code{\link[=params]{params()}}.}

\item{api_key}{API key to use for authentication.

You generally should not supply this directly, but instead set the \code{MISTRAL_API_KEY} environment variable.
The best place to set this is in \code{.Renviron},
which you can easily edit by calling \code{usethis::edit_r_environ()}.}

\item{model}{The model to use for the chat (defaults to "mistral-large-latest").
We regularly update the default, so we strongly recommend explicitly specifying a model for anything other than casual use.}

\item{seed}{Optional integer seed that ChatGPT uses to try and make output
more reproducible.}

\item{api_args}{Named list of arbitrary extra arguments appended to the body
of every chat API call. Combined with the body object generated by ellmer
with \code{\link[=modifyList]{modifyList()}}.}

\item{echo}{One of the following options:
\itemize{
\item \code{none}: don't emit any output (default when running in a function).
\item \code{output}: echo text and tool-calling output as it streams in (default
when running at the console).
\item \code{all}: echo all input and output.
}

Note this only affects the \code{chat()} method.}

\item{api_headers}{Named character vector of arbitrary extra headers appended
to every chat API call.}
}
\value{
A \link{Chat} object.
}
\description{
Get your API key from \url{https://console.mistral.ai/api-keys}.
\subsection{Known limitations}{
\itemize{
\item Tool calling is unstable.
\item Images require a model that supports images.
}
}
}
\examples{
\dontrun{
chat <- chat_mistral()
chat$chat("Tell me three jokes about statisticians")
}
}
\seealso{
Other chatbots: 
\code{\link{chat_anthropic}()},
\code{\link{chat_aws_bedrock}()},
\code{\link{chat_azure_openai}()},
\code{\link{chat_cloudflare}()},
\code{\link{chat_databricks}()},
\code{\link{chat_deepseek}()},
\code{\link{chat_github}()},
\code{\link{chat_google_gemini}()},
\code{\link{chat_groq}()},
\code{\link{chat_huggingface}()},
\code{\link{chat_ollama}()},
\code{\link{chat_openai}()},
\code{\link{chat_openrouter}()},
\code{\link{chat_perplexity}()},
\code{\link{chat_portkey}()}
}
\concept{chatbots}
