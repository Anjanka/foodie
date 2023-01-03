package services.stats

import algebra.ring.AdditiveSemigroup
import cats.data.EitherT
import cats.instances.list._
import cats.syntax.traverse._
import config.TestConfiguration
import errors.ServerError
import io.scalaland.chimney.dsl.TransformerOps
import org.scalacheck.Prop.AnyOperators
import org.scalacheck.{ Gen, Prop, Properties, Test }
import play.api.db.slick.DatabaseConfigProvider
import services._
import services.common.RequestInterval
import services.complex.food.ComplexFoodService
import services.complex.ingredient.ComplexIngredientService
import services.meal.{ FullMeal, Gens, Meal, MealEntry, MealService, MockMealService }
import services.nutrient.NutrientService
import services.recipe.{ FullRecipe, MockRecipeService, RecipeService }
import services.user.User
import spire.compat._
import spire.implicits._
import spire.math.interval._
import spire.math.{ Interval, Natural }
import utils.collection.MapUtil
import utils.date.Date

import java.time.LocalDate
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

object MealStatsProperties extends Properties("Meal stats") {
  private val nutrientServiceCompanion          = TestUtil.injector.instanceOf[NutrientService.Companion]
  private val complexFoodServiceCompanion       = TestUtil.injector.instanceOf[ComplexFoodService.Companion]
  private val complexIngredientServiceCompanion = TestUtil.injector.instanceOf[ComplexIngredientService.Companion]
  private val dbConfigProvider                  = TestUtil.injector.instanceOf[DatabaseConfigProvider]

  private def statsServiceWith(
      recipeServiceCompanion: RecipeService.Companion,
      mealServiceCompanion: MealService.Companion
  ): StatsService =
    new Live(
      dbConfigProvider = dbConfigProvider,
      companion = new Live.Companion(
        mealService = mealServiceCompanion,
        recipeService = recipeServiceCompanion,
        nutrientService = nutrientServiceCompanion,
        complexFoodService = complexFoodServiceCompanion,
        complexIngredientService = complexIngredientServiceCompanion
      )
    )

  private case class SetupUserAndRecipes(
      user: User,
      fullRecipes: List[FullRecipe]
  )

  private val maxNumberOfRecipesPerMeal = Natural(10)

  private val setupUserAndRecipesGen = for {
    user        <- GenUtils.userWithFixedPassword
    fullRecipes <- GenUtils.nonEmptyListOfAtMost(maxNumberOfRecipesPerMeal, recipe.Gens.fullRecipeGen())
  } yield SetupUserAndRecipes(
    user = user,
    fullRecipes = fullRecipes.toList
  )

  private def computeNutrientsPerMealEntry(fullRecipes: Map[RecipeId, FullRecipe])(
      mealEntry: MealEntry
  ) = {
    services.stats.ServiceFunctions
      .computeNutrientAmounts(fullRecipes(mealEntry.recipeId))
      .map(
        _.view
          .mapValues(
            _.map {
              // TODO: Comparing the numbers of existing and non-existing values
              //       is not directly possible in the current implementation
              //       but would improve the test quality.
              //       However, it may be tricky to find a good implementation
              //       that is sufficiently different from the one already used
              //       in the production code.
              case (_, value) => value * mealEntry.numberOfServings
            }
          )
          .toMap
      )
  }

  private case class PerMealSetup(
      userAndRecipes: SetupUserAndRecipes,
      fullMeal: FullMeal
  )

  private val perMealSetupGen: Gen[PerMealSetup] =
    for {
      userAndRecipeSetup <- setupUserAndRecipesGen
      fullMeal           <- meal.Gens.fullMealGen(userAndRecipeSetup.fullRecipes.map(_.recipe.id))
    } yield PerMealSetup(
      userAndRecipes = userAndRecipeSetup,
      fullMeal = fullMeal
    )

