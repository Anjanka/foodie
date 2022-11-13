module Pages.Statistics.Food.Search.View exposing (view)

import Addresses.Frontend
import Addresses.StatisticsVariant as StatisticsVariant
import Api.Types.Food exposing (Food)
import Configuration exposing (Configuration)
import Html exposing (Html, col, colgroup, div, label, table, tbody, td, text, th, thead, tr)
import Monocle.Compose as Compose
import Pages.Statistics.Food.Search.Page as Page
import Pages.Statistics.Food.Search.Pagination as Pagination
import Pages.Statistics.Food.Search.Status as Status
import Pages.Statistics.StatisticsView as StatisticsView
import Pages.Util.HtmlUtil as HtmlUtil
import Pages.Util.Links as Links
import Pages.Util.PaginationSettings as PaginationSettings
import Pages.Util.Style as Style
import Pages.Util.ViewUtil as ViewUtil exposing (Page(..))
import Paginate
import Util.SearchUtil as SearchUtil


view : Page.Model -> Html Page.Msg
view model =
    ViewUtil.viewWithErrorHandling
        { isFinished = Status.isFinished
        , initialization = .initialization
        , configuration = .authorizedAccess >> .configuration
        , jwt = .authorizedAccess >> .jwt >> Just
        , currentPage = Just Statistics
        , showNavigation = True
        }
        model
    <|
        StatisticsView.withNavigationBar
            { mainPageURL = model.authorizedAccess.configuration.mainPageURL
            , currentPage = Just <| StatisticsVariant.Food StatisticsVariant.None
            }
        <|
            let
                viewFoods =
                    model.foods
                        |> List.filter (\v -> SearchUtil.search model.foodsSearchString v.name)
                        |> List.sortBy .name
                        |> ViewUtil.paginate
                            { pagination =
                                Page.lenses.pagination
                                    |> Compose.lensWithLens Pagination.lenses.foods
                            }
                            model
            in
            div [ Style.classes.addView ]
                [ div [ Style.classes.addElement ]
                    [ HtmlUtil.searchAreaWith
                        { msg = Page.SetSearchString
                        , searchString = model.foodsSearchString
                        }
                    , table [ Style.classes.choiceTable ]
                        [ colgroup []
                            [ col [] []
                            , col [] []
                            ]
                        , thead []
                            [ tr [ Style.classes.tableHeader ]
                                [ th [] [ label [] [ text "Name" ] ]
                                , th [ Style.classes.controlsGroup ] []
                                ]
                            ]
                        , tbody []
                            (viewFoods
                                |> Paginate.page
                                |> List.map (viewFoodLine model.authorizedAccess.configuration)
                            )
                        ]
                    , div [ Style.classes.pagination ]
                        [ ViewUtil.pagerButtons
                            { msg =
                                PaginationSettings.updateCurrentPage
                                    { pagination = Page.lenses.pagination
                                    , items = Pagination.lenses.foods
                                    }
                                    model
                                    >> Page.SetFoodsPagination
                            , elements = viewFoods
                            }
                        ]
                    ]
                ]


viewFoodLine : Configuration -> Food -> Html Page.Msg
viewFoodLine configuration food =
    tr [ Style.classes.editing ]
        [ td [ Style.classes.editable ]
            [ label [] [ text food.name ] ]
        , td [ Style.classes.controls ]
            [ Links.linkButton
                { url = Links.frontendPage configuration <| Addresses.Frontend.statisticsFoodSelect.address <| food.id
                , attributes = [ Style.classes.button.editor ]
                , children = [ text "Nutrients" ]
                }
            ]
        ]
