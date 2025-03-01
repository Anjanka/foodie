module Pages.Util.NavigationUtil exposing (..)

import Addresses.Frontend
import Api.Auxiliary exposing (MealId, RecipeId)
import Configuration exposing (Configuration)
import Html exposing (Html, text)
import Pages.Util.Links as Links
import Pages.Util.Style as Style


recipeEditorLinkButton : Configuration -> RecipeId -> Html msg
recipeEditorLinkButton configuration recipeId =
    Links.linkButton
        { url =
            recipeId
                |> Addresses.Frontend.ingredientEditor.address
                |> Links.frontendPage configuration
        , attributes = [ Style.classes.button.editor ]
        , children = [ text "Recipe" ]
        }


recipeNutrientsLinkButton : Configuration -> RecipeId -> Html msg
recipeNutrientsLinkButton configuration recipeId =
    nutrientButtonWith
        { address =
            recipeId
                |> Addresses.Frontend.statisticsRecipeSelect.address
                |> Links.frontendPage configuration
        }


mealEditorLinkButton : Configuration -> RecipeId -> Html msg
mealEditorLinkButton configuration mealId =
    Links.linkButton
        { url =
            mealId
                |> Addresses.Frontend.mealEntryEditor.address
                |> Links.frontendPage configuration
        , attributes = [ Style.classes.button.editor ]
        , children = [ text "Meal" ]
        }


mealNutrientsLinkButton : Configuration -> MealId -> Html msg
mealNutrientsLinkButton configuration mealId =
    nutrientButtonWith
        { address =
            mealId
                |> Addresses.Frontend.statisticsMealSelect.address
                |> Links.frontendPage configuration
        }


complexFoodNutrientLinkButton : Configuration -> RecipeId -> Html msg
complexFoodNutrientLinkButton configuration recipeId =
    nutrientButtonWith
        { address =
            recipeId
                |> Addresses.Frontend.statisticsComplexFoodSelect.address
                |> Links.frontendPage configuration
        }


nutrientButtonWith : { address : String } -> Html msg
nutrientButtonWith ps =
    Links.linkButton
        { url = ps.address
        , attributes = [ Style.classes.button.nutrients ]
        , children = [ text "Nutrients" ]
        }
