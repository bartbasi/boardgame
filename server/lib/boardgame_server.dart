/// Backend API for the Board Game Collector app.
library;

export 'src/app.dart' show buildApp;
export 'src/config/config.dart' show Config, ConfigException;
export 'src/http/middleware.dart'
    show loggableMethod, otherMethod, unmatchedRoute;
export 'src/http/serve.dart' show bindAndServe, serverIdleTimeout;
export 'src/logging/error_description.dart'
    show describeError, maxErrorDescriptionLength;
export 'src/http/responses.dart'
    show errorResponse, internalErrorResponse, jsonResponse, notFoundResponse;
export 'src/http/routes.dart' show RouteSlot, Routes;
export 'src/logging/logger.dart' show LogLevel, Logger;
export 'src/server_runner.dart'
    show
        configErrorExitCode,
        defaultShutdownGrace,
        listenErrorExitCode,
        runServer;
export 'src/version.dart' show appVersion;
