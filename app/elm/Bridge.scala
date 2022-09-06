package elm

import better.files._
import bridges.core.Type.Ref
import bridges.core._
import bridges.core.syntax._
import bridges.elm._
import controllers.login.Credentials
import controllers.meal._
import controllers.recipe._
import controllers.stats.{ Amounts, NutrientInformation, NutrientUnit, Stats }
import shapeless.Lazy
import utils.date.{ Date, SimpleDate, Time }

import scala.reflect.runtime.universe.TypeTag

object Bridge {

  val elmModule: String       = "Api.Types"
  val elmModuleFilePath: File = "frontend" / "src" / "Api" / "Types"

  def mkElmBridge[A](implicit tpeTag: TypeTag[A], encoder: Lazy[Encoder[A]]): (String, String) = {
    val (fileName, content) = Elm.buildFile(
      module = elmModule,
      decl = decl[A],
      customTypeReplacements = Map(
        Ref("UUID")
          -> TypeReplacement(
            "UUID",
            imports = s"\nimport $elmModule.UUID exposing (..)",
            encoder = "encoderUUID",
            decoder = "decoderUUID"
          )
      )
    )

    // Simplified assumption: the encoder and the value do not contain spaces or parentheses.
    val encodeListMatch = """Encode.list \(List.map ([^)\s]*) ([^)\s]*)\)""".r
    val updatedContent  =
      /* The bridge library puts a no longer existing function call here,
         which is why we manually replace it with the correct function.*/
      content
        .replaceAll(" decode ", " Decode.succeed ")
        // Workaround for issue #195 in the bridges library
        .replaceAll(
          "import Json.Decode as Decode\n\nimport Json.Encode as Encode",
          "import Json.Decode as Decode\nimport Json.Decode.Pipeline exposing (..)\nimport Json.Encode as Encode"
        )
    fileName ->
      // Workaround for issue #193 in the bridges library
      encodeListMatch
        .replaceAllIn(
          updatedContent,
          _ match {
            case encodeListMatch(encoder, value) =>
              s"Encode.list $encoder $value"
          }
        )
  }

  def mkAndWrite[A](implicit tpeTag: TypeTag[A], encoder: Lazy[Encoder[A]]): Unit = {
    val (filePath, content) = mkElmBridge[A]
    val file = (
      elmModuleFilePath /
        filePath
    ).createIfNotExists(createParents = true)
    file.write(content)
  }

  def main(args: Array[String]): Unit = {
    mkAndWrite[Date]
    mkAndWrite[Time]
    mkAndWrite[SimpleDate]
    mkAndWrite[RequestInterval]
    mkAndWrite[Meal]
    mkAndWrite[MealCreation]
    mkAndWrite[MealUpdate]
    mkAndWrite[MealEntry]
    mkAndWrite[MealEntryCreation]
    mkAndWrite[MealEntryUpdate]
    mkAndWrite[Credentials]
    mkAndWrite[AmountUnit]
    mkAndWrite[Food]
    mkAndWrite[Ingredient]
    mkAndWrite[IngredientCreation]
    mkAndWrite[IngredientUpdate]
    mkAndWrite[Measure]
    mkAndWrite[Recipe]
    mkAndWrite[RecipeCreation]
    mkAndWrite[RecipeUpdate]
    mkAndWrite[Amounts]
    mkAndWrite[NutrientInformation]
    mkAndWrite[NutrientUnit]
    mkAndWrite[Stats]
  }

}
