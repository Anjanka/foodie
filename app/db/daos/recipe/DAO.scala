package db.daos.recipe

import db.DAOActions
import db.generated.Tables
import io.scalaland.chimney.dsl._
import slick.jdbc.PostgresProfile.api._
import utils.TransformerUtils.Implicits._

import java.util.UUID

trait DAO extends DAOActions.Instance[Tables.RecipeRow, Tables.Recipe, RecipeKey]

object DAO {

  val instance: DAO =
    new DAOActions.Instance[Tables.RecipeRow, Tables.Recipe, RecipeKey](
      Tables.Recipe,
      (table, key) => table.userId === key.userId.transformInto[UUID] && table.id === key.recipeId.transformInto[UUID]
    ) with DAO

}
