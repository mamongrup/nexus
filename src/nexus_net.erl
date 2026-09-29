%% Network trust helpers.
%%
%% The only supported way to learn a client address is the socket peer that
%% Mist reports. Forwarding headers are attacker controlled, so they are only
%% consulted when the immediate peer is an explicitly configured proxy.
-module(nexus_net).
-export([ip_in_cidrs/2, normalize_ip/1]).

%% True when the address falls inside any configured entry. Each entry is a
%% plain address ("10.0.0.5") or a CIDR block ("10.0.0.0/8", "2001:db8::/32").
%% Unparseable entries are ignored so a typo can never widen trust.
ip_in_cidrs(_Ip, []) ->
    false;
ip_in_cidrs(Ip, Entries) ->
    lists:any(fun(Entry) -> entry_matches(Ip, Entry) end, Entries).

%% Rewrites IPv4-mapped IPv6 spellings so ::ffff:10.0.0.1 and 10.0.0.1 are
%% recognised as the same host by a rule written in either notation.
%% Returns an empty binary when the input is not an address at all.
normalize_ip(Ip) ->
    case strip_ipv4_mapped(Ip) of
        none -> <<>>;
        Text -> Text
    end.

strip_ipv4_mapped(Ip) ->
    try
        Text = string:trim(binary_to_list(Ip)),
        case string:prefix(string:lowercase(Text), "::ffff:") of
            nomatch -> ensure_parses(Text);
            Mapped -> ensure_parses(Mapped)
        end
    catch
        _:_ -> <<>>
    end.

ensure_parses(Text) ->
    case address_bytes(Text) of
        none -> <<>>;
        _ -> list_to_binary(Text)
    end.

entry_matches(Ip, Entry) ->
    case split_entry(Entry) of
        none ->
            false;
        {Network, Bits} ->
            case address_bytes(Ip) of
                none -> false;
                Address when bit_size(Address) =/= bit_size(Network) -> false;
                Address -> same_prefix(Address, Network, Bits)
            end
    end.

split_entry(Entry) ->
    case binary:split(Entry, <<"/">>) of
        [Plain] ->
            case address_bytes(Plain) of
                none -> none;
                Bytes -> {Bytes, bit_size(Bytes)}
            end;
        [NetworkText, BitsText] ->
            case address_bytes(NetworkText) of
                none -> none;
                Bytes -> with_bits(Bytes, BitsText)
            end
    end.

with_bits(Bytes, BitsText) ->
    try
        Bits = binary_to_integer(string:trim(BitsText)),
        case Bits >= 0 andalso Bits =< bit_size(Bytes) of
            true -> {Bytes, Bits};
            false -> none
        end
    catch
        _:_ -> none
    end.

same_prefix(_Address, _Network, 0) ->
    true;
same_prefix(Address, Network, Bits) ->
    same_prefix_bytes(Address, Network, Bits).

%% Compare the network bit by bit. Whole bytes must match exactly; the final
%% partial byte is compared only across the bits that belong to the prefix.
%% Callers guarantee both addresses have the same bit size, so a prefix that
%% runs out of bits has already matched in full.
same_prefix_bytes(_, _, Bits) when Bits =< 0 ->
    true;
same_prefix_bytes(<<A, RestA/binary>>, <<B, RestB/binary>>, Bits) when Bits >= 8 ->
    case A =:= B of
        false -> false;
        true -> same_prefix_bytes(RestA, RestB, Bits - 8)
    end;
same_prefix_bytes(<<A, _/binary>>, <<B, _/binary>>, Bits) ->
    Mask = low_bits_mask(Bits),
    (A band Mask) =:= (B band Mask);
same_prefix_bytes(_, _, _) ->
    false.

%% Masks that keep the leading Bits of a byte. The top bits are the network
%% bits, so the mask is the high-order run, not the low-order one.
low_bits_mask(Bits) ->
    case Bits of
        1 -> 16#80;
        2 -> 16#C0;
        3 -> 16#E0;
        4 -> 16#F0;
        5 -> 16#F8;
        6 -> 16#FC;
        7 -> 16#FE
    end.

address_bytes(Text) ->
    try
        %% inet:parse_address/1 expects a charlist, not a binary, on this OTP.
        {ok, Address} = inet:parse_address(string:trim(to_charlist(Text))),
        tuple_to_bytes(Address)
    catch
        _:_ -> none
    end.

to_charlist(Text) when is_binary(Text) ->
    binary_to_list(Text);
to_charlist(Text) when is_list(Text) ->
    Text.

%% inet reports IPv4 as a 4-tuple of 8-bit words and IPv6 as an 8-tuple of
%% 16-bit words. The tuple length decides the family: reading the width from
%% the value would make ::1 (every word below 256) collapse to 8 bytes while
%% 2001:db8::1 expanded to 16, and the two could never be compared.
tuple_to_bytes(Address) when tuple_size(Address) =:= 4 ->
    list_to_binary(tuple_to_list(Address));
tuple_to_bytes(Address) when tuple_size(Address) =:= 8 ->
    list_to_binary(lists:append([word16(Word) || Word <- tuple_to_list(Address)]));
tuple_to_bytes(_) ->
    none.

word16(Word) ->
    [Word div 256, Word rem 256].
