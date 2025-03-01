package services.recipe

import db.generated.Tables
import db.{ RecipeId, UserId }
import io.scalaland.chimney.Transformer
import io.scalaland.chimney.dsl.TransformerOps
import utils.TransformerUtils.Implicits._

import java.util.UUID

case class Recipe(
    id: RecipeId,
    name: String,
    description: Option[String],
    numberOfServings: BigDecimal,
    servingSize: Option[String]
)

object Recipe {

  implicit val fromDB: Transformer[Tables.RecipeRow, Recipe] =
    Transformer
      .define[Tables.RecipeRow, Recipe]
      .buildTransformer

  implicit val toDB: Transformer[(Recipe, UserId), Tables.RecipeRow] = { case (recipe, userId) =>
    Tables.RecipeRow(
      id = recipe.id.transformInto[UUID],
      userId = userId.transformInto[UUID],
      name = recipe.name,
      description = recipe.description,
      numberOfServings = recipe.numberOfServings,
      servingSize = recipe.servingSize
    )

  }

}
