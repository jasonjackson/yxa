-module(sipheader).
-export([to/1, from/1, contact/1, via/1, via_print/1, to_print/1,
	 contact_print/1, auth_print/1, auth/1, comma/1, httparg/1]).

comma(String) ->
    comma([], String, false).

% comma(Parsed, Rest, Inquote)

comma(Parsed, [$\\, Char | Rest], true) ->
    comma(Parsed ++ [$\\, Char], Rest, true);
comma(Parsed, [$" | Rest], false) ->
    comma(Parsed ++ [$"], Rest, true);
comma(Parsed, [$" | Rest], true) ->
    comma(Parsed ++ [$"], Rest, false);
comma(Parsed, [$, | Rest], false) ->
    [Parsed | comma([], Rest, false)];
comma(Parsed, [Char | Rest], Inquote) ->
    comma(Parsed ++ [Char], Rest, Inquote);
comma(Parsed, [], false) ->
    [Parsed].

% name-addr = [ display-name ] "<" addr-spec ">"
% display-name = *token | quoted-string


% {Displayname, URL}

to([String]) ->
    name_header(String).

from([String]) ->
    name_header(String).

contact([]) ->
    [];
contact([String | Rest]) ->
    Headers = comma(String),
    lists:append(lists:map(fun(H) ->
				   name_header(H)
			   end, Headers),
		 contact(Rest)).

via([]) ->
    [];
via([String | Rest]) ->
    Headers = comma(String),
    lists:append(lists:map(fun(H) ->
				   [Protocol, Sentby] = string:tokens(H, " "),
				   {Protocol, sipurl:parse_hostport(Sentby)}
			   end, Headers),
		 via(Rest)).

via_print(Via) ->
    lists:map(fun(H) ->
		      {Protocol, {Host, Port}} = H,
		      Protocol ++ " " ++ Host ++ ":" ++ Port
	      end, Via).

contact_print(Contact) ->
    lists:map(fun(H) ->
		      name_print(H)
	      end, Contact).

to_print(To) ->
    name_print(To).

name_print({none, URI}) ->
    sipurl:print(URI);

name_print({Name, URI}) ->
    "\"" ++ Name ++ "\" <" ++ sipurl:print(URI) ++ ">".

unquote([$" | QString]) ->
    Index = string:chr(QString, $"),
    string:substr(QString, 1, Index - 1);

unquote(QString) ->
    QString.

name_header([$" | String]) ->
    Index1 = string:chr(String, $"),
    QString = string:substr(String, Index1),
    Index2 = string:chr(QString, $"),
    logger:log(debug, "index: ~p", [Index2]),
    Displayname = string:substr(QString, 1, Index2 - 1),
    Rest = string:strip(string:substr(QString, Index2 + 1), left),
    case Rest of
	[$< | Rest2] ->
	    Index3 = string:chr(Rest2, $>),
	    URL = string:substr(Rest2, 1, Index3 - 1),
	    URI = sipurl:parse(URL),
	    {Displayname, URI}
    end;

name_header(String) ->
    logger:log(debug, "n: ~p", [String]),
    case String of
	[$< | Rest2] ->
	    Index2 = string:chr(Rest2, $>),
	    URL = string:substr(Rest2, 1, Index2 - 1),
	    URI = sipurl:parse(URL),
	    {none, URI};
	URL ->
	    URI = sipurl:parse(URL),
	    {none, URI}
    end.

auth_print(Auth) ->
    {Realm, Nonce, Opaque} = Auth,
    ["Digest realm=" ++ Realm ++ ", nonce=" ++ Nonce ++ ", opaque=" ++ Opaque].

auth(["Digest " ++ String]) ->
    Headers = comma(String),
    L = lists:map(fun(A) ->
			  H = string:strip(A,left),
			  Index = string:chr(H, $=),
			  Name = string:substr(H, 1, Index - 1),
			  Value = string:substr(H, Index + 1),
			  
			  {Name, unquote(Value)}
		  end, Headers),
    dict:from_list(L).

httparg(String) ->
    Headers = string:tokens(String, "&"),
    L = lists:map(fun(A) ->
			  H = string:strip(A,left),
			  Index = string:chr(H, $=),
			  Name = string:substr(H, 1, Index - 1),
			  Value = string:substr(H, Index + 1),
			  
			  {Name, Value}
		  end, Headers),
    dict:from_list(L).