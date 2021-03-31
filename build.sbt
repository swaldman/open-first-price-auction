name := "open-first-price-auction"

organization := "com.mchange"

version := "0.0.1-SNAPSHOT"

scalaVersion := "2.12.13"

resolvers += ("releases" at "https://oss.sonatype.org/service/local/staging/deploy/maven2")

resolvers += ("snapshots" at "https://oss.sonatype.org/content/repositories/snapshots")

resolvers += ("Typesafe repository" at "https://repo.typesafe.com/typesafe/releases/")

ethcfgScalaStubsPackage := "com.mchange.sc.v1.auction.firstprice.contract"

Test / ethcfgAutoDeployContracts := Seq( "TestAuctioneer" )

Test / parallelExecution := false

libraryDependencies += "org.specs2" %% "specs2-core" % "4.0.2" % "test"
