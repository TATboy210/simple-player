/// Contract test runner aggregator (BASE-04, D13/D14).
///
/// This library has NO `test()` calls of its own — it only re-exports the
/// parameterized `run<Iface>ContractTests(MediaEngine Function() createEngine)`
/// functions from each of the 7 ISP interface contract files. Mount points
/// (e.g. `test/engine/fvp_engine_contract_test.dart`) import this single
/// library and call each exported function with a concrete engine factory.
///
/// This indirection is what makes the contract suite reusable against a
/// future `NewFvpEngine` (Phase 21) by swapping only the factory passed to
/// each `run*ContractTests` call — the test bodies themselves never
/// reference a concrete engine type (D13).
library;

export 'engine_state_view_contract.dart';
export 'playback_control_contract.dart';
export 'track_control_contract.dart';
export 'subtitle_config_contract.dart';
export 'video_effect_control_contract.dart';
export 'renderer_control_contract.dart';
export 'volume_control_contract.dart';
