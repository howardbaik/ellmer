# invoke_tools() echoes tool requests and results

    Code
      . <- invoke_tools(turn, echo = "output")
    Message
      ( ) [tool call] my_tool()
      o #> 1
      ( ) [tool call] my_tool(x = 1)
      # #> Error: unused argument (x = 1)
      ( ) [tool call] tool_list()
      o #> {"a":1,"b":2}
      ( ) [tool call] tool_chr()
      o #> a
        #> b
        #> c
      ( ) [tool call] tool_abort()
      # #> Error: Unexpected input
        #> i Please revise and try again.

# invoke_tools_async() echoes tool requests and results

    Code
      . <- sync(invoke_tools_async(turn, echo = "output"))
    Message
      ( ) [tool call] my_tool()
      ( ) [tool call] my_tool(x = 1)
      ( ) [tool call] tool_list()
      ( ) [tool call] tool_chr()
      ( ) [tool call] tool_abort()
      # #> Error: unused argument (x = 1)
      # #> Error: Unexpected input
        #> i Please revise and try again.
      o #> 1
      o #> {"a":1,"b":2}
      o #> a
        #> b
        #> c

# tool error warnings

    Code
      warn_tool_errors(errors)
    Condition
      Warning:
      Failed to evaluate 2 tool calls.
      x [returns_json (call1)]: The JSON was invalid: {[1, 2, 3]}
      x [throws (call2)]: went boom!

