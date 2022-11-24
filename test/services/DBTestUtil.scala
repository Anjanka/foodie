package services

import db.generated.Tables
import play.api.db.slick.DatabaseConfigProvider
import slick.jdbc.PostgresProfile
import slick.jdbc.PostgresProfile.api._

import scala.concurrent.{ Await, Future }
import scala.concurrent.duration.{ Duration, _ }

object DBTestUtil {

  val defaultAwaitTimeout: Duration  = 2.minutes
  private val databaseConfigProvider = TestUtil.injector.instanceOf[DatabaseConfigProvider]

  def clearDb(): Unit =
    await(
      dbRun(
        /* The current structure links everything to users at the
             root level, which is why it is sufficient to delete all
             users to also clear all non-CNF tables.
         */
        Tables.User.delete
      )
    )

  def dbRun[A](action: DBIO[A]): Future[A] =
    databaseConfigProvider
      .get[PostgresProfile]
      .db
      .run(action)

  def await[A](future: Future[A], timeout: Duration = defaultAwaitTimeout): A =
    Await.result(
      awaitable = future,
      atMost = timeout
    )

}
