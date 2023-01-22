module Pages.Ingredients.View exposing (view)

import Addresses.Frontend
import Api.Auxiliary exposing (ComplexFoodId, FoodId, IngredientId, JWT, MeasureId, RecipeId)
import Api.Types.AmountUnit exposing (AmountUnit)
import Api.Types.ComplexFood exposing (ComplexFood)
import Api.Types.ComplexFoodUnit as ComplexFoodUnit
import Api.Types.ComplexIngredient exposing (ComplexIngredient)
import Api.Types.Food exposing (Food)
import Api.Types.Ingredient exposing (Ingredient)
import Api.Types.Measure exposing (Measure)
import Basics.Extra exposing (flip)
import Configuration exposing (Configuration)
import Dict exposing (Dict)
import Dropdown exposing (Item, dropdown)
import Html exposing (Attribute, Html, button, col, colgroup, div, input, label, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (colspan, disabled, scope, value)
import Html.Attributes.Extra exposing (stringProperty)
import Html.Events exposing (onClick, onInput)
import Html.Events.Extra exposing (onEnter)
import List.Extra
import Maybe.Extra
import Monocle.Compose as Compose
import Monocle.Lens exposing (Lens)
import Pages.Ingredients.AmountUnitClientInput as AmountUnitClientInput
import Pages.Ingredients.ComplexIngredientClientInput as ComplexIngredientClientInput exposing (ComplexIngredientClientInput)
import Pages.Ingredients.FoodGroup as FoodGroup exposing (FoodGroup, IngredientState)
import Pages.Ingredients.IngredientCreationClientInput as IngredientCreationClientInput exposing (IngredientCreationClientInput)
import Pages.Ingredients.IngredientUpdateClientInput as IngredientUpdateClientInput exposing (IngredientUpdateClientInput)
import Pages.Ingredients.Page as Page
import Pages.Ingredients.Pagination as Pagination exposing (Pagination)
import Pages.Ingredients.Status as Status
import Pages.Recipes.RecipeUpdateClientInput as RecipeUpdateClientInput
import Pages.Recipes.View
import Pages.Util.DictUtil as DictUtil
import Pages.Util.HtmlUtil as HtmlUtil
import Pages.Util.Links as Links
import Pages.Util.PaginationSettings as PaginationSettings
import Pages.Util.Style as Style
import Pages.Util.ValidatedInput as ValidatedInput
import Pages.Util.ViewUtil as ViewUtil
import Paginate exposing (PaginatedList)
import Util.Editing as Editing
import Util.MaybeUtil as MaybeUtil
import Util.SearchUtil as SearchUtil


view : Page.Model -> Html Page.Msg
view model =
    ViewUtil.viewWithErrorHandling
        { isFinished = Status.isFinished
        , initialization = .initialization
        , configuration = .authorizedAccess >> .configuration
        , jwt = .authorizedAccess >> .jwt >> Just
        , currentPage = Nothing
        , showNavigation = True
        }
        model
    <|
        let
            viewIngredientState =
                Editing.unpack
                    { onView = viewIngredientLine model.ingredientsGroup.foods
                    , onUpdate = updateIngredientLine model.ingredientsGroup.foods
                    , onDelete = deleteIngredientLine model.ingredientsGroup.foods
                    }

            viewComplexIngredientState =
                Editing.unpack
                    { onView = viewComplexIngredientLine model.complexIngredientsGroup.foods
                    , onUpdate = updateComplexIngredientLine model.complexIngredientsGroup.foods
                    , onDelete = deleteComplexIngredientLine model.complexIngredientsGroup.foods
                    }

            viewIngredientsWith :
                (IngredientState ingredient update -> Bool)
                -> Lens Page.Model (FoodGroup comparableIngredientId ingredient update comparableFoodId food creation)
                -> (ingredient -> comparableFoodId)
                -> Dict comparableFoodId { a | name : String }
                -> PaginatedList (IngredientState ingredient update)
            viewIngredientsWith searchFilter groupLens idOf nameMap =
                model
                    |> groupLens.get
                    |> .ingredients
                    |> Dict.filter (\_ v -> searchFilter v)
                    |> Dict.values
                    |> List.sortBy (.original >> idOf >> DictUtil.nameOrEmpty nameMap >> String.toLower)
                    |> ViewUtil.paginate
                        { pagination =
                            groupLens
                                |> Compose.lensWithLens FoodGroup.lenses.pagination
                                |> Compose.lensWithLens Pagination.lenses.ingredients
                        }
                        model

            viewIngredients =
                viewIngredientsWith
                    (.original
                        >> .foodId
                        >> DictUtil.nameOrEmpty model.ingredientsGroup.foods
                        >> SearchUtil.search model.ingredientsSearchString
                    )
                    Page.lenses.ingredientsGroup
                    .foodId
                    model.ingredientsGroup.foods

            viewComplexIngredients =
                viewIngredientsWith
                    (.original
                        >> .complexFoodId
                        >> (\id -> complexFoodInfo id model.complexIngredientsGroup.foods)
                        >> .name
                        >> SearchUtil.search model.complexIngredientsSearchString
                    )
                    Page.lenses.complexIngredientsGroup
                    .complexFoodId
                    model.complexIngredientsGroup.foods

            viewRecipe =
                Editing.unpack
                    { onView =
                        Pages.Recipes.View.recipeLineWith
                            { controls =
                                [ td [ Style.classes.controls ]
                                    [ button [ Style.classes.button.edit, Page.EnterEditRecipe |> onClick ] [ text "Edit" ] ]
                                , td [ Style.classes.controls ]
                                    [ button
                                        [ Style.classes.button.delete, Page.RequestDeleteRecipe |> onClick ]
                                        [ text "Delete" ]
                                    ]
                                , td [ Style.classes.controls ]
                                    [ Links.linkButton
                                        { url = Links.frontendPage model.authorizedAccess.configuration <| Addresses.Frontend.statisticsRecipeSelect.address <| model.recipe.original.id
                                        , attributes = [ Style.classes.button.nutrients ]
                                        , children = [ text "Nutrients" ]
                                        }
                                    ]
                                ]
                            , onClick = [ Page.EnterEditRecipe |> onClick ]
                            , styles = []
                            }
                    , onUpdate =
                        Pages.Recipes.View.editRecipeLineWith
                            { saveMsg = Page.SaveRecipeEdit
                            , nameLens = RecipeUpdateClientInput.lenses.name
                            , descriptionLens = RecipeUpdateClientInput.lenses.description
                            , numberOfServingsLens = RecipeUpdateClientInput.lenses.numberOfServings
                            , updateMsg = Page.UpdateRecipe
                            , confirmName = "Save"
                            , cancelMsg = Page.ExitEditRecipe
                            , cancelName = "Cancel"
                            , rowStyles = [  ]
                            }
                            |> always
                    , onDelete =
                        Pages.Recipes.View.recipeLineWith
                            { controls =
                                [ td [ Style.classes.controls ]
                                    [ button [ Style.classes.button.delete, onClick <| Page.ConfirmDeleteRecipe ] [ text "Delete?" ] ]
                                , td [ Style.classes.controls ]
                                    [ button
                                        [ Style.classes.button.confirm, onClick <| Page.CancelDeleteRecipe ]
                                        [ text "Cancel" ]
                                    ]
                                ]
                            , onClick = []
                            , styles = []
                            }
                    }
                    model.recipe
        in
        div [ Style.ids.ingredientEditor ]
            [ div []
                [ table [ Style.classes.elementsWithControlsTable ]
                    (Pages.Recipes.View.tableHeader { controlButtons = 3 }
                        ++ [ tbody [] [ viewRecipe ]
                           ]
                    )
                ]
            , div [ Style.classes.elements ] [ label [] [ text "Ingredients" ] ]
            , div [ Style.classes.choices ]
                [ HtmlUtil.searchAreaWith
                    { msg = Page.SetIngredientsSearchString
                    , searchString = model.ingredientsSearchString
                    }
                , table [ Style.classes.elementsWithControlsTable ]
                    [ colgroup []
                        [ col [] []
                        , col [] []
                        , col [] []
                        , col [ stringProperty "span" "2" ] []
                        ]
                    , thead []
                        [ tr [ Style.classes.tableHeader ]
                            [ th [ scope "col" ] [ label [] [ text "Name" ] ]
                            , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text "Amount" ] ]
                            , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text "Unit" ] ]
                            , th [ colspan 2, scope "colgroup", Style.classes.controlsGroup ] []
                            ]
                        ]
                    , tbody []
                        (viewIngredients
                            |> Paginate.page
                            |> List.map viewIngredientState
                        )
                    ]
                , div [ Style.classes.pagination ]
                    [ ViewUtil.pagerButtons
                        { msg =
                            PaginationSettings.updateCurrentPage
                                { pagination = Page.lenses.ingredientsGroup |> Compose.lensWithLens FoodGroup.lenses.pagination
                                , items = Pagination.lenses.ingredients
                                }
                                model
                                >> Page.SetIngredientsPagination
                        , elements = viewIngredients
                        }
                    ]
                ]
            , div [ Style.classes.elements ] [ label [] [ text "Complex ingredients" ] ]
            , div [ Style.classes.choices ]
                [ HtmlUtil.searchAreaWith
                    { msg = Page.SetComplexIngredientsSearchString
                    , searchString = model.complexIngredientsSearchString
                    }
                , table [ Style.classes.elementsWithControlsTable ]
                    [ colgroup []
                        [ col [] []
                        , col [] []
                        , col [] []
                        , col [ stringProperty "span" "2" ] []
                        ]
                    , thead []
                        [ tr [ Style.classes.tableHeader ]
                            [ th [ scope "col" ] [ label [] [ text "Name" ] ]
                            , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text "Factor" ] ]
                            , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text "Amount" ] ]
                            , th [ colspan 2, scope "colgroup", Style.classes.controlsGroup ] []
                            ]
                        ]
                    , tbody []
                        (viewComplexIngredients
                            |> Paginate.page
                            |> List.map viewComplexIngredientState
                        )
                    ]
                , div [ Style.classes.pagination ]
                    [ ViewUtil.pagerButtons
                        { msg =
                            PaginationSettings.updateCurrentPage
                                { pagination = Page.lenses.complexIngredientsGroup |> Compose.lensWithLens FoodGroup.lenses.pagination
                                , items = Pagination.lenses.ingredients
                                }
                                model
                                >> Page.SetComplexIngredientsPagination
                        , elements = viewComplexIngredients
                        }
                    ]
                ]
            , div []
                [ button
                    [ disabled <| model.foodsMode == Page.Plain
                    , onClick <| Page.ChangeFoodsMode Page.Plain
                    , Style.classes.button.alternative
                    ]
                    [ text "Ingredients" ]
                , button
                    [ disabled <| model.foodsMode == Page.Complex
                    , onClick <| Page.ChangeFoodsMode Page.Complex
                    , Style.classes.button.alternative
                    ]
                    [ text "Complex ingredients" ]
                ]
            , case model.foodsMode of
                Page.Plain ->
                    viewPlain model

                Page.Complex ->
                    viewComplex model
            ]


