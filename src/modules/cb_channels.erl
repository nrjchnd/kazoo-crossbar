%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2014, 2600Hz INC
%%% @doc
%%%
%%% Listing of all expected v1 callbacks
%%%
%%% @end
%%% @contributors:
%%%   Karl Anderson
%%%   James Aimonetti
%%%-------------------------------------------------------------------
-module(cb_channels).

-export([init/0
         ,allowed_methods/0, allowed_methods/1
         ,resource_exists/0, resource_exists/1
         ,content_types_provided/1
         ,validate/1, validate/2
         ,post/2
        ]).

-include("../crossbar.hrl").

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Initializes the bindings this module will respond to.
%% @end
%%--------------------------------------------------------------------
-spec init() -> 'ok'.
init() ->
    cb_modules_util:bind(?MODULE
                         ,[{<<"*.allowed_methods.channels">>, 'allowed_methods'}
                           ,{<<"*.resource_exists.channels">>, 'resource_exists'}
                           ,{<<"*.content_types_provided.channels">>, 'content_types_provided'}
                           ,{<<"*.validate.channels">>, 'validate'}
                           ,{<<"*.execute.post.channels">>, 'post'}
                          ]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Given the path tokens related to this module, what HTTP methods are
%% going to be responded to.
%% @end
%%--------------------------------------------------------------------
-spec allowed_methods() -> http_methods().
-spec allowed_methods(path_token()) -> http_methods().
allowed_methods() ->
    [?HTTP_GET].
allowed_methods(_) ->
    [?HTTP_GET, ?HTTP_POST].

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Does the path point to a valid resource
%% So /channels => []
%%    /channels/foo => [<<"foo">>]
%%    /channels/foo/bar => [<<"foo">>, <<"bar">>]
%% @end
%%--------------------------------------------------------------------
-spec resource_exists() -> 'true'.
-spec resource_exists(path_token()) -> 'true'.
resource_exists() -> 'true'.
resource_exists(_) -> 'true'.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% What content-types will the module be using to respond (matched against
%% client's accept header)
%% Of the form {atom, [{Type, SubType}]} :: {to_json, [{<<"application">>, <<"json">>}]}
%% @end
%%--------------------------------------------------------------------
-spec content_types_provided(cb_context:context()) -> cb_context:context().
content_types_provided(Context) ->
    Context.

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Check the request (request body, query string params, path tokens, etc)
%% and load necessary information.
%% /channels mights load a list of channel objects
%% /channels/123 might load the channel object 123
%% Generally, use crossbar_doc to manipulate the cb_context{} record
%% @end
%%--------------------------------------------------------------------
-spec validate(cb_context:context()) -> cb_context:context().
-spec validate(cb_context:context(), path_token()) -> cb_context:context().
validate(Context) ->
    validate_channels(Context, cb_context:req_verb(Context)).
validate(Context, Id) ->
    validate_channel(Context, Id, cb_context:req_verb(Context)).

-spec validate_channels(cb_context:context(), http_method()) -> cb_context:context().
validate_channels(Context, ?HTTP_GET) ->
    summary(Context).

-spec validate_channel(cb_context:context(), path_token(), http_method()) -> cb_context:context().
validate_channel(Context, Id, ?HTTP_GET) ->
    read(Id, Context);
validate_channel(Context, Id, ?HTTP_POST) ->
    update(Id, Context).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% If the HTTP verb is POST, execute the actual action, usually a db save
%% (after a merge perhaps).
%% @end
%%--------------------------------------------------------------------
-spec post(cb_context:context(), path_token()) -> cb_context:context().
post(Context, _) ->
    crossbar_doc:save(Context).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Load an instance from the database
%% @end
%%--------------------------------------------------------------------
-spec read(ne_binary(), cb_context:context()) -> cb_context:context().
read(Id, Context) ->
    crossbar_doc:load(Id, Context).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Update an existing menu document with the data provided, if it is
%% valid
%% @end
%%--------------------------------------------------------------------
-spec update(ne_binary(), cb_context:context()) -> cb_context:context().
update(_Id, Context) ->
    Context.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Attempt to load a summarized listing of all instances of this
%% resource.
%% @end
%%--------------------------------------------------------------------
-spec summary(cb_context:context()) -> cb_context:context().
summary(Context) ->
    case cb_context:req_nouns(Context) of
        [{<<"channels">>, []}, {<<"users">>, [UserId]} | _] ->
            lager:debug("getting user summary for ~s", [UserId]),
            user_summary(Context, UserId);
        [{<<"channels">>, []}, {<<"accounts">>, [_AccountId]} | _] ->
            lager:debug("getting account summary"),
            account_summary(Context);
        _Nouns ->
            lager:debug("unexpected nouns: ~p", [_Nouns]),
            Context
    end.

user_summary(Context, UserId) ->
    Options = [{'key', [UserId, <<"device">>]}
               ,'include_docs'
              ],
    %% TODO: Using the cf_attributes from crossbar isn't exactly kosher
    Context1 = crossbar_doc:load_view(<<"cf_attributes/owned">>, Options, Context),
    case cb_context:has_errors(Context1) of
        'true' -> Context1;
        'false' -> get_channels(Context1, cb_context:doc(Context1), fun wapi_call:publish_query_user_channels_req/1)
    end.

account_summary(Context) ->
    get_channels(Context, [], fun wapi_call:publish_query_account_channels_req/1).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
-spec get_channels(cb_context:context(), wh_json:objects(), function()) -> cb_context:context().
get_channels(Context, Devices, PublisherFun) ->
    Realm = crossbar_util:get_account_realm(cb_context:account_id(Context)),
    Usernames = [Username
                 || JObj <- Devices,
                    (Username = wh_json:get_value([<<"doc">>
                                                   ,<<"sip">>
                                                   ,<<"username">>
                                                  ], JObj))
                        =/= 'undefined'
                ],
    Req = [{<<"Realm">>, Realm}
           ,{<<"Usernames">>, Usernames}
           ,{<<"Account-ID">>, cb_context:account_id(Context)}
           | wh_api:default_headers(?APP_NAME, ?APP_VERSION)
          ],
    case whapps_util:amqp_pool_collect(Req
                                       ,PublisherFun
                                       ,{'ecallmgr', 'true'}
                                      )
    of
        {'error', _R} ->
            lager:error("could not reach ecallmgr channels: ~p", [_R]),
            crossbar_util:response('error', <<"could not reach ecallmgr channels">>, Context);
        {_, Resp} ->
            Channels = merge_user_channels_jobjs(Resp),
            crossbar_util:response(Channels, Context)
    end.

-spec merge_user_channels_jobjs(wh_json:objects()) -> wh_json:objects().
merge_user_channels_jobjs(JObjs) ->
    merge_user_channels_jobjs(JObjs, dict:new()).

-spec merge_user_channels_jobjs(wh_json:objects(), dict()) -> wh_json:objects().
merge_user_channels_jobjs([], Dict) ->
    [delete_keys(Channel) || {_, Channel} <- dict:to_list(Dict)];
merge_user_channels_jobjs([JObj|JObjs], Dict) ->
    merge_user_channels_jobjs(JObjs, merge_user_channels_jobj(JObj, Dict)).

-spec merge_user_channels_jobj(wh_json:object(), dict()) -> dict().
merge_user_channels_jobj(JObj, Dict) ->
    lists:foldl(fun merge_user_channels_fold/2, Dict, wh_json:get_value(<<"Channels">>, JObj, [])).

-spec merge_user_channels_fold(wh_json:object(), dict()) -> dict().
merge_user_channels_fold(Channel, D) ->
    UUID = wh_json:get_value(<<"uuid">>, Channel),
    dict:store(UUID, Channel, D).

-spec delete_keys(wh_json:object()) -> wh_json:object().
delete_keys(JObj) ->
    wh_json:delete_keys([<<"account_id">>
                         ,<<"bridge_id">>
                         ,<<"context">>
                         ,<<"dialplan">>
                         ,<<"handling_locally">>
                         ,<<"node">>
                         ,<<"precedence">>
                         ,<<"profile">>
                         ,<<"realm">>
                        ], JObj).
