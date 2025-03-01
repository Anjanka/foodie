package services.meal

import db.{ MealEntryId, RecipeId }

case class MealEntryUpdate(
    id: MealEntryId,
    recipeId: RecipeId,
    numberOfServings: BigDecimal
)

object MealEntryUpdate {

  def update(mealEntry: MealEntry, mealEntryUpdate: MealEntryUpdate): MealEntry =
    mealEntry.copy(
      numberOfServings = mealEntryUpdate.numberOfServings
    )

}
