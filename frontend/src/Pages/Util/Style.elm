module Pages.Util.Style exposing (..)

import Html exposing (Attribute)
import Html.Attributes exposing (class, id)


classes :
    { addElement : Attribute msg
    , addView : Attribute msg
    , button :
        { add : Attribute msg
        , cancel : Attribute msg
        , confirm : Attribute msg
        , delete : Attribute msg
        , edit : Attribute msg
        , editor : Attribute msg
        , navigation : Attribute msg
        , select : Attribute msg
        }
    , choices : Attribute msg
    , choiceTable : Attribute msg
    , controlsGroup : Attribute msg
    , controls : Attribute msg
    , date : Attribute msg
    , descriptionColumn : Attribute msg
    , disabled : Attribute msg
    , editable : Attribute msg
    , editing : Attribute msg
    , editLine : Attribute msg
    , elements : Attribute msg
    , info : Attribute msg
    , intervalSelection : Attribute msg
    , meals : Attribute msg
    , numberCell : Attribute msg
    , numberLabel : Attribute msg
    , nutrients : Attribute msg
    , rating :
        { low : Attribute msg
        , exact : Attribute msg
        , high : Attribute msg
        }
    , search :
        { area : Attribute msg
        , field : Attribute msg
        }
    , tableHeader : Attribute msg
    , time : Attribute msg
    }
classes =
    { addElement = class "addElement"
    , addView = class "addView"
    , button =
        { add = class "addButton"
        , cancel = class "cancelButton"
        , confirm = class "confirmButton"
        , delete = class "deleteButton"
        , edit = class "editButton"
        , editor = class "editorButton"
        , navigation = class "navigationButton"
        , select = class "selectButton"
        }
    , choices = class "choices"
    , choiceTable = class "choiceTable"
    , controlsGroup = class "controlsGroup"
    , controls = class "controls"
    , date = class "date"
    , descriptionColumn = class "descriptionColumn"
    , disabled = class "disabled"
    , editable = class "editable"
    , editing = class "editing"
    , editLine = class "editLine"
    , elements = class "elements"
    , info = class "info"
    , intervalSelection = class "intervalSection"
    , meals = class "meals"
    , numberCell = class "numberCell"
    , numberLabel = class "numberLabel"
    , nutrients = class "nutrients"
    , rating =
        { low = class "low"
        , exact = class "exact"
        , high = class "high"
        }
    , search =
        { area = class "searchArea"
        , field = class "searchField"
        }
    , tableHeader = class "tableHeader"
    , time = class "time"
    }


ids :
    { add : Attribute msg
    , addMealView : Attribute msg
    , addRecipeView : Attribute msg
    , error : Attribute msg
    , ingredientEditor : Attribute msg
    , login : Attribute msg
    , mealEntryEditor : Attribute msg
    , mealsButton : Attribute msg
    , navigation : Attribute msg
    , overviewMain : Attribute msg
    , recipesButton : Attribute msg
    , referenceNutrientEditor : Attribute msg
    , referenceNutrientsButton : Attribute msg
    , statistics : Attribute msg
    , statisticsButton : Attribute msg
    }
ids =
    { add = id "add"
    , addMealView = id "addMealView"
    , addRecipeView = id "addRecipeView"
    , error = id "error"
    , ingredientEditor = id "ingredientEditor"
    , login = id "login"
    , mealEntryEditor = id "mealEntryEditor"
    , mealsButton = id "mealsButton"
    , navigation = id "navigation"
    , overviewMain = id "overviewMain"
    , recipesButton = id "recipesButton"
    , referenceNutrientEditor = id "referenceNutrientEditor"
    , referenceNutrientsButton = id "referenceNutrientsButton"
    , statistics = id "statistics"
    , statisticsButton = id "statisticsButton"
    }
