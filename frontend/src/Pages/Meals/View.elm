module Pages.Meals.View exposing (editMealLineWith, mealLineWith, tableHeader, view)

import Addresses.Frontend
import Api.Types.Meal exposing (Meal)
import Api.Types.SimpleDate exposing (SimpleDate)
import Basics.Extra exposing (flip)
import Configuration exposing (Configuration)
import Html exposing (Attribute, Html, button, input, label, table, td, text, th, tr)
import Html.Attributes exposing (colspan, disabled, type_, value)
import Html.Events exposing (onClick, onInput)
import Html.Events.Extra exposing (onEnter)
import Maybe.Extra
import Monocle.Compose as Compose
import Monocle.Lens exposing (Lens)
import Monocle.Optional exposing (Optional)
import Pages.Meals.MealCreationClientInput as MealCreationClientInput exposing (MealCreationClientInput)
import Pages.Meals.MealUpdateClientInput as MealUpdateClientInput exposing (MealUpdateClientInput)
import Pages.Meals.Page as Page
import Pages.Util.DateUtil as DateUtil
import Pages.Util.HtmlUtil as HtmlUtil
import Pages.Util.Links as Links
import Pages.Util.ParentEditor.Page
import Pages.Util.ParentEditor.View
import Pages.Util.SimpleDateInput as SimpleDateInput exposing (SimpleDateInput)
import Pages.Util.Style as Style
import Pages.Util.ViewUtil as ViewUtil
import Pages.View.Tristate as Tristate
import Parser
import Util.MaybeUtil as MaybeUtil
import Util.SearchUtil as SearchUtil


view : Page.Model -> Html Page.Msg
view =
    Tristate.view
        { viewMain = viewMain
        , showLoginRedirect = True
        }


viewMain : Configuration -> Page.Main -> Html Page.LogicMsg
viewMain =
    Pages.Util.ParentEditor.View.viewParentsWith
        { currentPage = ViewUtil.Meals
        , matchesSearchText =
            \string meal ->
                SearchUtil.search string (meal.name |> Maybe.withDefault "")
                    || SearchUtil.search string (meal.date |> DateUtil.toString)
        , sort = List.sortBy (.original >> .date >> DateUtil.toString) >> List.reverse
        , tableHeader = tableHeader
        , viewLine = viewMealLine
        , updateLine = \_ -> updateMealLine
        , deleteLine = deleteMealLine
        , create =
            { ifCreating = createMealLine
            , default = MealCreationClientInput.default
            , label = "New meal"
            }
        , styling = Style.ids.addMealView
        }


tableHeader : Html msg
tableHeader =
    Pages.Util.ParentEditor.View.tableHeaderWith
        { columns =
            [ th [] [ label [] [ text "Date" ] ]
            , th [] [ label [] [ text "Time" ] ]
            , th [] [ label [] [ text "Name" ] ]
            ]
        , style = Style.classes.mealEditTable
        }


viewMealLine : Configuration -> Meal -> Bool -> List (Html Page.LogicMsg)
viewMealLine configuration meal showControls =
    mealLineWith
        { controls =
            [ td [ Style.classes.controls ] [ button [ Style.classes.button.edit, onClick <| Pages.Util.ParentEditor.Page.EnterEdit <| meal.id ] [ text "Edit" ] ]
            , td [ Style.classes.controls ]
                [ Links.linkButton
                    { url = Links.frontendPage configuration <| Addresses.Frontend.mealEntryEditor.address <| meal.id
                    , attributes = [ Style.classes.button.editor ]
                    , children = [ text "Entries" ]
                    }
                ]
            , td [ Style.classes.controls ]
                [ button [ Style.classes.button.delete, onClick <| Pages.Util.ParentEditor.Page.RequestDelete <| meal.id ] [ text "Delete" ] ]
            , td [ Style.classes.controls ]
                [ Links.linkButton
                    { url = Links.frontendPage configuration <| Addresses.Frontend.statisticsMealSelect.address <| meal.id
                    , attributes = [ Style.classes.button.nutrients ]
                    , children = [ text "Nutrients" ]
                    }
                ]
            ]
        , toggleMsg = Pages.Util.ParentEditor.Page.ToggleControls meal.id
        , showControls = showControls
        }
        meal


