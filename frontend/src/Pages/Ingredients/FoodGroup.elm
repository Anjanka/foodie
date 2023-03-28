module Pages.Ingredients.FoodGroup exposing (..)

import Api.Auxiliary exposing (JWT, RecipeId)
import Monocle.Lens exposing (Lens)
import Pages.Ingredients.Pagination as Pagination exposing (Pagination)
import Pages.View.Tristate as Tristate
import Util.DictList as DictList exposing (DictList)
import Util.Editing as Editing exposing (Editing)
import Util.HttpUtil exposing (Error)


type alias Model ingredientId ingredient update foodId food creation =
    Tristate.Model (Main ingredientId ingredient update foodId food creation) (Initial ingredientId ingredient update foodId food)


type alias Main ingredientId ingredient update foodId food creation =
    { jwt : JWT
    , recipeId : RecipeId
    , ingredients : DictList ingredientId (IngredientState ingredient update)
    , foods : DictList foodId (Editing food creation)
    , pagination : Pagination
    , foodsSearchString : String
    , ingredientsSearchString : String
    }


type alias Initial ingredientId ingredient update foodId food =
    { jwt : JWT
    , recipeId : RecipeId
    , ingredients : Maybe (DictList ingredientId (IngredientState ingredient update))
    , foods : Maybe (DictList foodId food)
    }


initialWith : JWT -> RecipeId -> Initial ingredientId ingredient update foodId food
initialWith jwt recipeId =
    { jwt = jwt
    , recipeId = recipeId
    , ingredients = Nothing
    , foods = Nothing
    }


initialToMain : Initial ingredientId ingredient update foodId food -> Maybe (Main ingredientId ingredient update foodId food creation)
initialToMain i =
    Maybe.map2
        (\ingredients foods ->
            { jwt = i.jwt
            , recipeId = i.recipeId
            , ingredients = ingredients
            , foods = foods |> DictList.map Editing.asView
            , pagination = Pagination.initial
            , foodsSearchString = ""
            , ingredientsSearchString = ""
            }
        )
        i.ingredients
        i.foods


type alias IngredientState ingredient update =
    Editing ingredient update


lenses :
    { initial :
        { ingredients : Lens (Initial ingredientId ingredient update foodId food) (Maybe (DictList ingredientId (IngredientState ingredient update)))
        , foods : Lens (Initial ingredientId ingredient update foodId food) (Maybe (DictList foodId food))
        }
    , main :
        { ingredients : Lens (Main ingredientId ingredient update foodId food creation) (DictList ingredientId (IngredientState ingredient update))
        , foods : Lens (Main ingredientId ingredient update foodId food creation) (DictList foodId (Editing food creation))
        , pagination : Lens (Main ingredientId ingredient update foodId food creation) Pagination
        , foodsSearchString : Lens (Main ingredientId ingredient update foodId food creation) String
        , ingredientsSearchString : Lens (Main ingredientId ingredient update foodId food creation) String
        }
    }
lenses =
    { initial =
        { ingredients = Lens .ingredients (\b a -> { a | ingredients = b })
        , foods = Lens .foods (\b a -> { a | foods = b })
        }
    , main =
        { ingredients = Lens .ingredients (\b a -> { a | ingredients = b })
        , foods = Lens .foods (\b a -> { a | foods = b })
        , pagination = Lens .pagination (\b a -> { a | pagination = b })
        , foodsSearchString = Lens .foodsSearchString (\b a -> { a | foodsSearchString = b })
        , ingredientsSearchString = Lens .ingredientsSearchString (\b a -> { a | ingredientsSearchString = b })
        }
    }


type LogicMsg ingredientId ingredient update foodId food creation
    = Edit update
    | SaveEdit update
    | GotSaveEditResponse (Result Error ingredient)
    | ToggleControls ingredientId
    | EnterEdit ingredientId
    | ExitEdit ingredientId
    | RequestDelete ingredientId
    | ConfirmDelete ingredientId
    | CancelDelete ingredientId
    | GotDeleteResponse ingredientId (Result Error ())
    | GotFetchResponse (Result Error (List ingredient))
    | GotFetchFoodsResponse (Result Error (List food))
    | SelectFood food
    | DeselectFood foodId
    | Create foodId
    | GotCreateResponse (Result Error ingredient)
    | UpdateCreation creation
    | SetIngredientsPagination Pagination
    | SetIngredientsSearchString String
    | SetFoodsSearchString String
