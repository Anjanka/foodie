package services.stats

import algebra.ring.AdditiveMonoid
import cats.data.OptionT
import cats.syntax.traverse._
import db.generated.Tables
import io.scalaland.chimney.dsl.TransformerOps
import play.api.db.slick.{ DatabaseConfigProvider, HasDatabaseConfigProvider }
import services.complex.ingredient.ComplexIngredientService
import services.meal.{ MealEntry, MealService }
import services.nutrient.{ AmountEvaluation, NutrientMap, NutrientService }
import services.recipe.{ Recipe, RecipeService }
import services.{ FoodId, MealId, RecipeId, UserId }
import slick.dbio.DBIO
import slick.jdbc.PostgresProfile
import slick.jdbc.PostgresProfile.api._
import spire.implicits._
import spire.math.Natural
import utils.DBIOUtil
import utils.DBIOUtil.instances._
import utils.TransformerUtils.Implicits._
import utils.collection.MapUtil

import javax.inject.Inject
import scala.concurrent.{ ExecutionContext, Future }

trait StatsService {

  def nutrientsOverTime(userId: UserId, requestInterval: RequestInterval): Future[Stats]

}

object StatsService {

  class Live @Inject() (
      override protected val dbConfigProvider: DatabaseConfigProvider,
      companion: Companion
  )(implicit
      ec: ExecutionContext
  ) extends StatsService
      with HasDatabaseConfigProvider[PostgresProfile] {

    override def nutrientsOverTime(userId: UserId, requestInterval: RequestInterval): Future[Stats] =
      db.run(companion.nutrientsOverTime(userId, requestInterval))

  }

  trait Companion {
    def nutrientsOverTime(userId: UserId, requestInterval: RequestInterval)(implicit ec: ExecutionContext): DBIO[Stats]

  }

  object Live extends Companion {

    private case class RecipeNutrientMap(
        recipe: Recipe,
        nutrientMap: NutrientMap,
        foodIds: Set[FoodId]
    )

    override def nutrientsOverTime(
        userId: UserId,
        requestInterval: RequestInterval
    )(implicit
        ec: ExecutionContext
    ): DBIO[Stats] = {
      val dateFilter = DBIOUtil.dateFilter(requestInterval.from, requestInterval.to)
      for {
        mealIdsPlain <- Tables.Meal.filter(m => dateFilter(m.consumedOnDate)).map(_.id).result
        mealIds = mealIdsPlain.map(_.transformInto[MealId])
        meals <- mealIds.traverse(MealService.Live.getMeal(userId, _)).map(_.flatten)
        mealEntries <-
          mealIds
            .traverse(mealId =>
              MealService.Live
                .getMealEntries(userId, mealId)
                .map(mealId -> _): DBIO[(MealId, Seq[MealEntry])]
            )
            .map(_.toMap)
        nutrientsPerRecipe <-
          mealIds
            .flatMap(mealEntries(_).map(_.recipeId))
            .distinct
            .traverse { recipeId =>
              nutrientsOfRecipe(userId, recipeId)
                .map(recipeId -> _)
                .value
            }
            .map(_.flatten.toMap)
        allNutrients <- NutrientService.Live.all
      } yield {
        val nutrientMap = meals
          .flatMap(m => mealEntries(m.id))
          .map { me =>
            val recipeNutrientMap = nutrientsPerRecipe(me.recipeId)
            (me.numberOfServings / recipeNutrientMap.recipe.numberOfServings) *: recipeNutrientMap.nutrientMap
          }
          .qsum
        val totalNumberOfIngredients = nutrientsPerRecipe.values.flatMap(_.foodIds).toSet.size
        Stats(
          meals = meals,
          nutrientMap = MapUtil
            .unionWith(
              nutrientMap,
              allNutrients.map(n => n -> AdditiveMonoid[AmountEvaluation].zero).toMap
            )((x, _) => x)
            .view
            .mapValues(amountEvaluation =>
              Amount(
                value = Some(amountEvaluation.amount).filter(_ => amountEvaluation.encounteredFoodIds.nonEmpty),
                numberOfIngredients = Natural(totalNumberOfIngredients),
                numberOfDefinedValues = Natural(amountEvaluation.encounteredFoodIds.size)
              )
            )
            .toMap
        )
      }
    }

    private def nutrientsOfRecipe(
        userId: UserId,
        recipeId: RecipeId
    )(implicit
        ec: ExecutionContext
    ): OptionT[DBIO, RecipeNutrientMap] =
      for {
        recipe             <- OptionT(RecipeService.Live.getRecipe(userId, recipeId))
        ingredients        <- OptionT.liftF(RecipeService.Live.getIngredients(userId, recipeId))
        complexIngredients <- OptionT.liftF(ComplexIngredientService.Live.all(userId, recipeId))
        nutrients          <- OptionT.liftF(NutrientService.Live.nutrientsOfIngredients(ingredients))
        recipeNutrientMapsOfComplexNutrients <-
          complexIngredients
            .traverse { complexIngredient =>
              nutrientsOfRecipe(userId, complexIngredient.complexFoodId)
                .map(recipeNutrientMap =>
                  recipeNutrientMap.copy(nutrientMap = complexIngredient.factor *: recipeNutrientMap.nutrientMap)
                )
            }
      } yield RecipeNutrientMap(
        recipe = recipe,
        nutrientMap = nutrients + recipeNutrientMapsOfComplexNutrients.map(_.nutrientMap).qsum,
        foodIds = ingredients.map(_.foodId).toSet ++ recipeNutrientMapsOfComplexNutrients.flatMap(_.foodIds)
      )

  }

}
