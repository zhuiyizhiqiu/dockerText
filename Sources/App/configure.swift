/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import FluentPostgreSQL
import Vapor
import Leaf
import Authentication

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
  /// Register providers first
  try services.register(FluentPostgreSQLProvider())
  try services.register(LeafProvider())
  try services.register(AuthenticationProvider())

  /// Register routes to the router
  let router = EngineRouter.default()
  try routes(router)
  services.register(router, as: Router.self)

  /// Register middleware
  var middlewares = MiddlewareConfig() // Create _empty_ middleware config
  middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
  middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
  middlewares.use(SessionsMiddleware.self)
  services.register(middlewares)

  // Configure a database
  var databases = DatabasesConfig()
  let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
  let databaseName: String
  let databasePort: Int
  if (env == .testing) {
    databaseName = "vapor-test"
    if let testPort = Environment.get("DATABASE_PORT") {
      databasePort = Int(testPort) ?? 5433
    } else {
      databasePort = 5433
    }
  } else {
    databaseName = "vapor"
    databasePort = 5432
  }

  let databaseConfig = PostgreSQLDatabaseConfig(
    hostname: hostname,
    port: databasePort,
    username: "vapor",
    database: databaseName,
    password: "password")
  let database = PostgreSQLDatabase(config: databaseConfig)
  databases.add(database: database, as: .psql)
  services.register(databases)

  /// Configure migrations
  var migrations = MigrationConfig()
  migrations.add(model: User.self, database: .psql)
  migrations.add(model: Acronym.self, database: .psql)
  migrations.add(model: Category.self, database: .psql)
  migrations.add(model: AcronymCategoryPivot.self, database: .psql)
  migrations.add(model: Token.self, database: .psql)
  migrations.add(migration: AdminUser.self, database: .psql)
  services.register(migrations)

  var commandConfig = CommandConfig.default()
  commandConfig.useFluentCommands()
  services.register(commandConfig)

  config.prefer(LeafRenderer.self, for: ViewRenderer.self)
  config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
}
