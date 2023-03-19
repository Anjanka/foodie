module Pages.Util.Style exposing (..)

import Html exposing (Attribute)
import Html.Attributes exposing (class, id)


classes :
    { addElement : Attribute msg
    , addView : Attribute msg
    , button :
        { add : Attribute msg
        , alternative : Attribute msg
        , cancel : Attribute msg
        , confirm : Attribute msg
        , delete : Attribute msg
        , edit : Attribute msg
        , editor : Attribute msg
        , error : Attribute msg
        , logout : Attribute msg
        , menu : Attribute msg
        , navigation : Attribute msg
        , nutrients : Attribute msg
        , overview : Attribute msg
        , pager : Attribute msg
        , select : Attribute msg
        }
    , choices : Attribute msg
    , choiceTable : Attribute msg
    , confirm : Attribute msg
    , controlsGroup : Attribute msg
    , controls : Attribute msg
    , date : Attribute msg
    , descriptionColumn : Attribute msg
    , disabled : Attribute msg
    , editable : Attribute msg
    , editing : Attribute msg
    , editLine : Attribute msg
    , elements : Attribute msg
    , elementsWithControlsTable : Attribute msg
    , ellipsis : Attribute msg
    , incomplete : Attribute msg
    , info : Attribute msg
    , intervalSelection : Attribute msg
    , meals : Attribute msg
    , numberCell : Attribute msg
    , numberLabel : Attribute msg
    , nutrients : Attribute msg
    , pagination : Attribute msg
    , partialStatistics : Attribute msg
    , rating :
        { low : Attribute msg
        , exact : Attribute msg
        , high : Attribute msg
        }
    , request : Attribute msg
    , recipeEditTable : Attribute msg
    , search :
        { area : Attribute msg
        , field : Attribute msg
        }
    , tableHeader : Attribute msg
    , time : Attribute msg
    , toggle : Attribute msg
    }
classes =
    { addElement = class "addElement"
    , addView = class "addView"
    , button =
        { add = class "addButton"
        , alternative = class "alternativeButton"
        , cancel = class "cancelButton"
        , confirm = class "confirmButton"
        , delete = class "deleteButton"
        , edit = class "editButton"
        , editor = class "editorButton"
        , error = class "errorButton"
        , logout = class "logoutButton"
        , menu = class "menuButton"
        , navigation = class "navigationButton"
        , nutrients = class "nutrientsButton"
        , overview = class "overviewButton"
        , pager = class "pagerButton"
        , select = class "selectButton"
        }
    , choices = class "choices"
    , choiceTable = class "choiceTable"
    , confirm = class "confirm"
    , controlsGroup = class "controlsGroup"
    , controls = class "controls"
    , date = class "date"
    , descriptionColumn = class "descriptionColumn"
    , disabled = class "disabled"
    , editable = class "editable"
    , editing = class "editing"
    , editLine = class "editLine"
    , elements = class "elements"
    , elementsWithControlsTable = class "elementsWithControlsTable"
    , ellipsis = class "ellipsis"
    , incomplete = class "incomplete"
    , info = class "info"
    , intervalSelection = class "intervalSection"
    , meals = class "meals"
    , numberCell = class "numberCell"
    , numberLabel = class "numberLabel"
    , nutrients = class "nutrients"
    , pagination = class "pagination"
    , partialStatistics = class "partialStatistics"
    , rating =
        { low = class "low"
        , exact = class "exact"
        , high = class "high"
        }
    , request = class "request"
    , recipeEditTable = class "recipeEditTable"
    , search =
        { area = class "searchArea"
        , field = class "searchField"
        }
    , tableHeader = class "tableHeader"
    , time = class "time"
    , toggle = class "toggle"
    }


ids :
    { add : Attribute msg
    , addMealView : Attribute msg
    , addRecipeView : Attribute msg
    , addReferenceMapView : Attribute msg
    , complexFoodEditor : Attribute msg
    , error : Attribute msg
    , ingredientEditor : Attribute msg
    , mealEntryEditor : Attribute msg
    , navigation : Attribute msg
    , overviewMain : Attribute msg
    , referenceEntryEditor : Attribute msg
    , statistics :
        { food : Attribute msg
        , complexFood : Attribute msg
        , meal : Attribute msg
        , recipe : Attribute msg
        , time : Attribute msg
        , recipeOccurrence : Attribute msg
        }
    }
ids =
    { add = id "add"
    , addMealView = id "addMealView"
    , addRecipeView = id "addRecipeView"
    , addReferenceMapView = id "addReferenceMapView"
    , complexFoodEditor = id "complexFoodEditor"
    , error = id "error"
    , ingredientEditor = id "ingredientEditor"
    , mealEntryEditor = id "mealEntryEditor"
    , navigation = id "navigation"
    , overviewMain = id "overviewMain"
    , referenceEntryEditor = id "referenceEntryEditor"
    , statistics =
        { food = id "statisticsFood"
        , complexFood = id "statisticsComplexFood"
        , meal = id "statisticsMeal"
        , recipe = id "statisticsRecipe"
        , time = id "statistics"
        , recipeOccurrence = id "statisticsRecipeOccurrence"
        }
    }
