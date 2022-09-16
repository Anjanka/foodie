module Pages.ReferenceNutrients.Handler exposing (init, update)

import Api.Auxiliary exposing (JWT, NutrientCode)
import Api.Types.Nutrient exposing (Nutrient, decoderNutrient, encoderNutrient)
import Api.Types.ReferenceNutrient exposing (ReferenceNutrient)
import Basics.Extra exposing (flip)
import Dict
import Either exposing (Either(..))
import Http exposing (Error)
import Json.Decode as Decode
import Json.Encode as Encode
import Maybe.Extra
import Monocle.Compose as Compose
import Monocle.Lens as Lens
import Monocle.Optional as Optional
import Pages.ReferenceNutrients.Page as Page exposing (Msg(..))
import Pages.ReferenceNutrients.ReferenceNutrientCreationClientInput as ReferenceNutrientCreationClientInput exposing (ReferenceNutrientCreationClientInput)
import Pages.ReferenceNutrients.ReferenceNutrientUpdateClientInput as ReferenceNutrientUpdateClientInput exposing (ReferenceNutrientUpdateClientInput)
import Pages.ReferenceNutrients.Requests as Requests
import Pages.Util.FlagsWithJWT exposing (FlagsWithJWT)
import Ports
import Util.Editing as Editing exposing (Editing)
import Util.LensUtil as LensUtil


init : Page.Flags -> ( Page.Model, Cmd Page.Msg )
init flags =
    let
        ( jwt, cmd ) =
            flags.jwt
                |> Maybe.Extra.unwrap ( "", Ports.doFetchToken () )
                    (\token ->
                        ( token
                        , initialFetch
                            { configuration = flags.configuration
                            , jwt = token
                            }
                        )
                    )
    in
    ( { flagsWithJWT =
            { configuration = flags.configuration
            , jwt = jwt
            }
      , referenceNutrients = Dict.empty
      , nutrients = Dict.empty
      , nutrientsSearchString = ""
      , referenceNutrientsToAdd = Dict.empty
      }
    , cmd
    )


initialFetch : FlagsWithJWT -> Cmd Page.Msg
initialFetch flags =
    Cmd.batch
        [ Requests.fetchReferenceNutrients flags
        , Ports.doFetchNutrients ()
        ]


update : Page.Msg -> Page.Model -> ( Page.Model, Cmd Page.Msg )
update msg model =
    case msg of
        UpdateReferenceNutrient referenceNutrientUpdateClientInput ->
            updateReferenceNutrient model referenceNutrientUpdateClientInput

        SaveReferenceNutrientEdit nutrientCode ->
            saveReferenceNutrientEdit model nutrientCode

        GotSaveReferenceNutrientResponse result ->
            gotSaveReferenceNutrientResponse model result

        EnterEditReferenceNutrient nutrientCode ->
            enterEditReferenceNutrient model nutrientCode

        ExitEditReferenceNutrientAt nutrientCode ->
            exitEditReferenceNutrientAt model nutrientCode

        DeleteReferenceNutrient nutrientCode ->
            deleteReferenceNutrient model nutrientCode

        GotDeleteReferenceNutrientResponse nutrientCode result ->
            gotDeleteReferenceNutrientResponse model nutrientCode result

        GotFetchReferenceNutrientsResponse result ->
            gotFetchReferenceNutrientsResponse model result

        GotFetchNutrientsResponse result ->
            gotFetchNutrientsResponse model result

        SelectNutrient nutrient ->
            selectNutrient model nutrient

        DeselectNutrient nutrientCode ->
            deselectNutrient model nutrientCode

        AddNutrient nutrientCode ->
            addNutrient model nutrientCode

        GotAddReferenceNutrientResponse result ->
            gotAddReferenceNutrientResponse model result

        UpdateAddNutrient referenceNutrientCreationClientInput ->
            updateAddNutrient model referenceNutrientCreationClientInput

        UpdateJWT jwt ->
            updateJWT model jwt

        SetNutrientsSearchString string ->
            setNutrientsSearchString model string

        UpdateNutrients string ->
            updateNutrients model string


