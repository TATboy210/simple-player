import 'package:logger/logger.dart';

/// Kernel-wide logger. Uses PrettyPrinter with minimal method count
/// for compact desktop output. Only logs in debug mode (default filter).
final Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 4,
    lineLength: 100,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
