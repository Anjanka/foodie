module Pages.MealEntries.View exposing (view)

import Api.Types.MealEntry exposing (MealEntry)
import Api.Types.Recipe exposing (Recipe)
import Basics.Extra exposing (flip)
import Dict
import Either
import Html exposing (Html, button, col, colgroup, div, input, label, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (colspan, disabled, scope, value)
import Html.Attributes.Extra exposing (stringProperty)
import Html.Events exposing (onClick, onInput)
import Html.Events.Extra exposing (onEnter)
import Maybe.Extra
import Pages.MealEntries.MealEntryCreationClientInput as MealEntryCreationClientInput exposing (MealEntryCreationClientInput)
import Pages.MealEntries.MealEntryUpdateClientInput as MealEntryUpdateClientInput exposing (MealEntryUpdateClientInput)
import Pages.MealEntries.Page as Page exposing (RecipeMap)
import Pages.MealEntries.Status as Status
import Pages.Util.DateUtil as DateUtil
import Pages.Util.DictUtil as DictUtil
import Pages.Util.HtmlUtil as HtmlUtil
import Pages.Util.Style as Style
import Pages.Util.ValidatedInput as ValidatedInput
import Pages.Util.ViewUtil as ViewUtil
import Util.Editing as Editing
import Util.SearchUtil as SearchUtil


view : Page.Model -> Html Page.Msg
view model =
    ViewUtil.viewWithErrorHandling
        { isFinished = Status.isFinished
        , initialization = .initialization
        , flagsWithJWT = .flagsWithJWT
        , currentPage = Nothing
        }
        model
    <|
        let
            viewEditMealEntries =
                List.map
                    (Either.unpack
                        (editOrDeleteMealEntryLine model.recipes)
                        (\e -> e.update |> editMealEntryLine model.recipes e.original)
                    )

            viewRecipes searchString =
                model.recipes
                    |> Dict.filter (\_ v -> SearchUtil.search searchString v.name)
                    |> Dict.values
                    |> List.sortBy .name
                    |> List.map (viewRecipeLine model.mealEntriesToAdd model.mealEntries)

            anySelection =
                model.mealEntriesToAdd
                    |> Dict.isEmpty
                    |> not

            numberOfServings =
                if anySelection then
                    "Servings"

                else
                    ""
        in
        div [ Style.ids.mealEntryEditor ]
            [ div []
                [ table [ Style.classes.info ]
                    [ tr []
                        [ td [ Style.classes.descriptionColumn ] [ label [] [ text "Date" ] ]
                        , td [] [ label [] [ text <| Maybe.Extra.unwrap "" (.date >> DateUtil.toString) <| model.mealInfo ] ]
                        ]
                    , tr []
                        [ td [ Style.classes.descriptionColumn ] [ label [] [ text "Name" ] ]
                        , td [] [ label [] [ text <| Maybe.withDefault "" <| Maybe.andThen .name <| model.mealInfo ] ]
                        ]
                    ]
                ]
            , div [ Style.classes.elements ] [ label [] [ text "Dishes" ] ]
            , div [ Style.classes.choices ]
                [ table []
                    [ colgroup []
                        [ col [] []
                        , col [] []
                        , col [] []
                        , col [ stringProperty "span" "2" ] []
                        ]
                    , thead []
                        [ tr []
                            [ th [ scope "col" ] [ label [] [ text "Name" ] ]
                            , th [ scope "col" ] [ label [] [ text "Description" ] ]
                            , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text "Servings" ] ]
                            , th [ colspan 2, scope "colgroup", Style.classes.controlsGroup ] []
                            ]
                        ]
                    , tbody []
                        (viewEditMealEntries
                            (model.mealEntries
                                |> Dict.values
                                |> List.sortBy (Editing.field .recipeId >> Page.recipeNameOrEmpty model.recipes >> String.toLower)
                            )
                        )
                    ]
                ]
            , div [ Style.classes.addView ]
                [ div [ Style.classes.addElement ]
                    [ HtmlUtil.searchAreaWith
                        { msg = Page.SetRecipesSearchString
                        , searchString = model.recipesSearchString
                        }
                    , table [ Style.classes.choiceTable ]
                        [ colgroup []
                            [ col [] []
                            , col [] []
                            , col [] []
                            , col [ stringProperty "span" "2" ] []
                            ]
                        , thead []
                            [ tr [ Style.classes.tableHeader ]
                                [ th [ scope "col" ] [ label [] [ text "Name" ] ]
                                , th [ scope "col" ] [ label [] [ text "Description" ] ]
                                , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text numberOfServings ] ]
                                , th [ colspan 2, scope "colgroup", Style.classes.controlsGroup ] []
                                ]
                            ]
                        , tbody [] (viewRecipes model.recipesSearchString)
                        ]
                    ]
                ]
            ]


