{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [
    elixir
    qpdf
    poppler-utils
    curl
    git
  ];

  shellHook = ''
    echo "josjob_ragpdf shell"
    echo "  elixir: $(elixir --version | tail -1)"
    echo "  qpdf:   $(qpdf --version | head -1)"
    echo "  pdftotext: $(pdftotext -v 2>&1 | head -1)"
    echo ""
    echo "Run:"
    echo "  mix deps.get"
    echo "  mix test"
    echo "  mix run --no-halt"
  '';
}