updateReferenceNutrient : Page.Model -> ReferenceNutrientUpdateClientInput -> ( Page.Model, Cmd msg )
updateReferenceNutrient model referenceNutrientUpdateClientInput =
    ( model
        |> mapReferenceNutrientOrUpdateById referenceNutrientUpdateClientInput.nutrientCode
            (Either.mapRight (Editing.updateLens.set referenceNutrientUpdateClientInput))
    , Cmd.none
    )


saveReferenceNutrientEdit : Page.Model -> NutrientCode -> ( Page.Model, Cmd Page.Msg )
saveReferenceNutrientEdit model nutrientCode =
    ( model
    , model
        |> Page.lenses.referenceNutrients.get
        |> Dict.get nutrientCode
        |> Maybe.andThen Either.rightToMaybe
        |> Maybe.Extra.unwrap Cmd.none
            (.update >> ReferenceNutrientUpdateClientInput.to >> Requests.saveReferenceNutrient model.flagsWithJWT)
    )


gotSaveReferenceNutrientResponse : Page.Model -> Result Error ReferenceNutrient -> ( Page.Model, Cmd Page.Msg )
gotSaveReferenceNutrientResponse model result =
    ( result
        |> Either.fromResult
        |> Either.unwrap model
            (\referenceNutrient ->
                mapReferenceNutrientOrUpdateById referenceNutrient.nutrientCode
                    (Either.andThenRight (always (Left referenceNutrient)))
                    model
            )
    , Cmd.none
    )


enterEditReferenceNutrient : Page.Model -> NutrientCode -> ( Page.Model, Cmd Page.Msg )
enterEditReferenceNutrient model nutrientCode =
    ( model
        |> mapReferenceNutrientOrUpdateById nutrientCode
            (Either.andThenLeft
                (\me ->
                    Right
                        { original = me
                        , update = ReferenceNutrientUpdateClientInput.from me
                        }
                )
            )
    , Cmd.none
    )


exitEditReferenceNutrientAt : Page.Model -> NutrientCode -> ( Page.Model, Cmd Page.Msg )
exitEditReferenceNutrientAt model nutrientCode =
    ( model
        |> mapReferenceNutrientOrUpdateById nutrientCode (Either.andThen (.original >> Left))
    , Cmd.none
    )


deleteReferenceNutrient : Page.Model -> NutrientCode -> ( Page.Model, Cmd Page.Msg )
deleteReferenceNutrient model nutrientCode =
    ( model
    , Requests.deleteReferenceNutrient model.flagsWithJWT nutrientCode
    )


gotDeleteReferenceNutrientResponse : Page.Model -> NutrientCode -> Result Error () -> ( Page.Model, Cmd msg )
gotDeleteReferenceNutrientResponse model nutrientCode result =
    ( result
        |> Either.fromResult
        |> Either.unwrap model
            (Lens.modify Page.lenses.referenceNutrients (Dict.remove nutrientCode) model
                |> always
            )
    , Cmd.none
    )


gotFetchReferenceNutrientsResponse : Page.Model -> Result Error (List ReferenceNutrient) -> ( Page.Model, Cmd Page.Msg )
gotFetchReferenceNutrientsResponse model result =
    ( result
        |> Either.fromResult
        |> Either.unwrap model
            (List.map (\r -> ( r.nutrientCode, Left r ))
                >> Dict.fromList
                >> flip Page.lenses.referenceNutrients.set model
            )
    , Cmd.none
    )