editOrDeleteMealEntryLine : Page.RecipeMap -> MealEntry -> Html Page.Msg
editOrDeleteMealEntryLine recipeMap mealEntry =
    tr [ Style.classes.editing ]
        [ td [ Style.classes.editable ] [ label [] [ text <| Page.recipeNameOrEmpty recipeMap <| mealEntry.recipeId ] ]
        , td [ Style.classes.editable ] [ label [] [ text <| Page.descriptionOrEmpty recipeMap <| mealEntry.recipeId ] ]
        , td [ Style.classes.editable, Style.classes.numberLabel ] [ label [] [ text <| String.fromFloat <| mealEntry.numberOfServings ] ]
        , td [ Style.classes.controls ] [ button [ Style.classes.button.edit, onClick (Page.EnterEditMealEntry mealEntry.id) ] [ text "Edit" ] ]
        , td [ Style.classes.controls ] [ button [ Style.classes.button.delete, onClick (Page.DeleteMealEntry mealEntry.id) ] [ text "Delete" ] ]
        ]


editMealEntryLine : Page.RecipeMap -> MealEntry -> MealEntryUpdateClientInput -> Html Page.Msg
editMealEntryLine recipeMap mealEntry mealEntryUpdateClientInput =
    tr [ Style.classes.editLine ]
        [ td [] [ label [] [ text <| Page.recipeNameOrEmpty recipeMap <| mealEntry.recipeId ] ]
        , td [] [ label [] [ text <| Page.descriptionOrEmpty recipeMap <| mealEntry.recipeId ] ]
        , td [ Style.classes.numberCell ]
            [ input
                [ value
                    (mealEntryUpdateClientInput.numberOfServings.value
                        |> String.fromFloat
                    )
                , onInput
                    (flip
                        (ValidatedInput.lift
                            MealEntryUpdateClientInput.lenses.numberOfServings
                        ).set
                        mealEntryUpdateClientInput
                        >> Page.UpdateMealEntry
                    )
                , onEnter (Page.SaveMealEntryEdit mealEntryUpdateClientInput)
                , Style.classes.numberLabel
                ]
                []
            ]
        , td []
            [ button [ Style.classes.button.confirm, onClick (Page.SaveMealEntryEdit mealEntryUpdateClientInput) ]
                [ text "Save" ]
            ]
        , td []
            [ button [ Style.classes.button.cancel, onClick (Page.ExitEditMealEntryAt mealEntry.id) ]
                [ text "Cancel" ]
            ]
        ]


viewRecipeLine : Page.AddMealEntriesMap -> Page.MealEntryOrUpdateMap -> Recipe -> Html Page.Msg
viewRecipeLine mealEntriesToAdd mealEntries recipe =
    let
        addMsg =
            Page.AddRecipe recipe.id

        process =
            case Dict.get recipe.id mealEntriesToAdd of
                Nothing ->
                    [ td [ Style.classes.editable, Style.classes.numberCell ] []
                    , td [ Style.classes.controls ] []
                    , td [ Style.classes.controls ] [ button [ Style.classes.button.select, onClick (Page.SelectRecipe recipe.id) ] [ text "Select" ] ]
                    ]

                Just mealEntryToAdd ->
                    let
                        ( confirmName, confirmMsg ) =
                            case DictUtil.firstSuch (\mealEntry -> Editing.field .recipeId mealEntry == mealEntryToAdd.recipeId) mealEntries of
                                Nothing ->
                                    ( "Add", addMsg )

                                Just mealEntryOrUpdate ->
                                    let
                                        mealEntry =
                                            Editing.field identity mealEntryOrUpdate
                                    in
                                    ( "Update"
                                    , mealEntry
                                        |> MealEntryUpdateClientInput.from
                                        |> MealEntryUpdateClientInput.lenses.numberOfServings.set mealEntryToAdd.numberOfServings
                                        |> Page.SaveMealEntryEdit
                                    )
                    in
                    [ td [ Style.classes.numberCell ]
                        [ input
                            [ value mealEntryToAdd.numberOfServings.text
                            , onInput
                                (flip
                                    (ValidatedInput.lift
                                        MealEntryCreationClientInput.lenses.numberOfServings
                                    ).set
                                    mealEntryToAdd
                                    >> Page.UpdateAddRecipe
                                )
                            , onEnter confirmMsg
                            , Style.classes.numberLabel
                            ]
                            []
                        ]
                    , td [ Style.classes.controls ]
                        [ button
                            [ Style.classes.button.confirm
                            , disabled
                                (mealEntryToAdd.numberOfServings |> ValidatedInput.isValid |> not)
                            , onClick confirmMsg
                            ]
                            [ text confirmName ]
                        ]
                    , td [ Style.classes.controls ] [ button [ Style.classes.button.cancel, onClick (Page.DeselectRecipe recipe.id) ] [ text "Cancel" ] ]
                    ]
    in
    tr [ Style.classes.editing ]
        (td [] [ label [] [ text recipe.name ] ]
            :: td [] [ label [] [ text <| Maybe.withDefault "" <| recipe.description ] ]
            :: process
        )