deleteMealLine : Meal -> List (Html Page.LogicMsg)
deleteMealLine meal =
    mealLineWith
        { controls =
            [ td [ Style.classes.controls ]
                [ button [ Style.classes.button.delete, onClick <| Pages.Util.ParentEditor.Page.ConfirmDelete meal.id ] [ text "Delete?" ] ]
            , td [ Style.classes.controls ]
                [ button [ Style.classes.button.confirm, onClick <| Pages.Util.ParentEditor.Page.CancelDelete meal.id ] [ text "Cancel" ] ]
            ]
        , toggleMsg = Pages.Util.ParentEditor.Page.ToggleControls meal.id
        , showControls = True
        }
        meal


mealInfoColumns : Meal -> List (HtmlUtil.Column msg)
mealInfoColumns meal =
    [ { attributes = [ Style.classes.editable ]
      , children = [ label [] [ text <| DateUtil.dateToPrettyString <| meal.date.date ] ]
      }
    , { attributes = [ Style.classes.editable ]
      , children = [ label [] [ text <| Maybe.Extra.unwrap "" DateUtil.timeToString <| meal.date.time ] ]
      }
    , { attributes = [ Style.classes.editable ]
      , children = [ label [] [ text <| Maybe.withDefault "" <| meal.name ] ]
      }
    ]


mealLineWith :
    { controls : List (Html msg)
    , toggleMsg : msg
    , showControls : Bool
    }
    -> Meal
    -> List (Html msg)
mealLineWith ps =
    Pages.Util.ParentEditor.View.lineWith
        { rowWithControls =
            \meal ->
                { display = mealInfoColumns meal
                , controls = ps.controls
                }
        , toggleMsg = ps.toggleMsg
        , showControls = ps.showControls
        }


updateMealLine : MealUpdateClientInput -> List (Html Page.LogicMsg)
updateMealLine mealUpdateClientInput =
    editMealLineWith
        { saveMsg = Pages.Util.ParentEditor.Page.SaveEdit mealUpdateClientInput.id
        , dateLens = MealUpdateClientInput.lenses.date
        , setDate = True
        , nameLens = MealUpdateClientInput.lenses.name
        , updateMsg = Pages.Util.ParentEditor.Page.Edit
        , confirmName = "Save"
        , cancelMsg = Pages.Util.ParentEditor.Page.ExitEdit mealUpdateClientInput.id
        , cancelName = "Cancel"
        , rowStyles = [ Style.classes.editLine ]
        , toggleCommand = Pages.Util.ParentEditor.Page.ToggleControls mealUpdateClientInput.id |> Just
        }
        mealUpdateClientInput


createMealLine : MealCreationClientInput -> List (Html Page.LogicMsg)
createMealLine mealCreation =
    editMealLineWith
        { saveMsg = Pages.Util.ParentEditor.Page.Create
        , dateLens = MealCreationClientInput.lenses.date
        , setDate = False
        , nameLens = MealCreationClientInput.lenses.name
        , updateMsg = Just >> Pages.Util.ParentEditor.Page.UpdateCreation
        , confirmName = "Add"
        , cancelMsg = Pages.Util.ParentEditor.Page.UpdateCreation Nothing
        , cancelName = "Cancel"
        , rowStyles = [ Style.classes.editLine ]
        , toggleCommand = Nothing
        }
        mealCreation


