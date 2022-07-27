package services.meal

import services.{ MealEntryId, MealId, RecipeId }

case class MealEntryCreation(
    mealId: MealId,
    recipeId: RecipeId,
    factor: BigDecimal
)

object MealEntryCreation {

  def create(id: MealEntryId, mealEntryCreation: MealEntryCreation): MealEntry =
    MealEntry(
      id = id,
      recipeId = mealEntryCreation.recipeId,
      factor = mealEntryCreation.factor
    )

}