viewPlain : Page.Model -> Html Page.Msg
viewPlain model =
    let
        viewFoods =
            model.ingredientsGroup.foods
                |> Dict.filter (\_ v -> SearchUtil.search model.ingredientsGroup.foodsSearchString v.name)
                |> Dict.values
                |> List.sortBy .name
                |> ViewUtil.paginate
                    { pagination =
                        Page.lenses.ingredientsGroup
                            |> Compose.lensWithLens FoodGroup.lenses.pagination
                            |> Compose.lensWithLens Pagination.lenses.foods
                    }
                    model

        ( amount, unit ) =
            if anySelection Page.lenses.ingredientsGroup model then
                ( "Amount", "Unit" )

            else
                ( "", "" )
    in
    div [ Style.classes.addView ]
        [ div [ Style.classes.addElement ]
            [ HtmlUtil.searchAreaWith
                { msg = Page.SetFoodsSearchString
                , searchString = model.ingredientsGroup.foodsSearchString
                }
            , table [ Style.classes.elementsWithControlsTable ]
                [ colgroup []
                    [ col [] []
                    , col [] []
                    , col [] []
                    , col [ stringProperty "span" "2" ] []
                    ]
                , thead []
                    [ tr [ Style.classes.tableHeader ]
                        [ th [ scope "col" ] [ label [] [ text "Name" ] ]
                        , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text amount ] ]
                        , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text unit ] ]
                        , th [ colspan 2, scope "colgroup", Style.classes.controlsGroup ] []
                        ]
                    ]
                , tbody []
                    (viewFoods
                        |> Paginate.page
                        |> List.map (viewFoodLine model.authorizedAccess.configuration model.ingredientsGroup.foods model.ingredientsGroup.foodsToAdd model.ingredientsGroup.ingredients)
                    )
                ]
            , div [ Style.classes.pagination ]
                [ ViewUtil.pagerButtons
                    { msg =
                        PaginationSettings.updateCurrentPage
                            { pagination = Page.lenses.ingredientsGroup |> Compose.lensWithLens FoodGroup.lenses.pagination
                            , items = Pagination.lenses.foods
                            }
                            model
                            >> Page.SetIngredientsPagination
                    , elements = viewFoods
                    }
                ]
            ]
        ]


