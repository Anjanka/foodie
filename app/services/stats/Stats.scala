package services.stats

import java.time.LocalDate

import io.scalaland.chimney.dsl._
import services.meal.Meal
import services.nutrient.NutrientMap

case class Stats(
    meals: Seq[Meal],
    nutrientMap: NutrientMap,
    referenceNutrientMap: NutrientMap
)

object Stats {

  def dailyAverage(stats: Stats): NutrientMap = {
    val days = stats.meals
      .map(_.date.date)
      .distinct
      .map(_.transformInto[LocalDate])

    val numberOfDays = days.max.toEpochDay - days.min.toEpochDay

    stats.nutrientMap.view
      .mapValues(_ / numberOfDays)
      .toMap
  }

}
