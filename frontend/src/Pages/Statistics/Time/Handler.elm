module Pages.Statistics.Time.Handler exposing (init, update)

import Addresses.StatisticsVariant as StatisticsVariant
import Api.Auxiliary exposing (ReferenceMapId)
import Api.Lenses.RequestIntervalLens as RequestIntervalLens
import Api.Lenses.StatsLens as StatsLens
import Api.Types.Date exposing (Date)
import Api.Types.ReferenceTree exposing (ReferenceTree)
import Api.Types.Stats exposing (Stats)
import Basics.Extra exposing (flip)
import Monocle.Lens as Lens
import Pages.Statistics.StatisticsRequests as StatisticsRequests
import Pages.Statistics.StatisticsUtil as StatisticsUtil
import Pages.Statistics.Time.Page as Page
import Pages.Statistics.Time.Pagination as Pagination exposing (Pagination)
import Pages.Statistics.Time.Requests as Requests
import Pages.Statistics.Time.Status as Status
import Pages.Util.AuthorizedAccess exposing (AuthorizedAccess)
import Result.Extra
import Util.HttpUtil as HttpUtil exposing (Error)
import Util.Initialization as Initialization


init : Page.Flags -> ( Page.Model, Cmd Page.Msg )
init flags =
    ( { authorizedAccess = flags.authorizedAccess
      , requestInterval = RequestIntervalLens.default
      , stats = defaultStats
      , statisticsEvaluation = StatisticsUtil.initial
      , initialization = Initialization.Loading Status.initial
      , pagination = Pagination.initial
      , fetching = False
      , variant = StatisticsVariant.Time
      }
    , initialFetch flags.authorizedAccess
    )


initialFetch : AuthorizedAccess -> Cmd Page.Msg
initialFetch =
    Requests.fetchReferenceTrees


defaultStats : Stats
defaultStats =
    { meals = []
    , nutrients = []
    }


update : Page.Msg -> Page.Model -> ( Page.Model, Cmd Page.Msg )
update msg model =
    case msg of
        Page.SetFromDate maybeDate ->
            setFromDate model maybeDate

        Page.SetToDate maybeDate ->
            setToDate model maybeDate

        Page.FetchStats ->
            fetchStats model

        Page.GotFetchStatsResponse result ->
            gotFetchStatsResponse model result

        Page.GotFetchReferenceTreesResponse result ->
            gotFetchReferenceTreesResponse model result

        Page.SetPagination pagination ->
            setPagination model pagination

        Page.SelectReferenceMap referenceMapId ->
            selectReferenceMap model referenceMapId

        Page.SetNutrientsSearchString string ->
            setNutrientsSearchString model string


setFromDate : Page.Model -> Maybe Date -> ( Page.Model, Cmd Page.Msg )
setFromDate model maybeDate =
    ( model
        |> Page.lenses.from.set
            maybeDate
    , Cmd.none
    )


setToDate : Page.Model -> Maybe Date -> ( Page.Model, Cmd Page.Msg )
setToDate model maybeDate =
    ( model
        |> Page.lenses.to.set
            maybeDate
    , Cmd.none
    )


fetchStats : Page.Model -> ( Page.Model, Cmd Page.Msg )
fetchStats model =
    ( model
        |> Page.lenses.fetching.set True
    , Requests.fetchStats model.authorizedAccess model.requestInterval
    )


gotFetchStatsResponse : Page.Model -> Result Error Stats -> ( Page.Model, Cmd Page.Msg )
gotFetchStatsResponse model result =
    ( result
        |> Result.Extra.unpack (flip setError model)
            (\stats ->
                model
                    |> Page.lenses.stats.set
                        (stats |> Lens.modify StatsLens.nutrients (List.sortBy (.base >> .name)))
                    |> Page.lenses.fetching.set False
            )
    , Cmd.none
    )


gotFetchReferenceTreesResponse : Page.Model -> Result Error (List ReferenceTree) -> ( Page.Model, Cmd Page.Msg )
gotFetchReferenceTreesResponse =
    StatisticsRequests.gotFetchReferenceTreesResponseWith
        { setError = setError
        , statisticsEvaluationLens = Page.lenses.statisticsEvaluation
        }


setPagination : Page.Model -> Pagination -> ( Page.Model, Cmd Page.Msg )
setPagination model pagination =
    ( model |> Page.lenses.pagination.set pagination
    , Cmd.none
    )


selectReferenceMap : Page.Model -> Maybe ReferenceMapId -> ( Page.Model, Cmd Page.Msg )
selectReferenceMap =
    StatisticsRequests.selectReferenceMapWith
        { statisticsEvaluationLens = Page.lenses.statisticsEvaluation
        }


setNutrientsSearchString : Page.Model -> String -> ( Page.Model, Cmd Page.Msg )
setNutrientsSearchString =
    StatisticsRequests.setNutrientsSearchStringWith
        { statisticsEvaluationLens = Page.lenses.statisticsEvaluation
        }


setError : Error -> Page.Model -> Page.Model
setError =
    HttpUtil.setError Page.lenses.initialization