viewComplex : Page.Model -> Html Page.Msg
viewComplex model =
    let
        viewComplexFoods =
            model.complexIngredientsGroup.foods
                |> Dict.filter (\_ v -> SearchUtil.search model.complexIngredientsGroup.foodsSearchString v.name)
                |> Dict.values
                |> List.sortBy .name
                |> ViewUtil.paginate
                    { pagination =
                        Page.lenses.complexIngredientsGroup
                            |> Compose.lensWithLens FoodGroup.lenses.pagination
                            |> Compose.lensWithLens Pagination.lenses.foods
                    }
                    model

        ( amount, unit ) =
            if anySelection Page.lenses.complexIngredientsGroup model then
                ( "Factor", "Amount" )

            else
                ( "", "" )
    in
    div [ Style.classes.addView ]
        [ div [ Style.classes.addElement ]
            [ HtmlUtil.searchAreaWith
                { msg = Page.SetComplexFoodsSearchString
                , searchString = model.complexIngredientsGroup.foodsSearchString
                }
            , table [ Style.classes.elementsWithControlsTable ]
                [ colgroup []
                    [ col [] []
                    , col [] []
                    , col [] []
                    , col [ stringProperty "span" "2" ] []
                    ]
                , thead []
                    [ tr [ Style.classes.tableHeader ]
                        [ th [ scope "col" ] [ label [] [ text "Name" ] ]
                        , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text amount ] ]
                        , th [ scope "col", Style.classes.numberLabel ] [ label [] [ text unit ] ]
                        , th [ colspan 2, scope "colgroup", Style.classes.controlsGroup ] []
                        ]
                    ]
                , tbody []
                    (viewComplexFoods
                        |> Paginate.page
                        |> List.map (viewComplexFoodLine model.authorizedAccess.configuration model.complexIngredientsGroup.foods model.complexIngredientsGroup.foodsToAdd model.complexIngredientsGroup.ingredients)
                    )
                ]
            , div [ Style.classes.pagination ]
                [ ViewUtil.pagerButtons
                    { msg =
                        PaginationSettings.updateCurrentPage
                            { pagination = Page.lenses.complexIngredientsGroup |> Compose.lensWithLens FoodGroup.lenses.pagination
                            , items = Pagination.lenses.foods
                            }
                            model
                            >> Page.SetComplexIngredientsPagination
                    , elements = viewComplexFoods
                    }
                ]
            ]
        ]


