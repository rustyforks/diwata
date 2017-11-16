module Views.Window.GroupedWindow exposing 
    ( FeedSource
    , Model
    , Msg
    , authorFeed
    , favoritedFeed
    , globalFeed
    , init
    , selectTag
    , tagFeed
    , update
    , viewWindowNames
    , viewFeedSources
    , yourFeed)

{-| The reusable Window Feed that appears on both the Home page as well as on
the Profile page. There's a lot of logic here, so it's more convenient to use
the heavyweight approach of giving this its own Model, view, and update.

This means callers must use Html.map and Cmd.map to use this thing, but in
this case that's totally worth it because of the amount of logic wrapped up
in this thing.

For every other reusable view in this application, this API would be totally
overkill, so we use simpler APIs instead.

-}

import Data.Window as Window exposing (Window, Tag)
import Data.Window.GroupedWindow as GroupedWindow exposing (GroupedWindow, WindowName)
import Data.Window.TableName as TableName exposing (TableName,tableNameToString)
import Data.AuthToken as AuthToken exposing (AuthToken)
import Data.Session as Session exposing (Session)
import Data.User as User exposing (Username)
import Dom.Scroll
import Html exposing (..)
import Html.Attributes exposing (attribute, class, classList, href, id, placeholder, src)
import Html.Events exposing (onClick)
import Http
import Request.Window
import SelectList exposing (Position(..), SelectList)
import Task exposing (Task)
import Util exposing ((=>), onClickStopPropagation, pair, viewIf)
import Views.Window
import Views.Errors as Errors
import Views.Page exposing (bodyId)
import Views.Spinner exposing (spinner)
import Route exposing (Route)


-- MODEL --


type Model
    = Model InternalModel


{-| This should not be exposed! We want to benefit from the guarantee that only
this module can create or alter this model. This way if it ever ends up in
a surprising state, we know exactly where to look: this file.
-}
type alias InternalModel =
    { errors : List String
    , groupedWindow : List GroupedWindow
    , feedSources : SelectList FeedSource
    , activePage : Int
    , isLoading : Bool
    }


init : Session -> SelectList FeedSource -> Task Http.Error Model
init session feedSources =
    let
        source =
            SelectList.selected feedSources

        toModel ( activePage, groupedWindow ) =
            Model
                { errors = []
                , activePage = activePage
                , groupedWindow = groupedWindow
                , feedSources = feedSources
                , isLoading = False
                }
    in
    source
        |> fetch (Maybe.map .token session.user) 1
        |> Task.map toModel



-- VIEW --

viewWindowName: WindowName -> Html msg
viewWindowName windowName = 
    a [class "nav-group-item", Route.href (Route.Window windowName.tableName) ]
        [span [class "icon icon-list"] []
        ,text windowName.name
        ]

viewWindowGroup: GroupedWindow  -> Html msg
viewWindowGroup groupedWindow = 
    nav [class "nav-group"]
        [ h5 [class "nav-group-title"] [text groupedWindow.group]
        , div [] <| List.map viewWindowName groupedWindow.windowNames
        ]


viewWindowNames : Model -> List (Html Msg)
viewWindowNames (Model { activePage, groupedWindow, feedSources }) =
    List.map viewWindowGroup groupedWindow


viewFeedSources : Model -> Html Msg
viewFeedSources (Model { feedSources, isLoading, errors }) =
    ul [ class "nav nav-pills outline-active" ] <|
        SelectList.toList (SelectList.mapBy viewFeedSource feedSources)
            ++ [ Errors.view DismissErrors errors, viewIf isLoading spinner ]


viewFeedSource : Position -> FeedSource -> Html Msg
viewFeedSource position source =
    li [ class "nav-item" ]
        [ a
            [ classList [ "nav-link" => True, "active" => position == Selected ]
            , href "javascript:void(0);"
            , onClick (SelectFeedSource source)
            ]
            [ text (sourceName source) ]
        ]


selectTag : Maybe AuthToken -> Tag -> Cmd Msg
selectTag maybeAuthToken tagName =
    let
        source =
            tagFeed tagName
    in
    source
        |> fetch maybeAuthToken 1
        |> Task.attempt (FeedLoadCompleted source)


sourceName : FeedSource -> String
sourceName source =
    case source of
        YourFeed ->
            "Your Feed"

        GlobalFeed ->
            "Organized Windows"

        TagFeed tagName ->
            "#" ++ Window.tagToString tagName

        FavoritedFeed username ->
            "Favorited Windows"

        AuthorFeed username ->
            "My Windows"


limit : FeedSource -> Int
limit feedSource =
    case feedSource of
        YourFeed ->
            10

        GlobalFeed ->
            10

        TagFeed tagName ->
            10

        FavoritedFeed username ->
            5

        AuthorFeed username ->
            5




pageLink : Int -> Bool -> Html Msg
pageLink page isActive =
    li [ classList [ "page-item" => True, "active" => isActive ] ]
        [ a
            [ class "page-link"
            , href "javascript:void(0);"
            , onClick (SelectPage page)
            ]
            [ text (toString page) ]
        ]



-- UPDATE --


type Msg
    = DismissErrors
    | SelectFeedSource FeedSource
    | FeedLoadCompleted FeedSource (Result Http.Error ( Int, List GroupedWindow ))
    | ToggleFavorite TableName
    | FavoriteCompleted (Result Http.Error TableName)
    | SelectPage Int
    | SelectWindow TableName


