package controllers.recipe

import io.circe.generic.JsonCodec

@JsonCodec
case class IngredientWithAmount(
    ingredient: Ingredient,
    amount: BigDecimal
)