viewIngredientLine : Page.FoodMap -> Ingredient -> Html Page.Msg
viewIngredientLine foodMap ingredient =
    let
        editMsg =
            Page.EnterEditIngredient ingredient.id |> onClick
    in
    ingredientLineWith
        { controls =
            [ td [ Style.classes.controls ] [ button [ Style.classes.button.edit, editMsg ] [ text "Edit" ] ]
            , td [ Style.classes.controls ] [ button [ Style.classes.button.delete, onClick (Page.RequestDeleteIngredient ingredient.id) ] [ text "Delete" ] ]
            ]
        , onClick = [ editMsg ]
        , foodMap = foodMap
        }
        ingredient


deleteIngredientLine : Page.FoodMap -> Ingredient -> Html Page.Msg
deleteIngredientLine foodMap ingredient =
    ingredientLineWith
        { controls =
            [ td [ Style.classes.controls ] [ button [ Style.classes.button.delete, onClick (Page.ConfirmDeleteIngredient ingredient.id) ] [ text "Delete?" ] ]
            , td [ Style.classes.controls ] [ button [ Style.classes.button.confirm, onClick (Page.CancelDeleteIngredient ingredient.id) ] [ text "Cancel" ] ]
            ]
        , onClick = []
        , foodMap = foodMap
        }
        ingredient


