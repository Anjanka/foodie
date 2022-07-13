import com.typesafe.config.ConfigFactory

name := """foodie"""
organization := "io.danilenko"

version := "1.0-SNAPSHOT"

val circeVersion = "0.14.2"
val slickVersion = "3.3.3"

val config = ConfigFactory
  .parseFile(new File("conf/application.conf"))
  .resolve()

lazy val root = (project in file("."))
  .enablePlugins(PlayScala)
  .enablePlugins(CodegenPlugin)
  .settings(
    scalaVersion := "2.13.2",
    libraryDependencies ++= Seq(
      guice,
      "com.typesafe.slick"   %% "slick"           % slickVersion,
      "com.typesafe.slick"   %% "slick-hikaricp"  % slickVersion,
      "com.typesafe.slick"   %% "slick-codegen"   % slickVersion,
      "org.postgresql"        % "postgresql"      % "42.3.6",
      "ch.qos.logback"        % "logback-classic" % "1.2.11",
      "io.circe"             %% "circe-core"      % circeVersion,
      "io.circe"             %% "circe-generic"   % circeVersion,
      "io.circe"             %% "circe-parser"    % circeVersion,
      "org.typelevel"        %% "spire"           % "0.17.0-M1",
      "org.flywaydb"         %% "flyway-play"     % "7.20.0",
      "com.typesafe.play"    %% "play-slick"      % "5.0.2",
      "com.dripower"         %% "play-circe"      % "2814.2",
      "com.davegurnell"      %% "bridges"         % "0.24.0",
      "com.github.pathikrit" %% "better-files"    % "3.9.1",
      "com.typesafe"          % "config"          % "1.4.2",
      "io.scalaland"         %% "chimney"         % "0.6.1"
    ),
    slickCodegenDatabaseUrl := config.getString("slick.dbs.default.db.url"),
    slickCodegenDatabaseUser := config.getString("slick.dbs.default.db.user"),
    slickCodegenDatabasePassword := config.getString("slick.dbs.default.db.password"),
    slickCodegenDriver := slick.jdbc.PostgresProfile,
    slickCodegenJdbcDriver := "org.postgresql.Driver",
    slickCodegenOutputPackage := "db.generated",
    slickCodegenExcludedTables := Seq("flyway_schema_history"),
    slickCodegenOutputDir := baseDirectory.value / "app"
  )

scalacOptions ++= Seq(
  "-Ymacro-annotations"
)

lazy val elmGenerate = Command.command("elmGenerate") { state =>
  "runMain elm.Bridge" :: state
}

commands += elmGenerate
