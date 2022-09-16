module Pages.Recipes.Page exposing (..)

import Api.Auxiliary exposing (JWT, RecipeId)
import Api.Types.Recipe exposing (Recipe)
import Configuration exposing (Configuration)
import Dict exposing (Dict)
import Either exposing (Either)
import Http exposing (Error)
import Monocle.Lens exposing (Lens)
import Pages.Recipes.RecipeCreationClientInput exposing (RecipeCreationClientInput)
import Pages.Recipes.RecipeUpdateClientInput exposing (RecipeUpdateClientInput)
import Pages.Util.FlagsWithJWT exposing (FlagsWithJWT)
import Util.Editing exposing (Editing)
import Util.LensUtil as LensUtil


type alias Model =
    { flagsWithJWT : FlagsWithJWT
    , recipes : RecipeOrUpdateMap
    , recipeToAdd : Maybe RecipeCreationClientInput
    }


type alias RecipeOrUpdate =
    Either Recipe (Editing Recipe RecipeUpdateClientInput)

type alias RecipeOrUpdateMap =
    Dict RecipeId RecipeOrUpdate

lenses :
    { jwt : Lens Model JWT
    , recipes : Lens Model RecipeOrUpdateMap
    , recipeToAdd : Lens Model (Maybe RecipeCreationClientInput)
    }
lenses =
    { jwt = LensUtil.jwtSubLens
    , recipes = Lens .recipes (\b a -> { a | recipes = b })
    , recipeToAdd = Lens .recipeToAdd (\b a -> { a | recipeToAdd = b })
    }


type alias Flags =
    { configuration : Configuration
    , jwt : Maybe String
    }


type Msg
    = UpdateRecipeCreation (Maybe RecipeCreationClientInput)
    | CreateRecipe
    | GotCreateRecipeResponse (Result Error Recipe)
    | UpdateRecipe RecipeUpdateClientInput
    | SaveRecipeEdit RecipeId
    | GotSaveRecipeResponse (Result Error Recipe)
    | EnterEditRecipe RecipeId
    | ExitEditRecipeAt RecipeId
    | DeleteRecipe RecipeId
    | GotDeleteRecipeResponse RecipeId (Result Error ())
    | GotFetchRecipesResponse (Result Error (List Recipe))
    | UpdateJWT JWT
