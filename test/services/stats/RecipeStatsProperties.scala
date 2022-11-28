package services.stats

import cats.data.{ EitherT, OptionT }
import cats.instances.list._
import cats.syntax.traverse._
import db.generated.Tables
import errors.ErrorContext
import io.scalaland.chimney.dsl._
import org.scalacheck.Prop._
import org.scalacheck.{ Prop, Properties }
import services._
import services.recipe.{ Ingredient, Recipe, RecipeService }
import services.user.UserService
import slick.jdbc.PostgresProfile.api._
import spire.math.Natural
import utils.DBIOUtil.instances._
import utils.TransformerUtils.Implicits._

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

object RecipeStatsProperties extends Properties("Recipe stats") {

  private val recipeService = TestUtil.injector.instanceOf[RecipeService]
  private val userService   = TestUtil.injector.instanceOf[UserService]
  private val statsService  = TestUtil.injector.instanceOf[StatsService]

  property("Per serving stats") = Prop.forAll(
    Gens.userWithFixedPassword :| "User",
    StatsGens.recipeParametersGen :| "Recipe parameters"
  ) { (user, recipeParameters) =>
    DBTestUtil.clearDb()
    val transformer = for {
      _      <- EitherT.liftF(userService.add(user))
      recipe <- EitherT(recipeService.createRecipe(user.id, recipeParameters.recipeCreation))
      ingredients <- recipeParameters.ingredientParameters.traverse(ip =>
        EitherT(
          recipeService.addIngredient(
            userId = user.id,
            ingredientCreation = IngredientPreCreation.toCreation(recipe.id, ip.ingredientPreCreation)
          )
        )
      )
      expectedNutrientValues <- EitherT.liftF(computeNutrientAmounts(recipe, ingredients))
      nutrientMapFromService <- EitherT.fromOptionF(
        statsService.nutrientsOfRecipe(user.id, recipe.id),
        ErrorContext.Recipe.NotFound.asServerError
      )
    } yield {
      val lengthProp: Prop =
        (ingredients.length ?= recipeParameters.ingredientParameters.length) :| "Correct ingredient number"
      val distinctIngredients = ingredients.distinctBy(_.foodId).length

      val propsPerNutrient = StatsGens.allNutrients.map { nutrient =>
        val prop = (nutrientMapFromService.get(nutrient), expectedNutrientValues.get(nutrient.id)) match {
          case (Some(actual), Some(expected)) =>
            val (expectedSize, expectedValue) = expected.fold((0, Option.empty[BigDecimal])) {
              case (size, value) => size -> Some(value)
            }
            Prop.all(
              closeEnough(actual.value, expectedValue) :| "Value correct",
              (actual.numberOfDefinedValues ?= Natural(expectedSize)) :| "Number of defined values correct",
              (actual.numberOfIngredients ?= Natural(distinctIngredients)) :| "Total number of ingredients matches"
            )
          case (None, None) => Prop.passed
          case _            => Prop.falsified
        }
        prop :| s"Correct values for nutrientId = ${nutrient.id}"
      }

      Prop.all(
        lengthProp +:
          propsPerNutrient: _*
      )
    }

    DBTestUtil.await(
      transformer.fold(
        error => {
          pprint.log(error.message)
          Prop.exception
        },
        identity
      )
    )
  }

  private def closeEnough(
      actual: Option[BigDecimal],
      expected: Option[BigDecimal],
      error: BigDecimal = BigDecimal(0.0000000001)
  ): Prop =
    (actual, expected) match {
      case (Some(av), Some(ev)) =>
        ((ev - av).abs < error) :| s"Distance between expected value $ev and actual value $av is smaller than $error"
      case (None, None) =>
        Prop.passed
      case _ => Prop.falsified :| s"Expected $expected, but got $actual"
    }

  private def computeNutrientAmount(
      nutrientId: NutrientId,
      ingredients: Seq[Ingredient]
  ): DBIO[Option[(Int, BigDecimal)]] = {
    val transformer =
      for {
        conversionFactors <-
          ingredients
            .traverse { ingredient =>
              OptionT
                .fromOption[DBIO](ingredient.amountUnit.measureId)
                .subflatMap(measureId => StatsGens.allConversionFactors.get((ingredient.foodId, measureId)))
                .orElseF(DBIO.successful(Some(BigDecimal(1))))
                .map(ingredient.id -> _)
            }
            .map(_.toMap)
        nutrientAmounts <- OptionT.liftF(nutrientAmountOf(nutrientId, ingredients.map(_.foodId)))
        ingredientAmounts = ingredients.flatMap { ingredient =>
          nutrientAmounts.get(ingredient.foodId).map { nutrientAmount =>
            nutrientAmount *
              ingredient.amountUnit.factor *
              conversionFactors(ingredient.id)
          }
        }
        amounts <- OptionT.fromOption[DBIO](Some(ingredientAmounts).filter(_.nonEmpty))
      } yield (nutrientAmounts.keySet.size, amounts.sum)

    transformer.value
  }

  private def nutrientAmountOf(
      nutrientId: NutrientId,
      foodIds: Seq[FoodId]
  ): DBIO[Map[FoodId, BigDecimal]] = {
    val baseMap = Tables.NutrientAmount
      .filter(na =>
        na.nutrientId === nutrientId.transformInto[Int]
          && na.foodId.inSetBind(foodIds.map(_.transformInto[Int]))
      )
      .result
      .map { nutrientAmounts =>
        nutrientAmounts
          .map(na => na.foodId.transformInto[FoodId] -> na.nutrientValue)
          .toMap
      }
    /* The constellation of foodId = 534 and nutrientId = 339 has no entry in the
       amount table, but there is an entry referencing the non-existing nutrientId = 328,
       with the value 0.1.
       There is no nutrient with id 328, but there is one nutrient with the *code* 328,
       and this nutrient has the id 339.
       The assumption is that this reference has been added by mistake,
       hence we correct this mistake here.
     */
    val erroneousNutrientId = 339.transformInto[NutrientId]
    val erroneousFoodId     = 534.transformInto[FoodId]
    if (nutrientId == erroneousNutrientId && foodIds.contains(erroneousFoodId)) {
      baseMap.map(_.updated(erroneousFoodId, BigDecimal(0.1)))
    } else {
      baseMap
    }
  }

  private def computeNutrientAmounts(
      recipe: Recipe,
      ingredients: List[Ingredient]
  ): Future[Map[NutrientId, Option[(Int, BigDecimal)]]] = {
    DBTestUtil.dbRun {
      StatsGens.allNutrients
        .traverse { nutrient =>
          computeNutrientAmount(nutrient.id, ingredients)
            .map(v =>
              nutrient.id ->
                v.map { case (number, value) => number -> value / recipe.numberOfServings }
            ): DBIO[(NutrientId, Option[(Int, BigDecimal)])]
        }
        .map(_.toMap)
    }
  }

}
