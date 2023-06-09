module Main exposing (main)

import Browser
import Browser.Events as Events
import Common exposing (..)
import Constants exposing (..)
import Engine exposing (..)
import Game exposing (..)
import Html
import Html.Attributes as HtmlA
import Html.Events as HtmlEvents
import Html.Events.Extra.Touch as Touch
import Svg
import Svg.Attributes as SvgA



-- MAIN


main : Program Flags Model Msg
main =
    Browser.element
        { init = initialModel
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- INIT


type alias Flags =
    { x : Float

    -- , y : Float
    , isMobile : Bool
    }


initialModel : Flags -> ( Model, Cmd Msg )
initialModel d =
    ( { gs = newGameState
      , gameStatus = Menu
      , keys = initialKeysPressed
      , isMobile = d.isMobile
      , rand = ( 0, 0 )
      , middleX = d.x + 80
      , touchDown = False
      , touchPos = newPosition 0 0
      }
    , randCommand NewRandom
    )



-- MODEL


type alias Model =
    { gs : GameState
    , gameStatus : GameStatus
    , keys : KeysPressed
    , rand : ( Float, Float )
    , isMobile : Bool
    , middleX : Float
    , touchDown : Bool
    , touchPos : Position
    }



-- UPDATE


type Msg
    = OnAnimationFrame Float
    | KeyDown String
    | KeyUp String
    | ClickDown ( Float, Float )
    | ClickMove ( Float, Float )
    | ClickUp
    | NewRandom ( Float, Float )
    | Blur Events.Visibility
    | PlayButton
    | ToMenu


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PlayButton ->
            ( { model | gameStatus = Playing, gs = newGameState }, Cmd.none )

        ToMenu ->
            ( { model | gameStatus = Menu }, Cmd.none )

        OnAnimationFrame deltaTime ->
            -- main game loop
            let
                delta =
                    deltaTime / 1000

                touch =
                    if model.touchDown then
                        ( Just model.touchPos, model.middleX )

                    else
                        ( Nothing, model.middleX )
            in
            ( { model
                | gs = updateGameStateModelCall delta model.rand model.keys touch model.gs
                , gameStatus = getGameOverStatus model.gs
              }
            , randCommand NewRandom
            )

        NewRandom r ->
            ( { model | rand = r }, Cmd.none )

        KeyDown key ->
            -- add key to model.keys
            ( applyFuncToModelKeys (addKey key) model, Cmd.none )

        KeyUp key ->
            -- remove key from model.keys
            ( applyFuncToModelKeys (removeKey key) model, Cmd.none )

        ClickDown ( x, y ) ->
            ( { model | touchDown = True, touchPos = newPosition x y }, Cmd.none )

        ClickMove ( x, y ) ->
            ( { model | touchPos = newPosition x y }, Cmd.none )

        ClickUp ->
            ( { model | touchDown = False }, Cmd.none )

        Blur _ ->
            -- clear model.keys
            ( { model | touchDown = False } |> applyFuncToModelKeys clearKeys, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        (case model.gameStatus of
            Playing ->
                [ Events.onAnimationFrameDelta OnAnimationFrame
                , Events.onKeyDown (keyDecoder KeyDown)
                , Events.onKeyUp (keyDecoder KeyUp)
                , Events.onVisibilityChange Blur
                ]

            _ ->
                [ Sub.none ]
        )



-- VIEW


view : Model -> Html.Html Msg
view model =
    Html.div
        [ HtmlA.class "main" ]
        (case model.gameStatus of
            Playing ->
                let
                    canvas =
                        Svg.g
                            [ SvgA.class "canvas"
                            ]
                            [ viewGameState model.gs
                            ]
                in
                [ Svg.svg
                    [ SvgA.class "canvasContainer"
                    , SvgA.viewBox ("0 0 " ++ canvasS.sw ++ " " ++ canvasS.sh)
                    , Touch.onStart (ClickDown << touchCoordinates)
                    , Touch.onMove (ClickMove << touchCoordinates)
                    , Touch.onEnd (\_ -> ClickUp)
                    ]
                    (if model.isMobile then
                        [ Svg.g [ SvgA.class "mobileExp" ]
                            [ viewEntity
                                "assets/mobileBackground.png"
                                { pos = newPosition 0 0
                                , dim = newDimension canvasS.w canvasS.h
                                , rot = initialRotation
                                }
                            ]
                        , canvas
                        ]

                     else
                        [ canvas ]
                    )
                ]

            GameOver ->
                [ Html.h1 [ HtmlA.class "title" ] [ Html.text "נגמר המשחק!" ]
                , Html.p [ HtmlA.class "pDescription" ]
                    [ Html.text "צברת "
                    , Html.text (model.gs.score |> String.fromInt)
                    , Html.text " נקודות"
                    ]
                , Html.button [ HtmlEvents.onClick ToMenu, HtmlA.class "controlButton" ] [ Html.text "לתפריט" ]
                ]

            Menu ->
                [ Html.h1 [ HtmlA.class "title" ] [ Html.text "ברוכים הבאים למשחק!" ]
                , Html.div [ HtmlA.class "controlContainer" ]
                    [ Html.button [ HtmlEvents.onClick PlayButton, HtmlA.class "controlButton" ] [ Html.text "שחק" ]
                    , Html.br [] []
                    , Html.br [] []
                    , Html.h3 [ HtmlA.class "subTitle" ] [ Html.text "הסבר:" ]
                    , Html.p
                        [ HtmlA.class "pDescription"
                        ]
                        [ Html.text "קפוץ מפלטפורמה לפלטפורמה והימנע ממגע בלבה."
                        ]
                    , Html.p [ HtmlA.class "pDescription" ] [ Html.text "המשחק תוכנת על ידי ", Html.a [ HtmlA.class "pDescription", HtmlA.href "http://www.github.com/48thFlame" ] [ Html.text "אבישי" ] ]
                    ]
                ]
        )
