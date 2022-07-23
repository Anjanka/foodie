package controllers.meal

import io.circe.generic.JsonCodec
import io.scalaland.chimney.Transformer
import utils.SimpleDate

import java.util.UUID

@JsonCodec
case class MealUpdate(
    mealId: UUID,
    date: SimpleDate,
    recipeId: UUID,
    amount: BigDecimal
)

object MealUpdate {

  implicit val toDomain: Transformer[MealUpdate, services.meal.MealUpdate] =
    Transformer
      .define[MealUpdate, services.meal.MealUpdate]
      .buildTransformer

}
