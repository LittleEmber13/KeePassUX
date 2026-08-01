class KdfInfo {
  final String kdfType;
  final int memoryBytes;
  final int iterations;
  final int parallelism;

  KdfInfo({
    required this.kdfType,
    required this.memoryBytes,
    required this.iterations,
    required this.parallelism,
  });
}
