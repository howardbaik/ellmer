# defaults are reported

    Code
      . <- chat_databricks()
    Message
      Using model = "databricks-claude-3-7-sonnet".

# M2M authentication requests look correct

    Code
      list(url = req$url, headers = req$headers, body = req$body$data)
    Output
      $url
      [1] "https://example.cloud.databricks.com/oidc/v1/token"
      
      $headers
      <httr2_headers>
      Authorization: <REDACTED>
      Accept: application/json
      
      $body
      $body$grant_type
      [1] "client_credentials"
      
      $body$scope
      [1] "all-apis"
      
      

