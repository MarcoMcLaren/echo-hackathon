// Build-time switch between the real mesh transport and the demo one.
//
// Kept as its own file (rather than inline in main.dart) so flipping it back
// to the mock while developing without a paired second phone is a one-line
// change, and so main.dart's provider wiring stays a diff of one expression.
const bool useRealTransport = true;
