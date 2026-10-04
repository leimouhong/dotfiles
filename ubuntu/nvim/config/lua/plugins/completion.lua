return {
  {
    "saghen/blink.cmp",
    opts = {
      completion = {
        list = {
          -- Show suggestions without selecting or inserting one automatically.
          selection = { preselect = false, auto_insert = false },
        },
      },
      keymap = {
        ["<CR>"] = { "fallback" },
        ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
      },
    },
  },
}
