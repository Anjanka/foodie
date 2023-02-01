package controllers.meal

import action.UserAction
import cats.data.{ EitherT, OptionT }
import db.{ MealEntryId, MealId }
import errors.{ ErrorContext, ServerError }
import io.circe.syntax._
import io.scalaland.chimney.dsl.TransformerOps
import play.api.libs.circe.Circe
import play.api.mvc._
import services.DBError
import services.common.RequestInterval
import services.meal.MealService
import utils.TransformerUtils.Implicits._

import java.util.UUID
import javax.inject.Inject
import scala.concurrent.ExecutionContext
import scala.util.chaining._

class MealController @Inject() (
    controllerComponents: ControllerComponents,
    mealService: MealService,
    userAction: UserAction
)(implicit ec: ExecutionContext)
    extends AbstractController(controllerComponents)
    with Circe {

  def all: Action[AnyContent] =
    userAction.async { request =>
      mealService
        .allMeals(
          userId = request.user.id,
          interval = RequestInterval(from = None, to = None).transformInto[services.common.RequestInterval]
        )
        .map(
          _.pipe(
            _.map(_.transformInto[Meal])
          )
            .pipe(_.asJson)
            .pipe(Ok(_))
        )
    }

  def get(id: UUID): Action[AnyContent] =
    userAction.async { request =>
      OptionT(mealService.getMeal(request.user.id, id.transformInto[MealId])).fold(
        NotFound(ErrorContext.Meal.NotFound.asServerError.asJson): Result
      )(
        _.pipe(_.transformInto[Meal])
          .pipe(_.asJson)
          .pipe(Ok(_))
      )
    }

  def create: Action[MealCreation] =
    userAction.async(circe.tolerantJson[MealCreation]) { request =>
      EitherT(
        mealService
          .createMeal(request.user.id, request.body.transformInto[services.meal.MealCreation])
      )
        .map(
          _.pipe(_.transformInto[Meal])
            .pipe(_.asJson)
            .pipe(Ok(_))
        )
        .fold(badRequest, identity)
        .recover(mealErrorHandler)
    }

  def update: Action[MealUpdate] =
    userAction.async(circe.tolerantJson[MealUpdate]) { request =>
      EitherT(
        mealService
          .updateMeal(request.user.id, request.body.transformInto[services.meal.MealUpdate])
      )
        .map(
          _.pipe(_.transformInto[Meal])
            .pipe(_.asJson)
            .pipe(Ok(_))
        )
        .fold(badRequest, identity)
        .recover(mealErrorHandler)
    }

  def delete(id: UUID): Action[AnyContent] =
    userAction.async { request =>
      mealService
        .deleteMeal(request.user.id, id.transformInto[MealId])
        .map(
          _.pipe(_.asJson)
            .pipe(Ok(_))
        )
    }

  def getMealEntries(id: UUID): Action[AnyContent] =
    userAction.async { request =>
      mealService
        .getMealEntries(
          request.user.id,
          id.transformInto[MealId]
        )
        .map(
          _.pipe(_.map(_.transformInto[MealEntry]).asJson)
            .pipe(Ok(_))
        )
        .recover(mealErrorHandler)
    }

  def addMealEntry: Action[MealEntryCreation] =
    userAction.async(circe.tolerantJson[MealEntryCreation]) { request =>
      EitherT(
        mealService.addMealEntry(
          userId = request.user.id,
          mealEntryCreation = request.body.transformInto[services.meal.MealEntryCreation]
        )
      )
        .fold(
          badRequest,
          _.pipe(_.transformInto[MealEntry])
            .pipe(_.asJson)
            .pipe(Ok(_))
        )
        .recover(mealErrorHandler)
    }

  def updateMealEntry: Action[MealEntryUpdate] =
    userAction.async(circe.tolerantJson[MealEntryUpdate]) { request =>
      EitherT(
        mealService.updateMealEntry(
          userId = request.user.id,
          mealEntryUpdate = request.body.transformInto[services.meal.MealEntryUpdate]
        )
      )
        .fold(
          badRequest,
          _.pipe(_.transformInto[MealEntry])
            .pipe(_.asJson)
            .pipe(Ok(_))
        )
        .recover(mealErrorHandler)
    }

  def deleteMealEntry(id: UUID): Action[AnyContent] =
    userAction.async { request =>
      mealService
        .removeMealEntry(request.user.id, id.transformInto[MealEntryId])
        .map(
          _.pipe(_.asJson)
            .pipe(Ok(_))
        )
    }

  private def badRequest(serverError: ServerError): Result =
    BadRequest(serverError.asJson)

  private def mealErrorHandler: PartialFunction[Throwable, Result] = {
    case error =>
      val context = error match {
        case DBError.Meal.NotFound =>
          ErrorContext.Meal.NotFound
        case DBError.Meal.EntryNotFound =>
          ErrorContext.Meal.Entry.NotFound
        case _ =>
          ErrorContext.Meal.General(error.getMessage)
      }

      BadRequest(context.asServerError.asJson)
  }

}