  property("Per meal stats") = Prop.forAll(
    perMealSetupGen :| "Per meal setup"
  ) { setup =>
    DBTestUtil.clearDb()
    val recipeMap = setup.userAndRecipes.fullRecipes.map(fr => fr.recipe.id -> fr).toMap
    val statsService = statsServiceWith(
      recipeServiceCompanion =
        MockRecipeService.fromCollection(Seq(setup.userAndRecipes.user.id -> setup.userAndRecipes.fullRecipes)),
      mealServiceCompanion = MockMealService.fromCollection(Seq(setup.userAndRecipes.user.id -> Seq(setup.fullMeal)))
    )

    val transformer = for {
      expectedNutrientValues <- EitherT.liftF[Future, ServerError, Map[NutrientId, Option[BigDecimal]]](
        setup.fullMeal.mealEntries
          .traverse(computeNutrientsPerMealEntry(recipeMap))
          .map(
            _.foldLeft(Map.empty[NutrientId, Option[BigDecimal]])(
              MapUtil.unionWith(_, _)(AdditiveSemigroup[Option[BigDecimal]].plus)
            )
          )
      )
      nutrientMapFromService <- EitherT.liftF[Future, ServerError, NutrientAmountMap](
        statsService.nutrientsOfMeal(setup.userAndRecipes.user.id, setup.fullMeal.meal.id)
      )
    } yield {
      val propsPerNutrient = GenUtils.allNutrients.map { nutrient =>
        val prop = PropUtil.closeEnough(
          nutrientMapFromService.get(nutrient).flatMap(_.value),
          expectedNutrientValues.get(nutrient.id).flatten
        )
        prop :| s"Correct values for nutrientId = ${nutrient.id}"
      }

      Prop.all(
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

  private case class OverTimeSetup(
      userAndRecipes: SetupUserAndRecipes,
      dateInterval: Interval[Date],
      fullMeals: List[FullMeal]
  )

  private def dateIntervalGen(earliest: Int, latest: Int): Gen[Interval[Date]] = {
    val smallerDateGen = Gen.option(GenUtils.dateGen(earliest, latest))
    for {
      date1 <- smallerDateGen
      date2 <- smallerDateGen
    } yield (date1, date2) match {
      case (Some(d1), Some(d2)) =>
        if (d1 <= d2)
          Interval.closed(d1, d2)
        else Interval.closed(d2, d1)
      case (Some(d1), None) => Interval.atOrAbove(d1)
      case (None, Some(d2)) => Interval.atOrBelow(d2)
      case _                => Interval.all[Date]
    }
  }

  private def overTimeSetupGen(
      range: Natural = Natural(1000)
  ): Gen[OverTimeSetup] = {
    val latest   = range.intValue
    val earliest = -latest

    for {
      dateInterval       <- dateIntervalGen(earliest, latest)
      userAndRecipeSetup <- setupUserAndRecipesGen
      fullMeals <-
        Gen.nonEmptyListOf(meal.Gens.fullMealGen(userAndRecipeSetup.fullRecipes.map(_.recipe.id), earliest, latest))
    } yield OverTimeSetup(
      userAndRecipes = userAndRecipeSetup,
      dateInterval = dateInterval,
      fullMeals = fullMeals
    )
  }

  property("Over time stats") = Prop.forAll(
    overTimeSetupGen() :| "Over time setup"
  ) { overTimeSetup =>
    DBTestUtil.clearDb()

    val statsService = statsServiceWith(
      recipeServiceCompanion = MockRecipeService.fromCollection(
        Seq(overTimeSetup.userAndRecipes.user.id -> overTimeSetup.userAndRecipes.fullRecipes)
      ),
      mealServiceCompanion =
        MockMealService.fromCollection(Seq(overTimeSetup.userAndRecipes.user.id -> overTimeSetup.fullMeals))
    )

    val mealsInInterval =
      overTimeSetup.fullMeals
        .filter(fullMeal => overTimeSetup.dateInterval.contains(fullMeal.meal.date.date))
    val fullRecipeMap = overTimeSetup.userAndRecipes.fullRecipes.map(fr => fr.recipe.id -> fr).toMap

    val transformer = for {
      expectedNutrientValues <- EitherT.liftF[Future, ServerError, Map[NutrientId, Option[BigDecimal]]](
        mealsInInterval
          .flatMap(_.mealEntries)
          .traverse(computeNutrientsPerMealEntry(fullRecipeMap))
          .map(
            _.foldLeft(Map.empty[NutrientId, Option[BigDecimal]])(
              MapUtil.unionWith(_, _)(AdditiveSemigroup[Option[BigDecimal]].plus)
            )
          )
      )
      statsFromService <- EitherT.liftF[Future, ServerError, Stats](
        statsService.nutrientsOverTime(
          overTimeSetup.userAndRecipes.user.id,
          toRequestInterval(overTimeSetup.dateInterval)
        )
      )
    } yield {
      val mealsProp: Prop =
        compareMealAndParametersInOrder(statsFromService.meals, mealsInInterval) :| "Correct meals"

      val propsPerNutrient = GenUtils.allNutrients.map { nutrient =>
        val prop = PropUtil.closeEnough(
          statsFromService.nutrientAmountMap.get(nutrient).flatMap(_.value),
          expectedNutrientValues.get(nutrient.id).flatten
        )
        prop :| s"Correct values for nutrientId = ${nutrient.id}"
      }

      Prop.all(
        mealsProp +:
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

  private case class RestrictedOverTimeSetup(
      user1: User,
      user2: User,
      meals1: List[Meal],
      meals2: List[Meal],
      dateInterval: Interval[Date]
  )

  private val restrictedOverTimeSetupGen: Gen[RestrictedOverTimeSetup] =
    for {
      (user1, user2) <- GenUtils.twoUsersGen
      meals1         <- Gen.nonEmptyListOf(Gens.mealGen())
      meals2         <- Gen.nonEmptyListOf(Gens.mealGen())
      dateInterval   <- dateIntervalGen(-10000, 10000)
    } yield RestrictedOverTimeSetup(
      user1 = user1,
      user2 = user2,
      meals1 = meals1,
      meals2 = meals2,
      dateInterval = dateInterval
    )

  // Regression test for a bug, where the meals were computed over all users.
  property("Meal stats restricted to user") = Prop.forAll(
    restrictedOverTimeSetupGen :| "restricted over time setup"
  ) { setup =>
    DBTestUtil.clearDb()

    val statsService = statsServiceWith(
      recipeServiceCompanion = MockRecipeService.fromCollection(
        Seq.empty
      ),
      mealServiceCompanion = MockMealService.fromCollection(
        Seq(
          setup.user1.id -> setup.meals1.map(FullMeal(_, List.empty)),
          setup.user2.id -> setup.meals2.map(FullMeal(_, List.empty))
        )
      )
    )
    val mealsInInterval =
      setup.meals1
        .filter(meal => setup.dateInterval.contains(meal.date.date))
    val transformer =
      for {
        statsFromService <- EitherT.liftF[Future, ServerError, Stats](
          statsService.nutrientsOverTime(
            setup.user1.id,
            toRequestInterval(setup.dateInterval)
          )
        )
      } yield compareMealAndParametersInOrder(
        statsFromService.meals,
        mealsInInterval.map(FullMeal(_, List.empty))
      )

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

  private def extractValue[A](bound: Bound[A]): Option[A] =
    bound match {
      case EmptyBound() => None
      case Unbound()    => None
      case Closed(x)    => Some(x)
      case Open(x)      => Some(x)
    }

  private def toRequestInterval(interval: Interval[Date]): RequestInterval = {
    def toLocalDate(bound: Bound[Date]) = extractValue(bound).map(_.transformInto[LocalDate])
    RequestInterval(
      from = toLocalDate(interval.lowerBound),
      to = toLocalDate(interval.upperBound)
    )
  }

  private def compareMealAndParametersInOrder(
      meals: Seq[Meal],
      fullMeals: Seq[FullMeal]
  ): Prop = {
    val lengthProp =
      (meals.length ?= fullMeals.length) :| "Correct number of meals"
    // TODO: This is a simplified assumption.
    //       It is possible for multiple meals to have the same date, and name, but contain different entries.
    //       The test could be extended by also comparing the recipe ids and amounts of the entries,
    //       which would lead to a sufficient equality in the sense that all comparable components are equal.
    //       In the current setting meal creations do not have uniquely identifying properties.
    val expectedDatesAndNames =
      fullMeals
        .map(fullMeal => (fullMeal.meal.date, fullMeal.meal.name))
        .sorted

    val actualDatesAndNames =
      meals
        .map(meal => (meal.date, meal.name))
        .sorted

    Prop.all(
      lengthProp,
      actualDatesAndNames ?= expectedDatesAndNames
    )
  }

  override def overrideParameters(p: Test.Parameters): Test.Parameters =
    p.withMinSuccessfulTests(TestConfiguration.default.property.minSuccessfulTests)

}
