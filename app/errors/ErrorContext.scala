package errors

sealed trait ErrorContext {
  def message: String
}

object ErrorContext {

  sealed abstract class ServerErrorInstance(override val message: String) extends ErrorContext

  /* No automatic derivation to avoid upcasting issue, since any instance of ErrorContext has a more precise type. */
  implicit class ErrorContextToServerError(val errorContext: ErrorContext) extends AnyVal {
    def asServerError: ServerError = ServerError.fromContext(errorContext)
  }

  object Login {
    case object Failure extends ServerErrorInstance("Invalid combination of user name and password.")
  }

  object Authentication {

    object Token {
      case object Decoding extends ServerErrorInstance("Error decoding JWT: Format or signature is wrong")
      case object Content  extends ServerErrorInstance("Error parsing JWT content: Unexpected format")
      case object Missing  extends ServerErrorInstance("Missing JWT")
    }

  }

  object User {
    case object NotFound extends ServerErrorInstance("No user with the given id found")
  }

  object Recipe {
    case object NotFound extends ServerErrorInstance("No recipe with the given id found")

    case class Creation(dbMessage: String)
        extends ServerErrorInstance(
          s"Recipe creation failed due to: $dbMessage"
        )

    case class General(dbMessage: String)
        extends ServerErrorInstance(
          s"A database operation failed with the message: $dbMessage"
        )

    object Ingredient {

      case class Creation(dbMessage: String)
          extends ServerErrorInstance(
            s"Ingredient creation failed due to: $dbMessage"
          )

      case object NotFound extends ServerErrorInstance("No ingredient with the given id found")

    }

  }

  object Meal {
    case object NotFound extends ServerErrorInstance("No meal with the given id found")

    object Entry {

      case class Creation(dbMessage: String)
          extends ServerErrorInstance(
            s"Entry creation failed due to: $dbMessage"
          )

      case object NotFound extends ServerErrorInstance("No entry with the given id found")

    }

  }

}
