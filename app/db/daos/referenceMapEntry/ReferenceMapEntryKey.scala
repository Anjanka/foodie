package db.daos.referenceMapEntry

import db.generated.Tables
import db.{ NutrientCode, ReferenceMapId }
import io.scalaland.chimney.dsl._
import utils.TransformerUtils.Implicits._

case class ReferenceMapEntryKey(
    referenceMapId: ReferenceMapId,
    nutrientCode: NutrientCode
)

object ReferenceMapEntryKey {

  def of(row: Tables.ReferenceEntryRow): ReferenceMapEntryKey =
    ReferenceMapEntryKey(
      row.referenceMapId.transformInto[ReferenceMapId],
      row.nutrientCode.transformInto[NutrientCode]
    )

}
