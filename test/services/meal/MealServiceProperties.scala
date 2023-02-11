package services.meal

import cats.data.{ EitherT, NonEmptyList }
import config.TestConfiguration
import db._
import errors.{ ErrorContext, ServerError }
import org.scalacheck.Prop.AnyOperators
import org.scalacheck.{ Gen, Prop, Properties, Test }
import services.common.RequestInterval
import services.{ ContentsUtil, DBTestUtil, GenUtils, TestUtil }

import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.Future

object MealServiceProperties extends Properties("Meal service") {

  private val recipeIdsGen: Gen[NonEmptyList[RecipeId]] =
    Gen.nonEmptyListOf(GenUtils.taggedId[RecipeTag]).map(NonEmptyList.fromListUnsafe)

  private def mealServiceWith(
      mealContents: Seq[(UserId, Meal)],
      mealEntryContents: Seq[(MealId, MealEntry)]
  ): MealService =
    new Live(
      dbConfigProvider = TestUtil.databaseConfigProvider,
      companion = new Live.Companion(
        mealDao = DAOTestInstance.Meal.instanceFrom(mealContents),
        mealEntryDao = DAOTestInstance.MealEntry.instanceFrom(mealEntryContents)
      )
    )

  property("Creation") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId",
    Gens.mealCreationGen() :| "meal creation"
  ) { (userId, mealCreation) =>
    val mealService = mealServiceWith(
      mealContents = Seq.empty,
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      createdMeal <- EitherT(mealService.createMeal(userId, mealCreation))
      fetchedMeal <- EitherT.fromOptionF(
        mealService.getMeal(userId, createdMeal.id),
        ErrorContext.Meal.NotFound.asServerError
      )
    } yield {
      val expectedMeal = MealCreation.create(createdMeal.id, mealCreation)
      Prop.all(
        createdMeal ?= expectedMeal,
        fetchedMeal ?= expectedMeal
      )
    }

    DBTestUtil.awaitProp(transformer)
  }

  property("Read single") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId",
    Gens.mealGen() :| "meal creation"
  ) { (userId, meal) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(userId, Seq(meal)),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      fetchedMeal <- EitherT.fromOptionF(
        mealService.getMeal(userId, meal.id),
        ErrorContext.Meal.NotFound.asServerError
      )
    } yield fetchedMeal ?= meal

    DBTestUtil.awaitProp(transformer)
  }

  property("Read all") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId",
    Gen.listOf(Gens.mealGen()) :| "meal creations"
  ) { (userId, meals) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(userId, meals),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      fetchedMeals <- EitherT.liftF[Future, ServerError, Seq[Meal]](
        mealService.allMeals(userId, RequestInterval(None, None))
      )
    } yield fetchedMeals.sortBy(_.id) ?= meals.sortBy(_.id)

    DBTestUtil.awaitProp(transformer)
  }

  private case class UpdateSetup(
      userId: UserId,
      meal: Meal,
      mealUpdate: MealUpdate
  )

  private val updateSetupGen: Gen[UpdateSetup] =
    for {
      userId     <- GenUtils.taggedId[UserTag]
      meal       <- Gens.mealGen()
      mealUpdate <- Gens.mealUpdateGen(meal.id)
    } yield UpdateSetup(
      userId,
      meal,
      mealUpdate
    )

  property("Update") = Prop.forAll(
    updateSetupGen :| "update setup"
  ) { setup =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.meal)),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      updatedMeal <- EitherT(mealService.updateMeal(setup.userId, setup.mealUpdate))
      fetchedMeal <- EitherT.fromOptionF(
        mealService.getMeal(setup.userId, setup.meal.id),
        ErrorContext.Meal.NotFound.asServerError
      )
    } yield {
      val expectedMeal = MealUpdate.update(setup.meal, setup.mealUpdate)
      Prop.all(
        updatedMeal ?= expectedMeal,
        fetchedMeal ?= expectedMeal
      )
    }

    DBTestUtil.awaitProp(transformer)
  }

  property("Delete") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId",
    Gens.mealGen() :| "meal creation"
  ) { (userId, meal) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(userId, Seq(meal)),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      result  <- EitherT.liftF[Future, ServerError, Boolean](mealService.deleteMeal(userId, meal.id))
      fetched <- EitherT.liftF[Future, ServerError, Option[Meal]](mealService.getMeal(userId, meal.id))
    } yield Prop.all(
      Prop(result) :| "Deletion successful",
      Prop(fetched.isEmpty) :| "Meal should be deleted"
    )

    DBTestUtil.awaitProp(transformer)
  }

  private case class AddMealEntrySetup(
      userId: UserId,
      fullMeal: FullMeal,
      mealEntryCreation: MealEntryCreation
  )

  private val addMealEntrySetupGen: Gen[AddMealEntrySetup] = for {
    userId    <- GenUtils.taggedId[UserTag]
    recipeIds <- recipeIdsGen
    fullMeal  <- Gens.fullMealGen(recipeIds)
    mealEntry <- Gens.mealEntryGen(recipeIds)
  } yield AddMealEntrySetup(
    userId = userId,
    fullMeal = fullMeal,
    mealEntryCreation = MealEntryCreation(
      fullMeal.meal.id,
      mealEntry.recipeId,
      mealEntry.numberOfServings
    )
  )

  property("Add meal entry") = Prop.forAll(
    addMealEntrySetupGen :| "setup"
  ) { setup =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      mealEntry <- EitherT(mealService.addMealEntry(setup.userId, setup.mealEntryCreation))
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(setup.userId, setup.fullMeal.meal.id)
      )
    } yield {
      val expectedMealEntry = MealEntryCreation.create(mealEntry.id, setup.mealEntryCreation)
      mealEntries.sortBy(_.id) ?= (expectedMealEntry +: setup.fullMeal.mealEntries).sortBy(_.id)
    }

    DBTestUtil.awaitProp(transformer)
  }

  private case class ReadMealEntriesSetup(
      userId: UserId,
      fullMeal: FullMeal
  )

  private val readMealEntriesSetupGen: Gen[ReadMealEntriesSetup] = for {
    userId    <- GenUtils.taggedId[UserTag]
    recipeIds <- recipeIdsGen
    fullMeal  <- Gens.fullMealGen(recipeIds)
  } yield ReadMealEntriesSetup(
    userId = userId,
    fullMeal = fullMeal
  )

  property("Read meal entries") = Prop.forAll(
    readMealEntriesSetupGen :| "setup"
  ) { setup =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(setup.userId, setup.fullMeal.meal.id)
      )
    } yield mealEntries.sortBy(_.id) ?= setup.fullMeal.mealEntries.sortBy(_.id)

    DBTestUtil.awaitProp(transformer)
  }

  private case class UpdateMealEntrySetup(
      userId: UserId,
      fullMeal: FullMeal,
      mealEntry: MealEntry,
      mealEntryUpdate: MealEntryUpdate
  )

  private val updateMealEntrySetupGen: Gen[UpdateMealEntrySetup] = for {
    userId          <- GenUtils.taggedId[UserTag]
    recipeIds       <- recipeIdsGen
    fullMeal        <- Gens.fullMealGen(recipeIds)
    mealEntry       <- Gen.oneOf(fullMeal.mealEntries)
    mealEntryUpdate <- Gens.mealEntryUpdateGen(mealEntry.id, recipeIds)
  } yield UpdateMealEntrySetup(
    userId = userId,
    fullMeal = fullMeal,
    mealEntry = mealEntry,
    mealEntryUpdate = mealEntryUpdate
  )

  property("Update meal entry") = Prop.forAll(
    updateMealEntrySetupGen :| "setup"
  ) { setup =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      updatedMealEntry <- EitherT(mealService.updateMealEntry(setup.userId, setup.mealEntryUpdate))
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(setup.userId, setup.fullMeal.meal.id)
      )
    } yield {
      val expectedMealEntry = MealEntryUpdate.update(setup.mealEntry, setup.mealEntryUpdate)
      val expectedMealEntries = setup.fullMeal.mealEntries
        .map(mealEntry => mealEntry.id -> mealEntry)
        .toMap
        .updated(setup.mealEntry.id, expectedMealEntry)

      Prop.all(
        (updatedMealEntry ?= expectedMealEntry) :| "Update correct",
        (mealEntries
          .map(mealEntry => mealEntry.id -> mealEntry)
          .toMap ?= expectedMealEntries) :| "Meal entries after update correct"
      )
    }

    DBTestUtil.awaitProp(transformer)
  }

  private case class DeleteMealEntrySetup(
      userId: UserId,
      fullMeal: FullMeal,
      mealEntryId: MealEntryId
  )

  private val deleteMealEntrySetupGen: Gen[DeleteMealEntrySetup] =
    for {
      userId      <- GenUtils.taggedId[UserTag]
      recipeIds   <- recipeIdsGen
      fullMeal    <- Gens.fullMealGen(recipeIds)
      mealEntryId <- Gen.oneOf(fullMeal.mealEntries).map(_.id)
    } yield DeleteMealEntrySetup(
      userId = userId,
      fullMeal = fullMeal,
      mealEntryId = mealEntryId
    )

  property("Delete meal entry") = Prop.forAll(
    deleteMealEntrySetupGen :| "setup"
  ) { setup =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      deletionResult <- EitherT.liftF(mealService.removeMealEntry(setup.userId, setup.mealEntryId))
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(setup.userId, setup.fullMeal.meal.id)
      )
    } yield {
      val expectedMealEntries = setup.fullMeal.mealEntries.filter(_.id != setup.mealEntryId)
      Prop.all(
        Prop(deletionResult) :| "Deletion successful",
        (mealEntries.sortBy(_.id) ?= expectedMealEntries.sortBy(_.id)) :| "Meal entries after update correct"
      )
    }

    DBTestUtil.awaitProp(transformer)
  }

  property("Creation (wrong userId)") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId1",
    GenUtils.taggedId[UserTag] :| "userId2",
    Gens.mealCreationGen() :| "meal creation"
  ) { case (userId1, userId2, mealCreation) =>
    val mealService = mealServiceWith(
      mealContents = Seq.empty,
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      createdMeal <- EitherT(mealService.createMeal(userId1, mealCreation))
      fetchedMeal <- EitherT.liftF[Future, ServerError, Option[Meal]](mealService.getMeal(userId2, createdMeal.id))
    } yield Prop(fetchedMeal.isEmpty) :| "Access denied"

    DBTestUtil.awaitProp(transformer)
  }

  property("Read single (wrong userId)") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId1",
    GenUtils.taggedId[UserTag] :| "userId2",
    Gens.mealGen() :| "meal"
  ) { case (userId1, userId2, meal) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(userId1, Seq(meal)),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      fetchedMeal <- EitherT.liftF[Future, ServerError, Option[Meal]](
        mealService.getMeal(userId2, meal.id)
      )
    } yield Prop(fetchedMeal.isEmpty) :| "Access denied"

    DBTestUtil.awaitProp(transformer)
  }

  property("Read all (wrong userId)") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId1",
    GenUtils.taggedId[UserTag] :| "userId2",
    Gen.listOf(Gens.mealGen()) :| "meals"
  ) { case (userId1, userId2, meals) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(userId1, meals),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      fetchedMeals <- EitherT.liftF[Future, ServerError, Seq[Meal]](
        mealService.allMeals(userId2, RequestInterval(None, None))
      )
    } yield fetchedMeals ?= Seq.empty

    DBTestUtil.awaitProp(transformer)
  }

  private case class WrongUpdateSetup(
      userId1: UserId,
      userId2: UserId,
      meal: Meal,
      mealUpdate: MealUpdate
  )

  private val wrongUpdateSetupGen: Gen[WrongUpdateSetup] =
    for {
      userId1    <- GenUtils.taggedId[UserTag]
      userId2    <- GenUtils.taggedId[UserTag]
      meal       <- Gens.mealGen()
      mealUpdate <- Gens.mealUpdateGen(meal.id)
    } yield WrongUpdateSetup(
      userId1,
      userId2,
      meal,
      mealUpdate
    )

  property("Update (wrong userId)") = Prop.forAll(
    wrongUpdateSetupGen :| "setup"
  ) { setup =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId1, Seq(setup.meal)),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      updatedMeal <- EitherT.liftF[Future, ServerError, ServerError.Or[Meal]](
        mealService.updateMeal(setup.userId2, setup.mealUpdate)
      )
    } yield Prop(updatedMeal.isLeft)

    DBTestUtil.awaitProp(transformer)
  }

  property("Delete (wrong userId)") = Prop.forAll(
    GenUtils.taggedId[UserTag] :| "userId1",
    GenUtils.taggedId[UserTag] :| "userId2",
    Gens.mealGen() :| "meal"
  ) { case (userId1, userId2, meal) =>
    val mealService = mealServiceWith(
      mealContents = Seq(userId1 -> meal),
      mealEntryContents = Seq.empty
    )
    val transformer = for {
      result <- EitherT.liftF[Future, ServerError, Boolean](mealService.deleteMeal(userId2, meal.id))
    } yield Prop(!result) :| "Deletion failed"

    DBTestUtil.awaitProp(transformer)
  }

  property("Add meal entry (wrong userId)") = Prop.forAll(
    addMealEntrySetupGen :| "setup",
    GenUtils.taggedId[UserTag] :| "userId2"
  ) { (setup, userId2) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      result <- EitherT.liftF(mealService.addMealEntry(userId2, setup.mealEntryCreation))
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(setup.userId, setup.fullMeal.meal.id)
      )
    } yield Prop.all(
      Prop(result.isLeft) :| "MealEntry addition failed",
      mealEntries.sortBy(_.id) ?= setup.fullMeal.mealEntries.sortBy(_.id)
    )

    DBTestUtil.awaitProp(transformer)
  }

  property("Read meal entries (wrong userId)") = Prop.forAll(
    readMealEntriesSetupGen :| "setup",
    GenUtils.taggedId[UserTag] :| "userId2"
  ) { (setup, userId2) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(userId2, setup.fullMeal.meal.id)
      )
    } yield mealEntries ?= List.empty

    DBTestUtil.awaitProp(transformer)
  }

  property("Update meal entry (wrong userId)") = Prop.forAll(
    updateMealEntrySetupGen :| "setup",
    GenUtils.taggedId[UserTag] :| "userId2"
  ) { (setup, userId2) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      result <- EitherT.liftF(mealService.updateMealEntry(userId2, setup.mealEntryUpdate))
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(setup.userId, setup.fullMeal.meal.id)
      )
    } yield Prop.all(
      Prop(result.isLeft) :| "Meal entry update failed",
      (mealEntries.sortBy(_.id) ?= setup.fullMeal.mealEntries.sortBy(
        _.id
      )) :| "Meal entries after update correct"
    )

    DBTestUtil.awaitProp(transformer)
  }

  property("Delete mealEntry (wrong userId)") = Prop.forAll(
    deleteMealEntrySetupGen :| "setup",
    GenUtils.taggedId[UserTag] :| "userId2"
  ) { (setup, userId2) =>
    val mealService = mealServiceWith(
      mealContents = ContentsUtil.Meal.from(setup.userId, Seq(setup.fullMeal.meal)),
      mealEntryContents = ContentsUtil.MealEntry.from(setup.fullMeal)
    )
    val transformer = for {
      deletionResult <- EitherT.liftF(mealService.removeMealEntry(userId2, setup.mealEntryId))
      mealEntries <- EitherT.liftF[Future, ServerError, Seq[MealEntry]](
        mealService.getMealEntries(setup.userId, setup.fullMeal.meal.id)
      )
    } yield {
      val expectedMealEntries = setup.fullMeal.mealEntries
      Prop.all(
        Prop(!deletionResult) :| "Meal entry deletion failed",
        (mealEntries.sortBy(_.id) ?= expectedMealEntries.sortBy(_.id)) :| "Meal entries after update correct"
      )
    }

    DBTestUtil.awaitProp(transformer)
  }

  override def overrideParameters(p: Test.Parameters): Test.Parameters =
    p.withMinSuccessfulTests(TestConfiguration.default.property.minSuccessfulTests.withoutDB)

}
