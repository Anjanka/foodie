module Pages.ComplexFoods.Foods.Requests exposing (..)

import Addresses.Backend
import Api.Auxiliary exposing (ComplexFoodId)
import Api.Types.ComplexFood exposing (ComplexFood, decoderComplexFood)
import Api.Types.ComplexFoodIncoming exposing (ComplexFoodIncoming, encoderComplexFoodIncoming)
import Http
import Json.Decode as Decode
import Pages.ComplexFoods.Foods.Page as Page
import Pages.Util.AuthorizedAccess exposing (AuthorizedAccess)
import Pages.Util.Choice.Page
import Pages.Util.Requests
import Util.HttpUtil as HttpUtil


fetchRecipes : AuthorizedAccess -> Cmd Page.LogicMsg
fetchRecipes =
    Pages.Util.Requests.fetchRecipesWith Pages.Util.Choice.Page.GotFetchChoicesResponse


fetchComplexFoods : AuthorizedAccess -> Cmd Page.LogicMsg
fetchComplexFoods authorizedAccess =
    HttpUtil.runPatternWithJwt
        authorizedAccess
        Addresses.Backend.complexFoods.all
        { body = Http.emptyBody
        , expect = HttpUtil.expectJson Pages.Util.Choice.Page.GotFetchElementsResponse (Decode.list decoderComplexFood)
        }


createComplexFood : AuthorizedAccess -> ComplexFoodIncoming -> Cmd Page.LogicMsg
createComplexFood authorizedAccess complexFood =
    HttpUtil.runPatternWithJwt
        authorizedAccess
        Addresses.Backend.complexFoods.create
        { body = encoderComplexFoodIncoming complexFood |> Http.jsonBody
        , expect = HttpUtil.expectJson Pages.Util.Choice.Page.GotCreateResponse decoderComplexFood
        }


updateComplexFood : AuthorizedAccess -> ComplexFoodIncoming -> Cmd Page.LogicMsg
updateComplexFood authorizedAccess complexFood =
    HttpUtil.runPatternWithJwt
        authorizedAccess
        Addresses.Backend.complexFoods.update
        { body = encoderComplexFoodIncoming complexFood |> Http.jsonBody
        , expect = HttpUtil.expectJson Pages.Util.Choice.Page.GotSaveEditResponse decoderComplexFood
        }


deleteComplexFood : AuthorizedAccess -> ComplexFoodId -> Cmd Page.LogicMsg
deleteComplexFood authorizedAccess complexFoodId =
    HttpUtil.runPatternWithJwt
        authorizedAccess
        (Addresses.Backend.complexFoods.delete complexFoodId)
        { body = Http.emptyBody
        , expect = HttpUtil.expectWhatever (Pages.Util.Choice.Page.GotDeleteResponse complexFoodId)
        }
