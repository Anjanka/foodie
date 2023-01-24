module Api.Types.Recipe exposing (..)

import Json.Decode as Decode
import Json.Decode.Pipeline exposing (..)
import Json.Encode as Encode

import Uuid exposing (Uuid)

type alias Recipe = { id: Uuid, name: String, description: (Maybe String), numberOfServings: Float }


decoderRecipe : Decode.Decoder Recipe
decoderRecipe = Decode.succeed Recipe |> required "id" Uuid.decoder |> required "name" Decode.string |> optional "description" (Decode.maybe Decode.string) Nothing |> required "numberOfServings" Decode.float


encoderRecipe : Recipe -> Encode.Value
encoderRecipe obj = Encode.object [ ("id", Uuid.encode obj.id), ("name", Encode.string obj.name), ("description", Maybe.withDefault Encode.null (Maybe.map Encode.string obj.description)), ("numberOfServings", Encode.float obj.numberOfServings) ]