measureOfFood : MeasureId -> Food -> Maybe Measure
measureOfFood measureId food =
    food
        |> .measures
        |> List.Extra.find (\measure -> measure.id == measureId)


ingredientLineWith :
    { controls : List (Html Page.Msg)
    , onClick : List (Attribute Page.Msg)
    , foodMap : Page.FoodMap
    }
    -> Ingredient
    -> Html Page.Msg
ingredientLineWith ps ingredient =
    let
        withOnClick =
            (++) ps.onClick

        food =
            Dict.get ingredient.foodId ps.foodMap
    in
    tr [ Style.classes.editing ]
        ([ td ([ Style.classes.editable ] |> withOnClick) [ label [] [ text <| Maybe.Extra.unwrap "" .name <| food ] ]
         , td ([ Style.classes.editable, Style.classes.numberLabel ] |> withOnClick) [ label [] [ text <| String.fromFloat <| ingredient.amountUnit.factor ] ]
         , td ([ Style.classes.editable, Style.classes.numberLabel ] |> withOnClick)
            [ label []
                [ text <|
                    Maybe.Extra.unwrap "" .name <|
                        Maybe.andThen (measureOfFood ingredient.amountUnit.measureId) <|
                            food
                ]
            ]
         ]
            ++ ps.controls
        )


viewComplexIngredientLine : Page.ComplexFoodMap -> ComplexIngredient -> Html Page.Msg
viewComplexIngredientLine complexFoodMap complexIngredient =
    let
        editMsg =
            Page.EnterEditComplexIngredient complexIngredient.complexFoodId |> onClick
    in
    complexIngredientLineWith
        { controls =
            [ td [ Style.classes.controls ] [ button [ Style.classes.button.edit, editMsg ] [ text "Edit" ] ]
            , td [ Style.classes.controls ] [ button [ Style.classes.button.delete, onClick (Page.RequestDeleteComplexIngredient complexIngredient.complexFoodId) ] [ text "Delete" ] ]
            ]
        , onClick = [ editMsg ]
        , complexFoodMap = complexFoodMap
        }
        complexIngredient


deleteComplexIngredientLine : Page.ComplexFoodMap -> ComplexIngredient -> Html Page.Msg
deleteComplexIngredientLine complexFoodMap complexIngredient =
    complexIngredientLineWith
        { controls =
            [ td [ Style.classes.controls ] [ button [ Style.classes.button.edit, onClick (Page.ConfirmDeleteComplexIngredient complexIngredient.complexFoodId) ] [ text "Delete?" ] ]
            , td [ Style.classes.controls ] [ button [ Style.classes.button.delete, onClick (Page.CancelDeleteComplexIngredient complexIngredient.complexFoodId) ] [ text "Cancel" ] ]
            ]
        , onClick = []
        , complexFoodMap = complexFoodMap
        }
        complexIngredient


complexIngredientLineWith :
    { controls : List (Html Page.Msg)
    , onClick : List (Attribute Page.Msg)
    , complexFoodMap : Page.ComplexFoodMap
    }
    -> ComplexIngredient
    -> Html Page.Msg
complexIngredientLineWith ps complexIngredient =
    let
        withOnClick =
            (++) ps.onClick

        info =
            complexFoodInfo complexIngredient.complexFoodId ps.complexFoodMap
    in
    tr [ Style.classes.editing ]
        ([ td ([ Style.classes.editable ] |> withOnClick) [ label [] [ text <| info.name ] ]
         , td ([ Style.classes.editable, Style.classes.numberLabel ] |> withOnClick) [ label [] [ text <| String.fromFloat <| complexIngredient.factor ] ]
         , td ([ Style.classes.editable, Style.classes.numberLabel ] |> withOnClick) [ label [] [ text <| info.amount ] ]
         ]
            ++ ps.controls
        )


