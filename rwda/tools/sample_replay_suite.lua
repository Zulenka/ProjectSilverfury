return {
  cases = {
    {
      name = "sample_replay_dsl",
      log = "rwda/tools/sample_replay.log",
      target = "Bainz",
      assertions = {
        expected_last_action = "dsl",
        min_actions = 1,
      },
    },
  },
}
