module Pages.Statistics.Meal.Search.Page exposing (..)

import Addresses.StatisticsVariant as StatisticsVariant exposing (Page)
import Api.Auxiliary exposing (JWT)
import Api.Types.Meal exposing (Meal)
import Monocle.Lens exposing (Lens)
import Pages.Statistics.Meal.Search.Pagination as Pagination exposing (Pagination)
import Pages.Util.AuthorizedAccess exposing (AuthorizedAccess)
import Pages.View.Tristate as Tristate
import Util.HttpUtil exposing (Error)


type alias Model =
    Tristate.Model Main Initial


type alias Main =
    { jwt : JWT
    , meals : List Meal
    , mealsSearchString : String
    , pagination : Pagination
    , variant : Page
    }


type alias Initial =
    { jwt : JWT
    , meals : Maybe (List Meal)
    }


initial : AuthorizedAccess -> Model
initial authorizedAccess =
    { jwt = authorizedAccess.jwt
    , meals = Nothing
    }
        |> Tristate.createInitial authorizedAccess.configuration


initialToMain : Initial -> Maybe Main
initialToMain i =
    Maybe.map
        (\meals ->
            { jwt = i.jwt
            , meals = meals
            , mealsSearchString = ""
            , pagination = Pagination.initial
            , variant = StatisticsVariant.Meal
            }
        )
        i.meals


lenses :
    { initial : { meals : Lens Initial (Maybe (List Meal)) }
    , main :
        { meals : Lens Main (List Meal)
        , mealsSearchString : Lens Main String
        , pagination : Lens Main Pagination
        }
    }
lenses =
    { initial = { meals = Lens .meals (\b a -> { a | meals = b }) }
    , main =
        { meals = Lens .meals (\b a -> { a | meals = b })
        , mealsSearchString = Lens .mealsSearchString (\b a -> { a | mealsSearchString = b })
        , pagination = Lens .pagination (\b a -> { a | pagination = b })
        }
    }


type alias Flags =
    { authorizedAccess : AuthorizedAccess
    }


type alias Msg =
    Tristate.Msg LogicMsg


type LogicMsg
    = SetSearchString String
    | SetMealsPagination Pagination
    | GotFetchMealsResponse (Result Error (List Meal))
