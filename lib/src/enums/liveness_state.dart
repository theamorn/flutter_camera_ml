enum LivenessState {
  notStart(-1),
  normal(0),
  faceNotFound(1),
  faceNotForward(2),
  tooLittleBright(3),
  tooBright(4),
  tooClose(5),
  tooFar(6),
  noMouth(7),
  noEyeLeft(8),
  noEyeRight(9),
  noEye(10),
  multipleFace(11),
  backgroundBright(12),
  turnFaceLeft(13),
  turnFaceRight(14),
  blink(15),
  smile(16),
  faceNod(17),
  mouthNotClose(18),
  changeEnvironment(19),
  notCenter(20),
  noseNotFound(21),
  unknown(42);

  static LivenessState mapIntToLivenessState(int value) {
    for (var state in LivenessState.values) {
      if (value == state.value) return state;
    }
    return LivenessState.unknown;
  }

  final int value;
  const LivenessState(this.value);
}