gotFetchNutrientsResponse : Page.Model -> Result Error (List Nutrient) -> ( Page.Model, Cmd msg )
gotFetchNutrientsResponse model result =
    result
        |> Either.fromResult
        |> Either.unwrap ( model, Cmd.none )
            (\nutrients ->
                ( LensUtil.set nutrients .code Page.lenses.nutrients model
                , nutrients
                    |> Encode.list encoderNutrient
                    |> Encode.encode 0
                    |> Ports.storeNutrients
                )
            )


selectNutrient : Page.Model -> NutrientCode -> ( Page.Model, Cmd msg )
selectNutrient model nutrientCode =
    ( model
        |> Lens.modify Page.lenses.referenceNutrientsToAdd
            (Dict.update nutrientCode (always (ReferenceNutrientCreationClientInput.default nutrientCode) >> Just))
    , Cmd.none
    )


deselectNutrient : Page.Model -> NutrientCode -> ( Page.Model, Cmd Page.Msg )
deselectNutrient model nutrientCode =
    ( model
        |> Lens.modify Page.lenses.referenceNutrientsToAdd (Dict.remove nutrientCode)
    , Cmd.none
    )


addNutrient : Page.Model -> NutrientCode -> ( Page.Model, Cmd Page.Msg )
addNutrient model nutrientCode =
    ( model
    , Dict.get nutrientCode model.referenceNutrientsToAdd
        |> Maybe.map
            (ReferenceNutrientCreationClientInput.toCreation
                >> Requests.addReferenceNutrient model.flagsWithJWT
            )
        |> Maybe.withDefault Cmd.none
    )


gotAddReferenceNutrientResponse : Page.Model -> Result Error ReferenceNutrient -> ( Page.Model, Cmd msg )
gotAddReferenceNutrientResponse model result =
    ( result
        |> Either.fromResult
        |> Either.map
            (\referenceNutrient ->
                model
                    |> Lens.modify Page.lenses.referenceNutrients
                        (Dict.update referenceNutrient.nutrientCode (always referenceNutrient >> Left >> Just))
                    |> Lens.modify Page.lenses.referenceNutrientsToAdd (Dict.remove referenceNutrient.nutrientCode)
            )
        |> Either.withDefault model
    , Cmd.none
    )


updateAddNutrient : Page.Model -> ReferenceNutrientCreationClientInput -> ( Page.Model, Cmd msg )
updateAddNutrient model referenceNutrientCreationClientInput =
    ( model
        |> Lens.modify Page.lenses.referenceNutrientsToAdd
            (Dict.update referenceNutrientCreationClientInput.nutrientCode (always referenceNutrientCreationClientInput >> Just))
    , Cmd.none
    )


updateJWT : Page.Model -> JWT -> ( Page.Model, Cmd Page.Msg )
updateJWT model jwt =
    let
        newModel =
            Page.lenses.jwt.set jwt model
    in
    ( newModel
    , initialFetch newModel.flagsWithJWT
    )


updateNutrients : Page.Model -> String -> ( Page.Model, Cmd Page.Msg )
updateNutrients model =
    Decode.decodeString (Decode.list decoderNutrient)
        >> Result.toMaybe
        >> Maybe.Extra.unwrap ( model, Cmd.none )
            (\nutrients ->
                ( LensUtil.set nutrients .code Page.lenses.nutrients model
                , if List.isEmpty nutrients then
                    Requests.fetchNutrients model.flagsWithJWT

                  else
                    Cmd.none
                )
            )


setNutrientsSearchString : Page.Model -> String -> ( Page.Model, Cmd msg )
setNutrientsSearchString model string =
    ( model |> Page.lenses.nutrientsSearchString.set string
    , Cmd.none
    )


mapReferenceNutrientOrUpdateById : NutrientCode -> (Page.ReferenceNutrientOrUpdate -> Page.ReferenceNutrientOrUpdate) -> Page.Model -> Page.Model
mapReferenceNutrientOrUpdateById ingredientId =
    Page.lenses.referenceNutrients
        |> Compose.lensWithOptional (LensUtil.dictByKey ingredientId)
        |> Optional.modify
