package utils.jwt

import errors.{ ErrorContext, ServerError }
import io.circe.syntax._
import io.scalaland.chimney.dsl._
import pdi.jwt.algorithms.JwtAsymmetricAlgorithm
import pdi.jwt.{ JwtAlgorithm, JwtCirce, JwtClaim, JwtHeader }
import security.jwt.{ JwtContent, JwtExpiration }
import services.user.UserId
import utils.IdUtils.Implicits._

import java.util.UUID

object JwtUtil {

  val signatureAlgorithm: JwtAsymmetricAlgorithm = JwtAlgorithm.RS256

  def validateJwt(token: String, publicKey: String): ServerError.Or[JwtContent] =
    JwtCirce
      .decode(token, publicKey, Seq(signatureAlgorithm))
      .toEither
      .left
      .map(_ => ErrorContext.Authentication.Token.Decoding.asServerError)
      .flatMap { jwtClaim =>
        io.circe.parser
          .decode[JwtContent](jwtClaim.content)
          .left
          .map(_ => ErrorContext.Authentication.Token.Content.asServerError)
      }

  def createJwt(userId: UserId, privateKey: String, expiration: JwtExpiration): String =
    JwtCirce.encode(
      header = JwtHeader(algorithm = signatureAlgorithm),
      claim = JwtClaim(
        content = JwtContent(
          userId = userId.transformInto[UUID]
        ).asJson.noSpaces,
        expiration = expiration.expirationAt,
        notBefore = expiration.notBefore
      ),
      key = privateKey
    )

}
