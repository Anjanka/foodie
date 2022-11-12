module Addresses.Frontend exposing
    ( complexFoods
    , confirmRecovery
    , confirmRegistration
    , deleteAccount
    , ingredientEditor
    , login
    , mealEntryEditor
    , meals
    , overview
    , recipes
    , referenceEntries
    , referenceMaps
    , requestRecovery
    , requestRegistration
    , statisticsTime
    , userSettings
    )

import Api.Auxiliary exposing (JWT, MealId, RecipeId, ReferenceMapId)
import Api.Types.UserIdentifier exposing (UserIdentifier)
import Pages.Util.ParserUtil as ParserUtil exposing (AddressWithParser, with1, with2)
import Url.Parser as Parser exposing ((</>), (<?>), Parser, s)


requestRegistration : AddressWithParser () a a
requestRegistration =
    plain "request-registration"


requestRecovery : AddressWithParser () a a
requestRecovery =
    plain "request-recovery"


overview : AddressWithParser () a a
overview =
    plain "overview"


mealEntryEditor : AddressWithParser MealId (MealId -> a) a
mealEntryEditor =
    with1
        { step1 = "meal-entry-editor"
        , toString = List.singleton
        , paramParser = ParserUtil.uuidParser
        }


recipes : AddressWithParser () a a
recipes =
    plain "recipes"


meals : AddressWithParser () a a
meals =
    plain "meals"


statisticsTime : AddressWithParser () a a
statisticsTime =
    plain "statistics"



--let
--    statisticsWord =
--        "statistics"
--in
--{ address = StatisticsVariant.toString >> (::) statisticsWord
--, parser =
--    [ Parser.top |> Parser.map StatisticsVariant.Time
--    , s StatisticsVariant.food </> Parser.top |> Parser.map (StatisticsVariant.Food Nothing)
--    , s StatisticsVariant.food </> Parser.int |> Parser.map (Just >> StatisticsVariant.Food)
--    , s StatisticsVariant.meal </> Parser.top |> Parser.map (StatisticsVariant.Meal Nothing)
--    , s StatisticsVariant.meal </> ParserUtil.uuidParser |> Parser.map (Just >> StatisticsVariant.Meal)
--    , s StatisticsVariant.recipe </> Parser.top |> Parser.map (StatisticsVariant.Recipe Nothing)
--    , s StatisticsVariant.recipe </> ParserUtil.uuidParser |> Parser.map (Just >> StatisticsVariant.Recipe)
--    ]
--        |> List.map (\p -> s statisticsWord </> p)
--        |> Parser.oneOf
--}


referenceMaps : AddressWithParser () a a
referenceMaps =
    plain "reference-maps"


referenceEntries : AddressWithParser ReferenceMapId (ReferenceMapId -> a) a
referenceEntries =
    with1
        { step1 = "reference-nutrients"
        , toString = List.singleton
        , paramParser = ParserUtil.uuidParser
        }


userSettings : AddressWithParser () a a
userSettings =
    plain "user-settings"


ingredientEditor : AddressWithParser RecipeId (RecipeId -> a) a
ingredientEditor =
    with1
        { step1 = "ingredient-editor"
        , toString = List.singleton
        , paramParser = ParserUtil.uuidParser
        }


login : AddressWithParser () a a
login =
    plain "login"


confirmRegistration : AddressWithParser ( ( String, String ), JWT ) (UserIdentifier -> JWT -> a) a
confirmRegistration =
    confirm "confirm-registration"


deleteAccount : AddressWithParser ( ( String, String ), JWT ) (UserIdentifier -> JWT -> a) a
deleteAccount =
    confirm "delete-account"


confirmRecovery : AddressWithParser ( ( String, String ), JWT ) (UserIdentifier -> JWT -> a) a
confirmRecovery =
    confirm "recover-account"


complexFoods : AddressWithParser () a a
complexFoods =
    plain "complex-foods"


confirm : String -> AddressWithParser ( ( String, String ), JWT ) (UserIdentifier -> JWT -> a) a
confirm step1 =
    with2
        { step1 = step1
        , toString1 = ParserUtil.nicknameEmailParser.address
        , step2 = "token"
        , toString2 = List.singleton
        , paramParser1 = ParserUtil.nicknameEmailParser.parser |> Parser.map UserIdentifier
        , paramParser2 = Parser.string
        }


plain : String -> AddressWithParser () a a
plain string =
    { address = always [ string ]
    , parser = s string
    }
