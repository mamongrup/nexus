-module(nexus_secrets).
-export([seal/3, open/3, valid_https/1, secure_compare/2]).

seal(Value, Key, Context) when byte_size(Key) >= 64 ->
    try
        Nonce = crypto:strong_rand_bytes(12),
        {Cipher, Tag} = crypto:crypto_one_time_aead(aes_256_gcm, crypto:hash(sha256, Key), Nonce, Value, Context, 16, true),
        {ok, <<"v1:", (base64:encode(<<Nonce/binary, Tag/binary, Cipher/binary>>))/binary>>}
    catch _:_ -> {error, nil} end;
seal(_, _, _) -> {error, nil}.

open(<<"v1:", Encoded/binary>>, Key, Context) when byte_size(Key) >= 64 ->
    try
        <<Nonce:12/binary, Tag:16/binary, Cipher/binary>> = base64:decode(Encoded),
        case crypto:crypto_one_time_aead(aes_256_gcm, crypto:hash(sha256, Key), Nonce, Cipher, Context, Tag, false) of
            error -> {error, nil};
            Value -> {ok, Value}
        end
    catch _:_ -> {error, nil} end;
open(_, _, _) -> {error, nil}.

valid_https(Value) ->
    try
        case uri_string:parse(Value) of
            #{scheme := <<"https">>, host := Host} = Parsed when byte_size(Host) > 0 ->
                not maps:is_key(userinfo, Parsed) andalso not maps:is_key(fragment, Parsed)
                andalso Host =/= <<"localhost">> andalso Host =/= <<"127.0.0.1">> andalso Host =/= <<"::1">>;
            _ -> false
        end
    catch _:_ -> false end.

%% Constant-time secret comparison. Every candidate byte is examined so the
%% duration does not reveal how many leading characters matched.
secure_compare(A, B) when is_binary(A), is_binary(B), byte_size(A) =:= byte_size(B) ->
    secure_compare_loop(A, B, 0);
secure_compare(_, _) ->
    false.

secure_compare_loop(<<>>, <<>>, Acc) ->
    Acc =:= 0;
secure_compare_loop(<<A, RestA/binary>>, <<B, RestB/binary>>, Acc) ->
    secure_compare_loop(RestA, RestB, Acc bor (A bxor B)).
