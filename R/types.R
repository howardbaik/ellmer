#' @include utils-S7.R
NULL

#' Type definitions for function calling and structured data extraction.
#'
#' These S7 classes are provided for use by package devlopers who are
#' extending ellmer. In every day use, use [type_boolean()] and friends.
#'
#' @name Type
#' @inheritParams type_boolean
#' @return S7 objects inheriting from `Type`
#' @examples
#' TypeBasic(type = "boolean")
#' TypeArray(items = TypeBasic(type = "boolean"))
NULL

Type <- new_class(
  "Type",
  properties = list(
    description = prop_string(allow_null = TRUE),
    required = prop_bool(TRUE)
  )
)

#' @export
#' @rdname Type
#' @param type Basic type name. Must be one of `boolean`, `integer`,
#'   `number`, or `string`.
TypeBasic <- new_class(
  "TypeBasic",
  Type,
  properties = list(
    type = prop_string()
  )
)

#' @export
#' @rdname Type
TypeEnum <- new_class(
  "TypeEnum",
  Type,
  properties = list(
    values = class_character
  )
)

#' @export
#' @rdname Type
TypeArray <- new_class(
  "TypeArray",
  Type,
  properties = list(
    items = Type
  )
)

#' @export
#' @param json A JSON schema object as a list.
#' @name Type
TypeJsonSchema <- new_class(
  "TypeJsonSchema",
  Type,
  properties = list(
    json = class_list
  )
)

#' @export
#' @rdname Type
#' @param properties Named list of properties stored inside the object.
#'   Each element should be an S7 `Type` object.`
TypeObject <- new_class(
  "TypeObject",
  Type,
  properties = list(
    properties = prop_list_of(Type, names = "all"),
    additional_properties = prop_bool(FALSE)
  )
)

#' Type specifications
#'
#' @description
#' These functions specify object types in a way that chatbots understand and
#' are used for tool calling and structured data extraction. Their names are
#' based on the [JSON schema](https://json-schema.org), which is what the APIs
#' expect behind the scenes. The translation from R concepts to these types is
#' fairly straightforward.
#'
#' * `type_boolean()`, `type_integer()`, `type_number()`, and `type_string()`
#'   each represent scalars. These are equivalent to length-1 logical,
#'   integer, double, and character vectors (respectively).
#'
#' * `type_enum()` is equivalent to a length-1 factor; it is a string that can
#'   only take the specified values.
#'
#' * `type_array()` is equivalent to a vector in R. You can use it to represent
#'   an atomic vector: e.g. `type_array(type_boolean())` is equivalent
#'   to a logical vector and `type_array(type_string())` is equivalent
#'   to a character vector). You can also use it to represent a list of more
#'   complicated types where every element is the same type (R has no base
#'   equivalent to this), e.g. `type_array(type_array(type_string()))`
#'   represents a list of character vectors.
#'
#' * `type_object()` is equivalent to a named list in R, but where every element
#'   must have the specified type. For example,
#'   `type_object(a = type_string(), b = type_array(type_integer()))` is
#'   equivalent to a list with an element called `a` that is a string and
#'   an element called `b` that is an integer vector.
#'
#' * `type_from_schema()` allows you to specify the full schema that you want to
#'   get back from the LLM as a JSON schema. This is useful if you have a
#'   pre-defined schema that you want to use directly without manually creating
#'   the type using the `type_*()` functions. You can point to a file with the
#'   `path` argument or provide a JSON string with `text`. The schema must be a
#'   valid JSON schema object.
#'
#' @param description,.description The purpose of the component. This is
#'   used by the LLM to determine what values to pass to the tool or what
#'   values to extract in the structured data, so the more detail that you can
#'   provide here, the better.
#' @param required,.required Is the component or argument required?
#'
#'   In type descriptions for structured data, if `required = FALSE` and the
#'   component does not exist in the data, the LLM may hallucinate a value. Only
#'   applies when the element is nested inside of a `type_object()`.
#'
#'   In tool definitions, `required = TRUE` signals that the LLM should always
#'   provide a value. Arguments with `required = FALSE` should have a default
#'   value in the tool function's definition. If the LLM does not provide a
#'   value, the default value will be used.
#' @export
#' @examples
#' # An integer vector
#' type_array(type_integer())
#'
#' # The closest equivalent to a data frame is an array of objects
#' type_array(type_object(
#'    x = type_boolean(),
#'    y = type_string(),
#'    z = type_number()
#' ))
#'
#' # There's no specific type for dates, but you use a string with the
#' # requested format in the description (it's not gauranteed that you'll
#' # get this format back, but you should most of the time)
#' type_string("The creation date, in YYYY-MM-DD format.")
#' type_string("The update date, in dd/mm/yyyy format.")
type_boolean <- function(description = NULL, required = TRUE) {
  TypeBasic(type = "boolean", description = description, required = required)
}
#' @export
#' @rdname type_boolean
type_integer <- function(description = NULL, required = TRUE) {
  TypeBasic(type = "integer", description = description, required = required)
}
#' @export
#' @rdname type_boolean
type_number <- function(description = NULL, required = TRUE) {
  TypeBasic(type = "number", description = description, required = required)
}
#' @export
#' @rdname type_boolean
type_string <- function(description = NULL, required = TRUE) {
  TypeBasic(type = "string", description = description, required = required)
}

#' @param values Character vector of permitted values.
#' @export
#' @rdname type_boolean
type_enum <- function(values, description = NULL, required = TRUE) {
  TypeEnum(values = values, description = description, required = required)
}

#' @param items The type of the array items. Can be created by any of the
#'   `type_` function.
#' @export
#' @rdname type_boolean
type_array <- function(items, description = NULL, required = TRUE) {
  TypeArray(items = items, description = description, required = required)
}

#' @param ... Name-type pairs defineing the components that the object must
#'   possess.
#' @param .additional_properties Can the object have arbitrary additional
#'   properties that are not explicitly listed? Only supported by Claude.
#' @export
#' @rdname type_boolean
type_object <- function(
  .description = NULL,
  ...,
  .required = TRUE,
  .additional_properties = FALSE
) {
  TypeObject(
    properties = list2(...),
    description = .description,
    required = .required,
    additional_properties = .additional_properties
  )
}

#' @param text A JSON string.
#' @param path A file path to a JSON file.
#' @export
#' @rdname type_boolean
type_from_schema <- function(text, path) {
  check_exclusive(text, path)
  if (!missing(text)) {
    json <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  } else {
    json <- jsonlite::read_json(path)
  }
  TypeJsonSchema(json = json)
}
