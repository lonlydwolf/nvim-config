-- ============================================================
-- LSP SETUP
-- ============================================================

-- nvim-lspconfig ships server definitions under lsp/*.lua.
-- We use vim.lsp.enable() (Neovim 0.11+) instead of manual setup calls.

-- ============================================================
-- CAPABILITIES (blink.cmp integration)
-- ============================================================

vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(),
})

-- ============================================================
-- ENABLE LSP SERVERS
-- ============================================================

local servers = {
	-- Lua
	"lua_ls",

	-- Python
	"basedpyright",
	"ruff",

	-- JavaScript / TypeScript
	"vtsls",

	-- C / C++
	"clangd",

	-- Rust
	"rust_analyzer",

	-- Go
	"gopls",

	-- Bash / Zsh
	"bashls",

	-- Ansible
	"ansiblels",

	-- Markdown
	"marksman",

	-- YAML
	"yamlls",

	-- JSON
	"jsonls",

	-- TOML
	"taplo",

	-- Dockerfile
	"dockerls",
}

vim.lsp.enable(servers)

-- ============================================================
-- SERVER-SPECIFIC CONFIGURATION
-- ============================================================

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
			},
			workspace = {
				checkThirdParty = false,
			},
		},
	},
})

-- ============================================================
-- DIAGNOSTICS CONFIGURATION
-- ============================================================

vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = { current_line = true },
	signs = true,
	underline = true,
	severity_sort = true,
})

-- ============================================================
-- LSP ATTACH BEHAVIOR (keymaps + features)
-- ============================================================

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),

	callback = function(ev)
		local opts = { buffer = ev.buf }
		local client = vim.lsp.get_client_by_id(ev.data.client_id)

		-- --------------------------------------------------------
		-- Navigation
		-- --------------------------------------------------------

		vim.keymap.set(
			"n",
			"gd",
			vim.lsp.buf.definition,
			vim.tbl_extend("force", opts, { desc = "[G]o to [D]efinition" })
		)

		vim.keymap.set(
			"n",
			"gD",
			vim.lsp.buf.declaration,
			vim.tbl_extend("force", opts, { desc = "[G]o to [D]eclaration" })
		)

		-- --------------------------------------------------------
		-- Diagnostics → Quickfix
		-- --------------------------------------------------------

		vim.keymap.set("n", "<leader>ld", function()
			local diags = vim.diagnostic.get(ev.buf)

			table.sort(diags, function(a, b)
				if a.lnum == b.lnum then
					return a.col < b.col
				end
				return a.lnum < b.lnum
			end)

			local severity_map = {
				[vim.diagnostic.severity.ERROR] = "E",
				[vim.diagnostic.severity.WARN] = "W",
				[vim.diagnostic.severity.INFO] = "I",
				[vim.diagnostic.severity.HINT] = "H",
			}

			local qf_items = {}

			for _, d in ipairs(diags) do
				table.insert(qf_items, {
					bufnr = d.bufnr,
					lnum = d.lnum + 1,
					col = d.col + 1,
					text = string.format("[%s] %s", d.source or "LSP", d.message),
					type = severity_map[d.severity] or "I",
				})
			end

			vim.fn.setqflist({}, " ", {
				title = "Diagnostics",
				items = qf_items,
			})

			vim.cmd("copen")
		end, vim.tbl_extend("force", opts, { desc = "[L]SP [D]iagnostics → quickfix" }))

		-- --------------------------------------------------------
		-- LSP Restart
		-- --------------------------------------------------------

		vim.keymap.set(
			"n",
			"<leader>lr",
			"<cmd>lsp restart<CR>",
			vim.tbl_extend("force", opts, { desc = "[L]SP [R]estart client" })
		)

		-- --------------------------------------------------------
		-- Inlay hints (buffer toggle)
		-- --------------------------------------------------------

		if client and client:supports_method("textDocument/inlayHint") then
			vim.keymap.set("n", "<leader>th", function()
				local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
				vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
			end, vim.tbl_extend("force", opts, { desc = "[T]oggle [H]ints inlay" }))
		end

		-- --------------------------------------------------------
		-- Document highlight (best practice: CursorHold only)
		-- --------------------------------------------------------

		if client and client:supports_method("textDocument/documentHighlight") then
			local group = vim.api.nvim_create_augroup("user-lsp-highlight-" .. ev.buf, { clear = true })

			vim.api.nvim_create_autocmd("CursorHold", {
				group = group,
				buffer = ev.buf,
				callback = vim.lsp.buf.document_highlight,
			})

			vim.api.nvim_create_autocmd("CursorMoved", {
				group = group,
				buffer = ev.buf,
				callback = vim.lsp.buf.clear_references,
			})

			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("user-lsp-detach-" .. ev.buf, { clear = true }),
				buffer = ev.buf,
				callback = function()
					vim.lsp.buf.clear_references()
				end,
			})
		end
	end,
})