editMealLineWith :
    { saveMsg : msg
    , dateLens : Lens editedValue SimpleDateInput
    , setDate : Bool
    , nameLens : Optional editedValue String
    , updateMsg : editedValue -> msg
    , confirmName : String
    , cancelMsg : msg
    , cancelName : String
    , rowStyles : List (Attribute msg)
    , toggleCommand : Maybe msg
    }
    -> editedValue
    -> List (Html msg)
editMealLineWith handling editedValue =
    let
        date =
            handling.dateLens.get <| editedValue

        deepDateLens =
            handling.dateLens
                |> Compose.lensWithLens SimpleDateInput.lenses.date

        deepTimeLens =
            handling.dateLens
                |> Compose.lensWithLens SimpleDateInput.lenses.time

        dateValue =
            date
                |> .date
                |> Maybe.Extra.filter (\_ -> handling.setDate)
                |> Maybe.map (DateUtil.dateToPrettyString >> value)
                |> Maybe.Extra.toList

        dateParsedInteraction =
            Parser.run DateUtil.dateParser
                >> Result.toMaybe
                >> flip
                    deepDateLens.set
                    editedValue
                >> handling.updateMsg

        validatedSaveAction =
            MaybeUtil.optional (deepDateLens.get editedValue |> Maybe.Extra.isJust) <| onEnter handling.saveMsg

        timeValue =
            date
                |> .time
                |> Maybe.Extra.filter (\_ -> handling.setDate)
                |> Maybe.map (DateUtil.timeToString >> value)
                |> Maybe.Extra.toList

        timeInteraction =
            Parser.run DateUtil.timeParser
                >> Result.toMaybe
                >> flip
                    deepTimeLens.set
                    editedValue
                >> handling.updateMsg

        name =
            Maybe.withDefault "" <| handling.nameLens.getOption <| editedValue

        validInput =
            Maybe.Extra.isJust <| date.date

        -- todo: Check back, whether it is sensible to extract this block (cf. same block for recipes).
        controlsRow =
            tr []
                [ td [ colspan 3 ]
                    [ table [ Style.classes.elementsWithControlsTable ]
                        [ tr []
                            [ td [ Style.classes.controls ]
                                [ button
                                    ([ MaybeUtil.defined <| Style.classes.button.confirm
                                     , MaybeUtil.defined <| disabled <| not <| validInput
                                     , MaybeUtil.optional validInput <| onClick handling.saveMsg
                                     ]
                                        |> Maybe.Extra.values
                                    )
                                    [ text handling.confirmName ]
                                ]
                            , td [ Style.classes.controls ]
                                [ button [ Style.classes.button.cancel, onClick handling.cancelMsg ]
                                    [ text handling.cancelName ]
                                ]
                            ]
                        ]
                    ]
                ]

        commandToggle =
            handling.toggleCommand
                |> Maybe.Extra.unwrap []
                    (HtmlUtil.toggleControlsCell >> List.singleton)
    in
    [ tr handling.rowStyles
        ([ td [ Style.classes.editable, Style.classes.date ]
            [ input
                ([ type_ "date"
                 , Style.classes.date
                 , onInput dateParsedInteraction
                 , HtmlUtil.onEscape handling.cancelMsg
                 ]
                    ++ dateValue
                )
                []
            ]
         , td [ Style.classes.editable, Style.classes.time ]
            [ input
                ([ type_ "time"
                 , Style.classes.time
                 , onInput timeInteraction
                 , HtmlUtil.onEscape handling.cancelMsg
                 ]
                    ++ timeValue
                )
                []
            ]
         , td [ Style.classes.editable ]
            [ input
                ([ MaybeUtil.defined <| value <| name
                 , MaybeUtil.defined <|
                    onInput <|
                        flip handling.nameLens.set editedValue
                            >> handling.updateMsg
                 , MaybeUtil.defined <| HtmlUtil.onEscape handling.cancelMsg
                 , validatedSaveAction
                 ]
                    |> Maybe.Extra.values
                )
                []
            ]
         ]
            ++ commandToggle
        )
    , controlsRow
    ]
