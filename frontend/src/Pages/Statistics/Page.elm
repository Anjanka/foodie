module Pages.Statistics.Page exposing (..)

import Addresses.StatisticsVariant exposing (StatisticsVariant)
import Api.Auxiliary exposing (FoodId, MealId, NutrientCode, RecipeId, ReferenceMapId)
import Api.Lenses.RequestIntervalLens as RequestIntervalLens
import Api.Types.Date exposing (Date)
import Api.Types.ReferenceMap exposing (ReferenceMap)
import Api.Types.ReferenceTree exposing (ReferenceTree)
import Api.Types.RequestInterval exposing (RequestInterval)
import Api.Types.Stats exposing (Stats)
import Dict exposing (Dict)
import Monocle.Compose as Compose
import Monocle.Lens exposing (Lens)
import Pages.Statistics.Pagination exposing (Pagination)
import Pages.Statistics.Status exposing (Status)
import Pages.Util.AuthorizedAccess exposing (AuthorizedAccess)
import Util.HttpUtil exposing (Error)
import Util.Initialization exposing (Initialization)


type alias Model =
    { authorizedAccess : AuthorizedAccess
    , requestInterval : RequestInterval
    , stats : Stats
    , referenceTrees : Dict ReferenceMapId ReferenceNutrientTree
    , referenceTree : Maybe ReferenceNutrientTree
    , initialization : Initialization Status
    , pagination : Pagination
    , nutrientsSearchString : String
    , fetching : Bool
    , variant : StatisticsVariant
    }


lenses :
    { requestInterval : Lens Model RequestInterval
    , from : Lens Model (Maybe Date)
    , to : Lens Model (Maybe Date)
    , stats : Lens Model Stats
    , referenceTrees : Lens Model (Dict ReferenceMapId ReferenceNutrientTree)
    , referenceTree : Lens Model (Maybe ReferenceNutrientTree)
    , initialization : Lens Model (Initialization Status)
    , pagination : Lens Model Pagination
    , nutrientsSearchString : Lens Model String
    , fetching : Lens Model Bool
    , variant : Lens Model StatisticsVariant
    }
lenses =
    let
        requestInterval =
            Lens .requestInterval (\b a -> { a | requestInterval = b })
    in
    { requestInterval = requestInterval
    , from = requestInterval |> Compose.lensWithLens RequestIntervalLens.from
    , to = requestInterval |> Compose.lensWithLens RequestIntervalLens.to
    , stats = Lens .stats (\b a -> { a | stats = b })
    , referenceTrees = Lens .referenceTrees (\b a -> { a | referenceTrees = b })
    , referenceTree = Lens .referenceTree (\b a -> { a | referenceTree = b })
    , initialization = Lens .initialization (\b a -> { a | initialization = b })
    , pagination = Lens .pagination (\b a -> { a | pagination = b })
    , nutrientsSearchString = Lens .nutrientsSearchString (\b a -> { a | nutrientsSearchString = b })
    , fetching = Lens .fetching (\b a -> { a | fetching = b })
    , variant = Lens .variant (\b a -> { a | variant = b })
    }


type alias Flags =
    { authorizedAccess : AuthorizedAccess
    , variant : StatisticsVariant
    }


type alias ReferenceNutrientTree =
    { map : ReferenceMap
    , values : Dict NutrientCode Float
    }


type Msg
    = SetFromDate (Maybe Date)
    | SetToDate (Maybe Date)
    | FetchStats
    | GotFetchStatsResponse (Result Error Stats)
    | GotFetchReferenceTreesResponse (Result Error (List ReferenceTree))
    | SetPagination Pagination
    | SelectReferenceMap (Maybe ReferenceMapId)
    | SetNutrientsSearchString String
    | SetVariant StatisticsVariant