updateIngredientLine : Page.FoodMap -> Ingredient -> IngredientUpdateClientInput -> Html Page.Msg
updateIngredientLine foodMap ingredient ingredientUpdateClientInput =
    let
        saveMsg =
            Page.SaveIngredientEdit ingredientUpdateClientInput

        cancelMsg =
            Page.ExitEditIngredientAt ingredient.id

        validInput =
            ingredientUpdateClientInput.amountUnit.factor |> ValidatedInput.isValid

        food =
            Dict.get ingredient.foodId foodMap

        maybeMeasure =
            food
                |> Maybe.andThen
                    (measureOfFood ingredient.amountUnit.measureId)
    in
    tr [ Style.classes.editLine ]
        [ td [] [ label [] [ text <| Maybe.Extra.unwrap "" .name <| food ] ]
        , td [ Style.classes.numberCell ]
            [ input
                [ value
                    ingredientUpdateClientInput.amountUnit.factor.text
                , onInput
                    (flip
                        (ValidatedInput.lift
                            (IngredientUpdateClientInput.lenses.amountUnit
                                |> Compose.lensWithLens AmountUnitClientInput.lenses.factor
                            )
                        ).set
                        ingredientUpdateClientInput
                        >> Page.UpdateIngredient
                    )
                , onEnter saveMsg
                , HtmlUtil.onEscape cancelMsg
                , Style.classes.numberLabel
                ]
                []
            ]
        , td [ Style.classes.numberCell ]
            [ dropdown
                { items = unitDropdown foodMap ingredient.foodId
                , emptyItem =
                    Maybe.map startingDropdownUnit <| maybeMeasure
                , onChange =
                    onChangeDropdown
                        { amountUnitLens = IngredientUpdateClientInput.lenses.amountUnit
                        , measureIdOf = .amountUnit >> .measureId
                        , mkMsg = Page.UpdateIngredient
                        , input = ingredientUpdateClientInput
                        }
                }
                [ Style.classes.numberLabel, HtmlUtil.onEscape cancelMsg ]
                (maybeMeasure
                    |> Maybe.map .name
                )
            ]
        , td []
            [ button
                ([ MaybeUtil.defined <| Style.classes.button.confirm
                 , MaybeUtil.defined <| disabled <| not <| validInput
                 , MaybeUtil.optional validInput <| onClick saveMsg
                 ]
                    |> Maybe.Extra.values
                )
                [ text "Save" ]
            ]
        , td []
            [ button [ Style.classes.button.cancel, onClick cancelMsg ]
                [ text "Cancel" ]
            ]
        ]


updateComplexIngredientLine : Page.ComplexFoodMap -> ComplexIngredient -> ComplexIngredientClientInput -> Html Page.Msg
updateComplexIngredientLine complexFoodMap complexIngredient complexIngredientUpdateClientInput =
    let
        saveMsg =
            Page.SaveComplexIngredientEdit complexIngredientUpdateClientInput

        cancelMsg =
            Page.ExitEditComplexIngredientAt complexIngredient.complexFoodId

        info =
            complexFoodInfo complexIngredient.complexFoodId complexFoodMap
    in
    tr [ Style.classes.editLine ]
        [ td [] [ label [] [ text <| info.name ] ]
        , td [ Style.classes.numberCell ]
            [ input
                [ value
                    complexIngredientUpdateClientInput.factor.text
                , onInput
                    (flip
                        (ValidatedInput.lift
                            ComplexIngredientClientInput.lenses.factor
                        ).set
                        complexIngredientUpdateClientInput
                        >> Page.UpdateComplexIngredient
                    )
                , onEnter saveMsg
                , HtmlUtil.onEscape cancelMsg
                , Style.classes.numberLabel
                ]
                []
            ]
        , td [ Style.classes.numberCell ]
            [ label [ Style.classes.editable, Style.classes.numberLabel ] [ text <| info.amount ]
            ]
        , td []
            [ button [ Style.classes.button.confirm, onClick saveMsg ]
                [ text "Save" ]
            ]
        , td []
            [ button [ Style.classes.button.cancel, onClick cancelMsg ]
                [ text "Cancel" ]
            ]
        ]


unitDropdown : Page.FoodMap -> FoodId -> List Dropdown.Item
unitDropdown fm fId =
    fm
        |> Dict.get fId
        |> Maybe.Extra.unwrap [] .measures
        |> List.map (\m -> { value = String.fromInt m.id, text = m.name, enabled = True })


startingDropdownUnit : Measure -> Dropdown.Item
startingDropdownUnit measure =
    { value = String.fromInt measure.id
    , text = measure.name
    , enabled = True
    }


onChangeDropdown :
    { amountUnitLens : Lens input AmountUnitClientInput.AmountUnitClientInput
    , measureIdOf : input -> MeasureId
    , input : input
    , mkMsg : input -> Page.Msg
    }
    -> Maybe String
    -> Page.Msg
