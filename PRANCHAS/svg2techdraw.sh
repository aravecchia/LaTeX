#!/bin/bash
set -e

# 🧾 Verifica argumento
if [ -z "$1" ] || [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Uso: ./ajustarpagina.sh arquivo.pdf"
  echo "Converte todas as páginas de um PDF em SVGs A3 compatíveis com FreeCAD TechDraw."
  echo "Exemplo: ./ajustarpagina.sh A3-MEC.pdf"
  exit 0
fi

PDF="$1"
BASE="$(basename "$PDF" .pdf)"
WIDTH_MM=420
HEIGHT_MM=297
PT_TO_MM=0.352777778

# 🔍 Verificações de dependência
for cmd in pdf2svg pdfinfo bc sed; do
  command -v $cmd >/dev/null || { echo "❌ Comando '$cmd' não encontrado."; exit 1; }
done

# 📁 Verifica PDF
if [ ! -f "$PDF" ]; then
  echo "❌ Arquivo $PDF não encontrado!"
  exit 1
fi

# 📊 Calcula viewBox
VIEWBOX_W=$(printf "%.2f" "$(echo "$WIDTH_MM / $PT_TO_MM" | bc -l)")
VIEWBOX_H=$(printf "%.2f" "$(echo "$HEIGHT_MM / $PT_TO_MM" | bc -l)")

# 🔢 Número de páginas
NUM_PAGES=$(pdfinfo "$PDF" | awk '/^Pages:/ {print $2}')
echo "📄 PDF contém $NUM_PAGES páginas. Iniciando conversão..."

# 🚧 Loop por páginas
for i in $(seq 1 "$NUM_PAGES"); do
  PADDED=$(printf "%02d" "$i")
  SVG="${BASE}-${PADDED}.svg"
  TMP_SVG=$(mktemp /tmp/svgtempXXXXXX.svg)

  echo "🔄 Página $i → $SVG"
  pdf2svg "$PDF" "$TMP_SVG" "$i" || { echo "❌ Erro na página $i"; continue; }

  # ✒️ Gera SVG final com header A3 compatível com FreeCAD
  {
    echo '<?xml version="1.0" standalone="no"?>'
    echo "<svg width=\"${WIDTH_MM}mm\" height=\"${HEIGHT_MM}mm\""
    echo "     viewBox=\"0 0 ${VIEWBOX_W} ${VIEWBOX_H}\" version=\"1.1\""
    echo "     xmlns=\"http://www.w3.org/2000/svg\""
    echo "     id=\"A3_Landscape\">"
    echo "  <desc>SVG gerado da página $i de $PDF para FreeCAD TechDraw</desc>"
    sed '1,/<svg[^>]*>/d;/<\/svg>/,$d' "$TMP_SVG"
    echo "  <g id=\"DrawingContent\"/>"
    echo "</svg>"
  } > "$SVG"

  rm -f "$TMP_SVG"
  echo "✅ Gerado: $SVG"
done

echo "🏁 Conversão concluída com sucesso!"