update : Session -> Msg -> Model -> ( Model, Cmd Msg )
update session msg (Model internalModel) =
    updateInternal session msg internalModel
        |> Tuple.mapFirst Model


updateInternal : Session -> Msg -> InternalModel -> ( InternalModel, Cmd Msg )
updateInternal session msg model =
    case msg of
        DismissErrors ->
            { model | errors = [] } => Cmd.none

        SelectFeedSource source ->
            source
                |> fetch (Maybe.map .token session.user) 1
                |> Task.attempt (FeedLoadCompleted source)
                |> pair { model | isLoading = True }

        FeedLoadCompleted source (Ok ( activePage, groupedWindow )) ->
            { model
                | groupedWindow = groupedWindow
                , feedSources = selectFeedSource source model.feedSources
                , activePage = activePage
                , isLoading = False
            }
                => Cmd.none

        FeedLoadCompleted _ (Err error) ->
            { model
                | errors = model.errors ++ [ "Server error while trying to load groupedWindow" ]
                , isLoading = False
            }
                => Cmd.none

        ToggleFavorite tableName ->
            case session.user of
                Nothing ->
                    { model | errors = model.errors ++ [ "You are currently signed out. You must sign in to favorite windows." ] }
                        => Cmd.none

                Just user ->
                    Request.Window.toggleFavorite tableName user.token
                        |> Http.send FavoriteCompleted
                        |> pair model

        FavoriteCompleted (Ok window) ->
             model => Cmd.none

        FavoriteCompleted (Err error) ->
            { model | errors = model.errors ++ [ "Server error while trying to favorite window." ] }
                => Cmd.none

        SelectPage page ->
            let
                source =
                    SelectList.selected model.feedSources
            in
            source
                |> fetch (Maybe.map .token session.user) page
                |> Task.andThen (\groupedWindow -> Task.map (\_ -> groupedWindow) scrollToTop)
                |> Task.attempt (FeedLoadCompleted source)
                |> pair model

        SelectWindow tableName ->
            let _ = Debug.log "select window" (tableNameToString tableName)
            in
            model => Cmd.none

scrollToTop : Task x ()
scrollToTop =
    Dom.Scroll.toTop bodyId
        -- It's not worth showing the user anything special if scrolling fails.
        -- If anything, we'd log this to an error recording service.
        |> Task.onError (\_ -> Task.succeed ())


fetch : Maybe AuthToken -> Int -> FeedSource -> Task Http.Error ( Int, List GroupedWindow )
fetch token page feedSource =
    let
        defaultListConfig =
            Request.Window.defaultListConfig

        windowsPerPage =
            limit feedSource

        offset =
            (page - 1) * windowsPerPage

        listConfig =
            { defaultListConfig | offset = offset, limit = windowsPerPage }

        task =
            case feedSource of
                YourFeed ->
                    let
                        defaultFeedConfig =
                            Request.Window.defaultFeedConfig

                        feedConfig =
                            { defaultFeedConfig | offset = offset, limit = windowsPerPage }
                    in
                    token
                        |> Maybe.map (Request.Window.groupedWindow feedConfig >> Http.toTask)
                        |> Maybe.withDefault (Task.fail (Http.BadUrl "You need to be signed in to view your groupedWindow."))

                GlobalFeed ->
                    Request.Window.list listConfig token
                        |> Http.toTask

                TagFeed tagName ->
                    Request.Window.list { listConfig | tag = Just tagName } token
                        |> Http.toTask

                FavoritedFeed username ->
                    Request.Window.list { listConfig | favorited = Just username } token
                        |> Http.toTask

                AuthorFeed username ->
                    Request.Window.list { listConfig | author = Just username } token
                        |> Http.toTask
    in
    task
        |> Task.map (\groupedWindow -> ( page, groupedWindow ))



selectFeedSource : FeedSource -> SelectList FeedSource -> SelectList FeedSource
selectFeedSource source sources =
    let
        withoutTags =
            sources
                |> SelectList.toList
                |> List.filter (not << isTagFeed)

        newSources =
            case source of
                YourFeed ->
                    withoutTags

                GlobalFeed ->
                    withoutTags

                FavoritedFeed _ ->
                    withoutTags

                AuthorFeed _ ->
                    withoutTags

                TagFeed _ ->
                    withoutTags ++ [ source ]
    in
    case newSources of
        [] ->
            -- This should never happen. If we had a logging service set up,
            -- we would definitely want to report if it somehow did happen!
            sources

        first :: rest ->
            SelectList.fromLists [] first rest
                |> SelectList.select ((==) source)


isTagFeed : FeedSource -> Bool
isTagFeed source =
    case source of
        TagFeed _ ->
            True

        _ ->
            False



-- FEEDSOURCE --


type FeedSource
    = YourFeed
    | GlobalFeed
    | TagFeed Tag
    | FavoritedFeed Username
    | AuthorFeed Username


yourFeed : FeedSource
yourFeed =
    YourFeed


globalFeed : FeedSource
globalFeed =
    GlobalFeed


tagFeed : Tag -> FeedSource
tagFeed =
    TagFeed


favoritedFeed : Username -> FeedSource
favoritedFeed =
    FavoritedFeed


authorFeed : Username -> FeedSource
authorFeed =
    AuthorFeed