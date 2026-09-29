-module(nexus_agency_callback_http).
-export([post_json/3, ends_with/2, drop_last/1]).

post_json(Url, Body, AuthHeader)
    when is_binary(Url), is_binary(Body), is_binary(AuthHeader) ->
  {ok, _} = application:ensure_all_started(inets),
  {ok, _} = application:ensure_all_started(ssl),
  UrlStr = binary_to_list(Url),
  BodyStr = binary_to_list(Body),
  Headers =
    [
      {"Accept", "application/json"},
      {"User-Agent", "NEXUS-TravelTech/2.0"},
      {"Connection", "keep-alive"}
    ]
    ++ case AuthHeader of
      <<>> -> [];
      A -> [{"Authorization", binary_to_list(A)}]
    end,
  Request = {UrlStr, Headers, "application/json; charset=UTF-8", BodyStr},
  HttpOptions = [
    {connect_timeout, 15000},
    {timeout, 30000},
    {ssl, ssl_opts_for_url(UrlStr)}
  ],
  case httpc:request(post, Request, HttpOptions, []) of
    {ok, {{_, Status, _}, _Headers, RespBody}} ->
      Bin = iolist_to_binary(RespBody),
      case Status >= 200 andalso Status < 300 of
        true -> {ok, Bin};
        false -> {error, Bin}
      end;
    {error, Reason} ->
      {error, iolist_to_binary(io_lib:format("~p", [Reason]))}
  end.

ssl_opts_for_url(UrlStr) ->
  case lists:prefix("https://", UrlStr) of
    true ->
      [
        {verify, verify_peer},
        {depth, 3},
        {customize_hostname_check, [
          {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
        ]}
      ];
    false -> []
  end.

ends_with(Value, Suffix) when is_binary(Value), is_binary(Suffix) ->
  binary:longest_common_suffix([Value, Suffix]) =:= byte_size(Suffix).

drop_last(Value) when is_binary(Value) ->
  Size = byte_size(Value),
  case Size of
    0 -> <<>>;
    _ -> binary:part(Value, 0, Size - 1)
  end.
