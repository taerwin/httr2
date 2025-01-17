test_that("req_paginate() checks inputs", {
  req <- request("http://example.com/")
  next_request <- function(req, parsed) req

  expect_snapshot(error = TRUE, {
    # `req`
    req_paginate("a", next_request)
    # `next_request`
    req_paginate(req, "a")
    req_paginate(req, function(req) req)
    # `parse_resp`
    req_paginate(req, next_request, parse_resp = "a")
    req_paginate(req, next_request, parse_resp = function(x) x)
    # `n_pages`
    req_paginate(req, next_request, n_pages = "a")
    req_paginate(req, next_request, n_pages = function(x) x)
  })
})

test_that("paginate_next_request() produces the request to the next page", {
  resp <- response()
  f_next_request <- function(req, parsed) {
    req_url_path(req, "/2")
  }
  f_n_pages <- function(parsed) 3

  req <- req_paginate(
    request("http://example.com/"),
    next_request = f_next_request,
    n_pages = f_n_pages
  )

  expect_snapshot(error = TRUE, {
    paginate_next_request("a", req)
    paginate_next_request(req, "a")
  })

  out <- paginate_next_request(req, parsed = NULL)
  expect_equal(out$url, "http://example.com/2")
  expect_equal(req$policies$paginate$n_pages(resp), 3)
})

test_that("req_paginate_next_url() can paginate", {
  local_mocked_responses(list(
    response_json(
      url = "https://pokeapi.co/api/v2/pokemon?limit=11",
      body = list('next' = "https://pokeapi.co/api/v2/pokemon?offset=11&limit=11")
    ),
    response_json(
      url = "https://pokeapi.co/api/v2/pokemon?limit=11",
      body = list('next' = "https://pokeapi.co/api/v2/pokemon?offset=22&limit=11")
    )
  ))

  req1 <- request("https://pokeapi.co/api/v2/pokemon") %>%
    req_url_query(limit = 11) %>%
    req_paginate_next_url(
      parse_resp = function(resp) list(data = "a", next_url = resp_body_json(resp)[["next"]])
    )

  resp <- req_perform(req1)
  parsed <- req1$policies$paginate$parse_resp(resp)
  req2 <- paginate_next_request(req1, parsed)
  expect_equal(req2$url, "https://pokeapi.co/api/v2/pokemon?offset=11&limit=11")

  resp <- req_perform(req2)
  parsed <- req1$policies$paginate$parse_resp(resp)
  req3 <- paginate_next_request(req2, parsed)
  expect_equal(req3$url, "https://pokeapi.co/api/v2/pokemon?offset=22&limit=11")
})

test_that("req_paginate_token() checks inputs", {
  req <- request("http://example.com/")

  expect_snapshot(error = TRUE, {
    req_paginate_token(req, "a")
    req_paginate_token(req, function(req) resp)
    req_paginate_token(req, function(req, next_token) req, "a")
    req_paginate_token(req, function(req, next_token) req, function(req) req)
  })
})

test_that("req_paginate_token() can paginate", {
  local_mocked_responses(list(
    response_json(body = list(x = 1, my_next_token = 2)),
    response_json(body = list(x = 1, my_next_token = 3))
  ))

  req1 <- request("http://example.com") %>%
    req_paginate_token(
      parse_resp = function(resp) {
        parsed <- resp_body_json(resp)
        list(next_token = parsed$my_next_token, data = parsed["x"])
      },
      set_token = function(req, next_token) {
        req_body_json(req, list(my_token = next_token))
      }
    )

  resp <- req_perform(req1)
  parsed <- req1$policies$paginate$parse_resp(resp)
  req2 <- paginate_next_request(req1, parsed)
  expect_equal(req2$body$data$my_token, 2L)

  resp <- req_perform(req2)
  parsed <- req1$policies$paginate$parse_resp(resp)
  req3 <- paginate_next_request(req2, parsed)
  expect_equal(req3$body$data$my_token, 3L)
})

test_that("req_paginate_offset() checks inputs", {
  req <- request("http://example.com/")

  expect_snapshot(error = TRUE, {
    req_paginate_offset(req, "a")
    req_paginate_offset(req, function(req) req)
    req_paginate_offset(req, function(req, offset) req, page_size = "a")
  })
})

