module Kilo
  module Constants
    NAME    = "kilo"
    VERSION = "version 0.0.1"

    MARKERS = {
      ret:    "⏎",
      caps:   "⇕",
      shift:  "⇑",
      bksp:   "⇤",
      space:  "⊔",
      space2: "⋃",
      unused: "◻",
      tab:    "➨",
      others: "□➨⇐⇑⇕⇤⇥←",
    }

    PRIVATE_DIR = ".#{NAME}"
    EXPORTS_DIR = "out"
    SCRIPTS_DIR = "scripts"
    SQL_DIR     = "sql"
    FREQ_DIR    = ".#{NAME}"
    CONFIG_DIR  = "config"
    DB_DIR      = "db"

    WEIGHTS_IMAGE_FILE  = "weights"
    FREQ_INDEX_FILE     = "freq.index.bin"
    CORPUS_DATA_FILE    = "corpus.msgpack"
    CANDIDATES_FILE     = "candidates.msgpack"
    PROJECT_CONFIG_FILE = File.join(CONFIG_DIR, "config.yaml")

    ProjectDirs = [
      PRIVATE_DIR,
      CONFIG_DIR,
      "data",
      DB_DIR,
      "maps",
      SCRIPTS_DIR,
      SQL_DIR,
    ]

    # This is used so that instead of using Float and wasting a lot of
    # storage in db and also memory when dealing with millions of
    # records we can instead use an Int16 and scale it to that scale.
    # now to print it as a decimal we just print it as 100.00 by
    # inserting the dot int the to_s representation. Otherwise, we will
    # deal with int math and make operations also faster. Most data
    # we calculate is a percentage so this representation should work
    # fine. The scaling happens at the frequency data level. So that
    # when calculating a score it is mostly addition without a lot of
    # division operations.
    DATA_SCALE   = 10_000.to_i64
    EFFORT_SCALE = 4

    # 4M buffer
    READNIG_BUFFER_SIZE  = 1024 * 1024 * 4
    INITIAL_CHARSET_SIZE = 32
  end
end
