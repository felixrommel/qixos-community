# Language servers and editor integrations for the dev-nube blueprint, kept apart so a
# dev nube can go without them: a language server often runs code from the project it
# opens (build scripts, proc macros, template haskell, lakefiles).
#
# Requires the dev-nube blueprint:
#
#   modules = [
#     (opQixCommunity.nixosModules.modules.blueprints.dev-nube { inherit home-manager nixvim opQixCommunity; })
#     opQixCommunity.nixosModules.modules.blueprints.dev-lsp
#   ];
{ config, lib, pkgs, ... }:
let
  mkRaw = expr: { __raw = expr; };
in
{
  home-manager.users.user.programs.nixvim = {
    plugins = {
      # ---- LSP ---------------------------------------------------
      # nixvim's lsp module auto-installs the server binary from nixpkgs
      # and wires up lspconfig. Each server supports extraOptions for
      # raw lspconfig overrides (e.g. rootDir).
      lsp = {
        enable = true;
        servers = {
          pyright.enable = true;

          ts_ls.enable = true;

          rust_analyzer = {
            enable = true;
            # nixvim can install rustc/cargo for you, but since you're
            # likely using a Rust toolchain from your shell/devshell,
            # disable auto-install to avoid conflicts:
            installRustc = false;
            installCargo = false;
          };

          svelte = {
            enable = true;
            rootMarkers = [ "svelte.config.js" "svelte.config.cjs" "package.json" ".git" ];

          };

          nixd.enable = true;
          bashls.enable = true;

          # Haskell. Its ghc comes from the blueprint, as rust_analyzer's cargo does.
          hls = {
            enable = true;
            installGhc = false;
          };

          ocamllsp.enable = true;

          idris2_lsp.enable = true;
          zls.enable = true;
        };
      };

      # ---- CMP ---------------------------------------------------
      cmp = {
        enable = true;
        settings = {
          preselect = mkRaw "require('cmp').PreselectMode.Item";
          completion.completeopt = "menu,menuone,noinsert";

          mapping = {
            "<CR>" = mkRaw "require('cmp').mapping.confirm({ select = true })";
            "<C-Space>" = mkRaw "require('cmp').mapping.complete()";
            "<Tab>" = mkRaw ''
              require('cmp').mapping(function(fallback)
                if require('cmp').visible() then
                  require('cmp').select_next_item()
                else
                  fallback()
                end
              end, { "i", "s" })
            '';
            "<S-Tab>" = mkRaw ''
              require('cmp').mapping(function(fallback)
                if require('cmp').visible() then
                  require('cmp').select_prev_item()
                else
                  fallback()
                end
              end, { "i", "s" })
            '';
          };

          sources = [
            { name = "nvim_lsp"; }
          ];
        };
      };

      # lean.nvim rather than a server above, because lspconfig only describes lean3ls
      # and Lean 3 is obsolete. It starts and owns the Lean 4 server, which runs lake,
      # which runs a project's lakefile.
      lean.enable = true;

      # cmp source for LSP
      cmp-nvim-lsp.enable = true;

    };

    keymaps = [
      # LSP (non-closure ones)
      { mode = "n"; key = "L";   action = mkRaw "vim.lsp.buf.hover";       options.desc = "LSP hover docs"; }
      { mode = "n"; key = ";n";  action = mkRaw "vim.lsp.buf.rename";      options.desc = "LSP rename"; }
      { mode = "n"; key = ";a";  action = mkRaw "vim.lsp.buf.code_action"; options.desc = "LSP code action"; }
      { mode = "n"; key = ";f";  action = mkRaw "vim.lsp.buf.format";      options.desc = "LSP format"; }
    ];

    autoCmd = [
      # CD to LSP root on attach
      {
        event = "LspAttach";
        callback = mkRaw ''
          function(args)
            local client = vim.lsp.get_client_by_id(args.data.client_id)
            local root_dir = client and client.config and client.config.root_dir
            if root_dir then
              vim.cmd("cd " .. vim.fn.fnameescape(root_dir))
              print("cwd set to LSP root: " .. root_dir)
            end
          end
        '';
      }
    ];

    # Closures the keymaps above cannot express. The jump stack serves only the lsp
    # jumps, so it lives here with them.
    extraConfigLua = ''
      -- ============================================================
      -- CURSOR HOLD DIAGNOSTICS
      -- Show hover diagnostic once per position, not on every tick.
      -- ============================================================
      local _last_diag_pos = nil
      vim.api.nvim_create_autocmd("CursorHold", {
        callback = function()
          local pos = vim.api.nvim_win_get_cursor(0)
          local key = vim.api.nvim_buf_get_name(0) .. ":" .. pos[1] .. ":" .. pos[2]
          if key ~= _last_diag_pos then
            vim.diagnostic.open_float(nil, { scope = "cursor", focusable = false })
            _last_diag_pos = key
          end
        end,
      })

      -- ============================================================
      -- JUMP STACK
      -- ============================================================
      local jumpstack = {}

      local function mark_jump()
        local pos = vim.api.nvim_win_get_cursor(0)
        local buf = vim.api.nvim_get_current_buf()
        table.insert(jumpstack, { buf = buf, pos = pos })
      end

      local function jump_back()
        local last = table.remove(jumpstack)
        if last then
          vim.api.nvim_set_current_buf(last.buf)
          vim.api.nvim_win_set_cursor(0, last.pos)
        else
          vim.notify("Jump stack empty", vim.log.levels.WARN)
        end
      end

      -- LSP keymaps that need closures
      vim.keymap.set("n", "<leader>j", function()
        mark_jump()
        vim.lsp.buf.definition()
      end, { desc = "LSP: Go to definition with stack" })

      vim.keymap.set("n", "<leader>b", jump_back, { desc = "Jump back" })

      vim.keymap.set("n", ";r", function()
        mark_jump()
        require('fzf-lua').lsp_references()
      end, { desc = "LSP references" })
    '';
  };

  # Here as well as behind nixvim so a server can be run by hand, which is how a project
  # it will not load is diagnosed. Every enabled server, taken from nixvim's own option so
  # it is the package nvim runs. Named one by one: iterating nixvim's servers touches the
  # options it has removed, which throw. Lean's comes with the blueprint's lean4.
  environment.systemPackages =
    let servers = config.home-manager.users.user.programs.nixvim.plugins.lsp.servers;
    in map (name: servers.${name}.package) [
      "pyright" "ts_ls" "rust_analyzer" "svelte" "nixd" "bashls"
      "hls" "ocamllsp" "idris2_lsp" "zls"
    ];
}