test_that("req_paginate_offset() can paginate", {
  req1 <- request("https://pokeapi.co/api/v2/pokemon") %>%
    req_url_query(limit = 11) %>%
    req_paginate_offset(
      offset = function(req, offset) req_url_query(req, offset = offset),
      page_size = 11
    )

  resp <- req_perform(req1)
  req2 <- paginate_next_request(req1, parsed = NULL)
  expect_equal(req2$url, "https://pokeapi.co/api/v2/pokemon?limit=11&offset=11")
  # offset stays the same when applied twice
  expect_equal(req2$url, "https://pokeapi.co/api/v2/pokemon?limit=11&offset=11")

  resp <- req_perform(req2)
  req3 <- paginate_next_request(req2, parsed = NULL)
  expect_equal(req3$url, "https://pokeapi.co/api/v2/pokemon?limit=11&offset=22")
})

test_that("req_paginate_page_index() checks inputs", {
  req <- request("http://example.com/")
  parse_resp <- function(resp) resp

  expect_snapshot(error = TRUE, {
    req_paginate_page_index(req, "a")
    req_paginate_page_index(req, function(req) req)
  })
})

test_that("req_paginate_page_index() can paginate", {
  req1 <- request("https://pokeapi.co/api/v2/pokemon") %>%
    req_url_query(limit = 11) %>%
    req_paginate_page_index(
      page_index = function(req, page) req_url_query(req, page = page)
    )

  resp <- req_perform(req1)
  req2 <- paginate_next_request(req1, NULL)
  expect_equal(req2$url, "https://pokeapi.co/api/v2/pokemon?limit=11&page=2")
  # offset stays the same when applied twice
  expect_equal(req2$url, "https://pokeapi.co/api/v2/pokemon?limit=11&page=2")

  resp <- req_perform(req2)
  req3 <- paginate_next_request(req2, NULL)
  expect_equal(req3$url, "https://pokeapi.co/api/v2/pokemon?limit=11&page=3")
})

test_that("paginate_req_perform() checks inputs", {
  req <- request("http://example.com") %>%
    req_paginate_token(
      parse_resp = function(resp) {
        list(next_token = 1, data = "a")
      },
      set_token = function(req, next_token) {
        req_body_json(req, list(my_token = next_token))
      }
    )

  expect_snapshot(error = TRUE, {
    paginate_req_perform("a")
    paginate_req_perform(request("http://example.com"))
    paginate_req_perform(req, max_pages = 0)
    paginate_req_perform(req, progress = -1)
  })
})

test_that("paginate_req_perform() iterates through pages", {
  req <- request_pagination_test()

  responses_2 <- paginate_req_perform(req, max_pages = 2)
  expect_length(responses_2, 2)
  expect_equal(responses_2[[1]], token_body_test(2))
  expect_equal(responses_2[[2]], token_body_test(3))

  responses_5 <- paginate_req_perform(req, max_pages = 5)
  expect_length(responses_5, 4)
  expect_equal(responses_5[[4]], token_body_test())

  responses_inf <- paginate_req_perform(req, max_pages = Inf)
  expect_length(responses_inf, 4)
  expect_equal(responses_inf[[4]], token_body_test())
})

test_that("paginate_req_perform() works if there is only one page", {
  req <- request_pagination_test(n_pages = function(resp, parsed) 1)

  expect_no_error(responses <- paginate_req_perform(req, max_pages = 2))
  expect_length(responses, 1)
})

test_that("parse_resp() produces a good error message", {
  req_not_a_list <- request("https://pokeapi.co/api/v2/pokemon") %>%
    req_paginate_next_url(parse_resp = function(resp) "a")
  req_missing_1_field <- request("https://pokeapi.co/api/v2/pokemon") %>%
    req_paginate_next_url(parse_resp = function(resp) list(data = "a"))
  req_missing_2_field <- request("https://pokeapi.co/api/v2/pokemon") %>%
    req_paginate_next_url(parse_resp = function(resp) list(x = "a"))
  resp <- response()

  expect_snapshot(error = TRUE, {
    req_not_a_list$policies$paginate$parse_resp(resp)
    req_missing_1_field$policies$paginate$parse_resp(resp)
    req_missing_2_field$policies$paginate$parse_resp(resp)
  })

  # The error call is helpful
  req <- request_pagination_test(
    parse_resp = function(resp) {
      parsed <- resp_body_json(resp)

      list(parsed$my_next_token, data = parsed)
    }
  )

  expect_snapshot(error = TRUE, {
    paginate_req_perform(req, max_pages = 2)
  })
})

test_that("paginate_req_perform() handles error in `parse_resp()`", {
  req <- request_pagination_test(
    parse_resp = function(resp) {
      parsed <- resp_body_json(resp)
      if (parsed$my_next_token >= 2) {
        abort("error")
      }

      list(next_token = parsed$my_next_token, data = parsed)
    }
  )

  expect_snapshot(error = TRUE, {
    paginate_req_perform(req, max_pages = 2)
  })
})
