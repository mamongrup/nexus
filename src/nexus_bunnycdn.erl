-module(nexus_bunnycdn).
-export([upload/5, test_connection/3]).

upload(Region, StorageZone, ApiKey, RemotePath, BinaryData) ->
    try
        inets:start(),
        ssl:start(),
        CleanPath = case RemotePath of
            <<"/", Rest/binary>> -> Rest;
            _ -> RemotePath
        end,
        Url = binary_to_list(<<"https://", Region/binary, "/", StorageZone/binary, "/", CleanPath/binary>>),
        Headers = [
            {"AccessKey", binary_to_list(ApiKey)},
            {"Content-Type", "image/avif"},
            {"Accept", "application/json"}
        ],
        Request = {Url, Headers, "image/avif", BinaryData},
        HttpOpts = [{timeout, 25000}, {connect_timeout, 10000}, {ssl, [{verify, verify_none}]}],
        Opts = [{body_format, binary}],
        case httpc:request(put, Request, HttpOpts, Opts) of
            {ok, {{_, StatusCode, _}, _RespHeaders, RespBody}} when StatusCode =:= 200; StatusCode =:= 201 ->
                {ok, RespBody};
            {ok, {{_, StatusCode, _}, _, _}} ->
                {error, list_to_binary("HTTP Status: " ++ integer_to_list(StatusCode))};
            {error, HttpReason} ->
                {error, list_to_binary(io_lib:format("HTTP error: ~p", [HttpReason]))}
        end
    catch
        _:CatchReason ->
            {error, list_to_binary(io_lib:format("Exception: ~p", [CatchReason]))}
    end.

test_connection(Region, StorageZone, ApiKey) ->
    try
        inets:start(),
        ssl:start(),
        Url = binary_to_list(<<"https://", Region/binary, "/", StorageZone/binary, "/">>),
        Headers = [
            {"AccessKey", binary_to_list(ApiKey)},
            {"Accept", "application/json"}
        ],
        Request = {Url, Headers},
        HttpOpts = [{timeout, 15000}, {connect_timeout, 8000}, {ssl, [{verify, verify_none}]}],
        Opts = [{body_format, binary}],
        case httpc:request(get, Request, HttpOpts, Opts) of
            {ok, {{_, StatusCode, _}, _RespHeaders, RespBody}} when StatusCode =:= 200 ->
                {ok, RespBody};
            {ok, {{_, StatusCode, _}, _, _}} ->
                {error, list_to_binary("HTTP Status: " ++ integer_to_list(StatusCode))};
            {error, HttpReason} ->
                {error, list_to_binary(io_lib:format("HTTP error: ~p", [HttpReason]))}
        end
    catch
        _:CatchReason ->
            {error, list_to_binary(io_lib:format("Exception: ~p", [CatchReason]))}
    end.