onChangeDropdown ps =
    Maybe.andThen String.toInt
        >> Maybe.withDefault (ps.measureIdOf ps.input)
        >> flip (ps.amountUnitLens |> Compose.lensWithLens AmountUnitClientInput.lenses.measureId).set ps.input
        >> ps.mkMsg


type alias ComplexFoodInfo =
    { name : String
    , amount : String
    }


complexFoodInfo : ComplexFoodId -> Page.ComplexFoodMap -> ComplexFoodInfo
complexFoodInfo complexFoodId complexFoodMap =
    let
        complexFood =
            Dict.get complexFoodId complexFoodMap
    in
    { name = complexFood |> Maybe.Extra.unwrap "" .name
    , amount =
        complexFood
            |> Maybe.Extra.unwrap "" (\cf -> String.concat [ cf.amount |> String.fromFloat, cf.unit |> ComplexFoodUnit.toPrettyString ])
    }


viewFoodLine : Configuration -> Page.FoodMap -> Page.AddFoodsMap -> Page.PlainIngredientStateMap -> Food -> Html Page.Msg
viewFoodLine configuration foodMap ingredientsToAdd ingredients food =
    let
        addMsg =
            Page.AddFood food.id

        selectMsg =
            Page.SelectFood food

        cancelMsg =
            Page.DeselectFood food.id

        maybeIngredientToAdd =
            Dict.get food.id ingredientsToAdd

        rowClickAction =
            if Maybe.Extra.isJust maybeIngredientToAdd then
                []

            else
                [ onClick selectMsg ]

        process =
            case maybeIngredientToAdd of
                Nothing ->
                    [ td [ Style.classes.editable, Style.classes.numberCell ] []
                    , td [ Style.classes.editable, Style.classes.numberCell ] []
                    , td [ Style.classes.controls ] [ button [ Style.classes.button.select, onClick selectMsg ] [ text "Select" ] ]
                    , td [ Style.classes.controls ]
                        [ Links.linkButton
                            { url = Links.frontendPage configuration <| Addresses.Frontend.statisticsFoodSelect.address <| food.id
                            , attributes = [ Style.classes.button.nutrients ]
                            , children = [ text "Nutrients" ]
                            }
                        ]
                    ]

                Just ingredientToAdd ->
                    let
                        validInput =
                            ingredientToAdd.amountUnit.factor |> ValidatedInput.isValid

                        ( confirmName, confirmStyle ) =
                            if DictUtil.existsValue (\ingredient -> ingredient.original.foodId == ingredientToAdd.foodId) ingredients then
                                ( "Add again", Style.classes.button.edit )

                            else
                                ( "Add"
                                , Style.classes.button.confirm
                                )
                    in
                    [ td [ Style.classes.numberCell ]
                        [ input
                            ([ MaybeUtil.defined <| value ingredientToAdd.amountUnit.factor.text
                             , MaybeUtil.defined <|
                                onInput <|
                                    flip
                                        (ValidatedInput.lift
                                            (IngredientCreationClientInput.amountUnit
                                                |> Compose.lensWithLens AmountUnitClientInput.lenses.factor
                                            )
                                        ).set
                                        ingredientToAdd
                                        >> Page.UpdateAddFood
                             , MaybeUtil.defined <| Style.classes.numberLabel
                             , MaybeUtil.defined <| HtmlUtil.onEscape cancelMsg
                             , MaybeUtil.optional validInput <| onEnter addMsg
                             ]
                                |> Maybe.Extra.values
                            )
                            []
                        ]
                    , td [ Style.classes.numberCell ]
                        [ dropdown
                            { items = unitDropdown foodMap food.id
                            , emptyItem = Nothing
                            , onChange =
                                onChangeDropdown
                                    { amountUnitLens = IngredientCreationClientInput.amountUnit
                                    , measureIdOf = .amountUnit >> .measureId
                                    , mkMsg = Page.UpdateAddFood
                                    , input = ingredientToAdd
                                    }
                            }
                            [ Style.classes.numberLabel
                            , HtmlUtil.onEscape cancelMsg
                            ]
                            (ingredientToAdd.amountUnit.measureId |> String.fromInt |> Just)
                        ]
                    , td [ Style.classes.controls ]
                        [ button
                            [ confirmStyle
                            , disabled <| not <| validInput
                            , onClick addMsg
                            ]
                            [ text confirmName
                            ]
                        ]
                    , td [ Style.classes.controls ]
                        [ button [ Style.classes.button.cancel, onClick cancelMsg ] [ text "Cancel" ] ]
                    ]
    in
    tr ([ Style.classes.editing ] ++ rowClickAction)
        (td [ Style.classes.editable ] [ label [] [ text food.name ] ]
            :: process
        )


