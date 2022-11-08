module Pages.Registration.Request.View exposing (..)

import Basics.Extra exposing (flip)
import Html exposing (Html, button, div, input, label, table, tbody, td, text, tr)
import Html.Attributes exposing (disabled)
import Html.Events exposing (onClick, onInput)
import Html.Events.Extra exposing (onEnter)
import Maybe.Extra
import Monocle.Lens exposing (Lens)
import Pages.Registration.Request.Page as Page
import Pages.Util.Links as Links
import Pages.Util.Style as Style
import Pages.Util.ValidatedInput as ValidatedInput
import Pages.Util.ViewUtil as ViewUtil
import Util.LensUtil as LensUtil
import Util.MaybeUtil as MaybeUtil


view : Page.Model -> Html Page.Msg
view model =
    ViewUtil.viewWithErrorHandling
        { isFinished = always True
        , initialization = Page.lenses.initialization.get
        , configuration = .configuration
        , jwt = always Nothing
        , currentPage = Nothing
        , showNavigation = False
        }
        model
    <|
        case model.mode of
            Page.Editing ->
                viewEditing model

            Page.Confirmed ->
                viewConfirmed model


viewEditing : Page.Model -> Html Page.Msg
viewEditing model =
    let
        isValid =
            ValidatedInput.isValid model.nickname && ValidatedInput.isValid model.email

        enterAction =
            MaybeUtil.optional isValid <| onEnter Page.Request
    in
    div [ Style.classes.request ]
        [ div [] [ label [ Style.classes.info ] [ text "Registration" ] ]
        , table []
            [ tbody []
                [ tr []
                    [ td [] [ label [] [ text "Nickname" ] ]
                    , td []
                        [ input
                            ([ MaybeUtil.defined <|
                                onInput <|
                                    flip (ValidatedInput.lift LensUtil.identityLens).set model.nickname
                                        >> Page.SetNickname
                             , MaybeUtil.defined <| Style.classes.editable
                             , enterAction
                             ]
                                |> Maybe.Extra.values
                            )
                            []
                        ]
                    ]
                , tr []
                    [ td [] [ label [] [ text "Email" ] ]
                    , td []
                        [ input
                            ([ MaybeUtil.defined <|
                                onInput <|
                                    flip (ValidatedInput.lift LensUtil.identityLens).set model.email
                                        >> Page.SetEmail
                             , MaybeUtil.defined <| Style.classes.editable
                             , enterAction
                             ]
                                |> Maybe.Extra.values
                            )
                            []
                        ]
                    ]
                ]
            ]
        , div []
            [ button
                [ onClick Page.Request
                , Style.classes.button.confirm
                , disabled <| not <| isValid
                ]
                [ text "Register" ]
            ]
        ]


viewConfirmed : Page.Model -> Html Page.Msg
viewConfirmed model =
    div [ Style.classes.confirm ]
        [ div [] [ label [] [ text "Registration requested. Please check your email to continue." ] ]
        , div []
            [ Links.toLoginButton
                { configuration = model.configuration
                , buttonText = "Main page"
                }
            ]
        ]
