module Pages.Meals.Page exposing (..)

import Api.Auxiliary exposing (JWT, MealId)
import Api.Types.Meal exposing (Meal)
import Monocle.Lens exposing (Lens)
import Pages.Meals.MealCreationClientInput exposing (MealCreationClientInput)
import Pages.Meals.MealUpdateClientInput exposing (MealUpdateClientInput)
import Pages.Meals.Pagination exposing (Pagination)
import Pages.Meals.Status exposing (Status)
import Pages.Util.AuthorizedAccess exposing (AuthorizedAccess)
import Util.DictList exposing (DictList)
import Util.Editing exposing (Editing)
import Util.HttpUtil exposing (Error)
import Util.Initialization exposing (Initialization)


type alias Model =
    { authorizedAccess : AuthorizedAccess
    , meals : MealStateMap
    , mealToAdd : Maybe MealCreationClientInput
    , searchString : String
    , initialization : Initialization Status
    , pagination : Pagination
    }


type alias MealState =
    Editing Meal MealUpdateClientInput


type alias MealStateMap =
    DictList MealId MealState


lenses :
    { meals : Lens Model MealStateMap
    , mealToAdd : Lens Model (Maybe MealCreationClientInput)
    , searchString : Lens Model String
    , initialization : Lens Model (Initialization Status)
    , pagination : Lens Model Pagination
    }
lenses =
    { meals = Lens .meals (\b a -> { a | meals = b })
    , mealToAdd = Lens .mealToAdd (\b a -> { a | mealToAdd = b })
    , searchString = Lens .searchString (\b a -> { a | searchString = b })
    , initialization = Lens .initialization (\b a -> { a | initialization = b })
    , pagination = Lens .pagination (\b a -> { a | pagination = b })
    }


type alias Flags =
    { authorizedAccess : AuthorizedAccess
    }


type Msg
    = UpdateMealCreation (Maybe MealCreationClientInput)
    | CreateMeal
    | GotCreateMealResponse (Result Error Meal)
    | UpdateMeal MealUpdateClientInput
    | SaveMealEdit MealId
    | GotSaveMealResponse (Result Error Meal)
    | EnterEditMeal MealId
    | ExitEditMealAt MealId
    | RequestDeleteMeal MealId
    | ConfirmDeleteMeal MealId
    | CancelDeleteMeal MealId
    | GotDeleteMealResponse MealId (Result Error ())
    | GotFetchMealsResponse (Result Error (List Meal))
    | SetPagination Pagination
    | SetSearchString String