viewComplexFoodLine : Configuration -> Page.ComplexFoodMap -> Page.AddComplexFoodsMap -> Page.ComplexIngredientStateMap -> ComplexFood -> Html Page.Msg
viewComplexFoodLine configuration complexFoodMap complexIngredientsToAdd complexIngredients complexFood =
    let
        addMsg =
            Page.AddComplexFood complexFood.recipeId

        selectMsg =
            Page.SelectComplexFood complexFood

        cancelMsg =
            Page.DeselectComplexFood complexFood.recipeId

        maybeComplexIngredientToAdd =
            Dict.get complexFood.recipeId complexIngredientsToAdd

        rowClickAction =
            if Maybe.Extra.isJust maybeComplexIngredientToAdd then
                []

            else
                [ onClick selectMsg ]

        info =
            complexFoodInfo complexFood.recipeId complexFoodMap

        process =
            case maybeComplexIngredientToAdd of
                Nothing ->
                    [ td [ Style.classes.editable, Style.classes.numberCell ] []
                    , td [ Style.classes.editable, Style.classes.numberCell ] []
                    , td [ Style.classes.controls ] [ button [ Style.classes.button.select, onClick selectMsg ] [ text "Select" ] ]
                    , td [ Style.classes.controls ]
                        [ Links.linkButton
                            { url = Links.frontendPage configuration <| Addresses.Frontend.statisticsComplexFoodSelect.address <| complexFood.recipeId
                            , attributes = [ Style.classes.button.nutrients ]
                            , children = [ text "Nutrients" ]
                            }
                        ]
                    ]

                Just complexIngredientToAdd ->
                    let
                        exists =
                            DictUtil.existsValue (\complexIngredient -> complexIngredient.original.complexFoodId == complexIngredientToAdd.complexFoodId) complexIngredients

                        validInput =
                            List.all identity
                                [ complexIngredientToAdd.factor |> ValidatedInput.isValid
                                , exists |> not
                                ]

                        ( confirmName, confirmStyle ) =
                            if exists then
                                ( "Added", Style.classes.button.edit )

                            else
                                ( "Add", Style.classes.button.confirm )
                    in
                    [ td [ Style.classes.numberCell ]
                        ([ input
                            [ value complexIngredientToAdd.factor.text
                            , onInput
                                (flip
                                    (ValidatedInput.lift
                                        ComplexIngredientClientInput.lenses.factor
                                    ).set
                                    complexIngredientToAdd
                                    >> Page.UpdateAddComplexFood
                                )
                            , Style.classes.numberLabel
                            , HtmlUtil.onEscape cancelMsg
                            , onEnter addMsg
                            ]
                            []
                         ]
                            |> List.filter (exists |> not |> always)
                        )
                    , td [ Style.classes.editable, Style.classes.numberLabel, onClick selectMsg ] [ label [] [ text <| info.amount ] ]
                    , td [ Style.classes.controls ]
                        [ button
                            ([ MaybeUtil.defined <| confirmStyle
                             , MaybeUtil.defined <| disabled <| not <| validInput
                             , MaybeUtil.optional validInput <| onClick addMsg
                             ]
                                |> Maybe.Extra.values
                            )
                            [ text confirmName
                            ]
                        ]
                    , td [ Style.classes.controls ]
                        [ button [ Style.classes.button.cancel, onClick cancelMsg ] [ text "Cancel" ] ]
                    ]
    in
    tr ([ Style.classes.editing ] ++ rowClickAction)
        (td [ Style.classes.editable ] [ label [] [ text info.name ] ]
            :: process
        )


anySelection : Lens Page.Model (FoodGroup ingredientId ingredient update foodId food creation) -> Page.Model -> Bool
anySelection foodGroupLens =
    (foodGroupLens |> Compose.lensWithLens FoodGroup.lenses.foodsToAdd).get
        >> Dict.isEmpty
        >> not
