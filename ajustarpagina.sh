#!/bin/bash

# Nome fixo do arquivo PDF de entrada
PDF="A3-MEC.pdf"
SVG="A3-MEC.svg"
TMP_SVG="temp-conversao.svg"

# Constantes para folha A3
WIDTH_MM=420
HEIGHT_MM=297
PT_TO_MM=0.352777778

# Calcula o viewBox correto (em unidades de PDF, ou seja, pt)
VIEWBOX_W=$(echo "$WIDTH_MM / $PT_TO_MM" | bc -l)
VIEWBOX_H=$(echo "$HEIGHT_MM / $PT_TO_MM" | bc -l)
VIEWBOX_W=$(printf "%.2f" "$VIEWBOX_W")
VIEWBOX_H=$(printf "%.2f" "$VIEWBOX_H")

# Verifica se o arquivo PDF existe
if [ ! -f "$PDF" ]; then
  echo "❌ Arquivo $PDF não encontrado!"
  exit 1
fi

# Verifica se pdf2svg está instalado
if ! command -v pdf2svg >/dev/null 2>&1; then
  echo "❌ pdf2svg não está instalado. Instale com: sudo apt install pdf2svg"
  exit 1
fi

# Converte PDF para SVG (primeira página)
echo "📄 Convertendo $PDF para SVG intermediário..."
pdf2svg "$PDF" "$TMP_SVG" 1 || { echo "Erro ao converter PDF"; exit 1; }

# Gera SVG com estrutura compatível com FreeCAD TechDraw
echo "🛠️  Gerando SVG final com dimensões e viewBox corretos..."
cat > "$SVG" <<EOF
<?xml version="1.0" standalone="no"?>
<svg
    width="${WIDTH_MM}mm"
    height="${HEIGHT_MM}mm"
    viewBox="0 0 ${VIEWBOX_W} ${VIEWBOX_H}"
    version="1.1"
    xmlns="http://www.w3.org/2000/svg"
    id="A3_Landscape">
    <desc>SVG gerado a partir de LaTeX para FreeCAD TechDraw</desc>

EOF

# Insere conteúdo interno do SVG original (sem a tag <svg>)
sed '1,/<svg[^>]*>/d;/<\/svg>/,$d' "$TMP_SVG" >> "$SVG"

# Finaliza o SVG com grupo de desenho
cat >> "$SVG" <<EOF
    <g id="DrawingContent"/>
</svg>
EOF

# Remove temporário
rm "$TMP_SVG"

echo "✅ SVG final salvo como: $SVG"
