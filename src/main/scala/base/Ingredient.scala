package base

import physical.{NamedUnit, Prefix}

trait Ingredient[N] {

  /**
    * @return The nutritional palette of a given ingredient per the base reference mass (usually 100g).
    */
  def basePalette: Functional[NamedUnit[N, _, _], Nutrient]

  /**
    * @return The reference mass.
    *         Each amount of this ingredient contains precisely the nutritional values
    *         provided in [[basePalette]].
    */
  def baseReference: Mass[N, _]

  /**
    * @tparam P The prefix type.
    * @return The density of the ingredient as weight per millilitre.
    */
  def weightPerMillilitre[P: Prefix]: Mass[N, P]
}
