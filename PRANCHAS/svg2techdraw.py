#!/usr/bin/env python3
import sys
import os
import tempfile
import subprocess
from PyQt6.QtWidgets import (
    QApplication, QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QFileDialog, QComboBox,
    QLineEdit, QProgressBar, QMessageBox
)
from PyQt6.QtGui import QPixmap, QFont
from PyQt6.QtCore import Qt, QThread, pyqtSignal

PT_TO_MM = 0.352777778
PAGE_SIZES = {
    "A0": (841, 1189),
    "A1": (594, 841),
    "A2": (420, 594),
    "A3": (297, 420),
    "A4": (210, 297),
}

class ConverterThread(QThread):
    progress = pyqtSignal(int, int)
    done = pyqtSignal()

    def __init__(self, pdf_path, page_size):
        super().__init__()
        self.pdf_path = pdf_path
        self.page_size = page_size

    def run(self):
        width_mm, height_mm = PAGE_SIZES[self.page_size]
        viewbox_w = round(width_mm / PT_TO_MM, 2)
        viewbox_h = round(height_mm / PT_TO_MM, 2)
        base = os.path.splitext(os.path.basename(self.pdf_path))[0]

        try:
            out = subprocess.check_output(["pdfinfo", self.pdf_path], text=True)
            pages = int([l for l in out.splitlines() if l.startswith("Pages:")][0].split()[1])
        except Exception as e:
            print("Erro ao obter páginas:", e)
            return

        for i in range(1, pages + 1):
            padded = f"{i:02d}"
            output_svg = f"{base}-{padded}.svg"
            with tempfile.NamedTemporaryFile(suffix=".svg", delete=False) as tmp_svg:
                tmp_path = tmp_svg.name

            try:
                subprocess.run(["pdf2svg", self.pdf_path, tmp_path, str(i)], check=True)

                with open(output_svg, "w") as out_svg, open(tmp_path) as tmp:
                    out_svg.write(f'''<?xml version="1.0"?>
<svg width="{width_mm}mm" height="{height_mm}mm"
     viewBox="0 0 {viewbox_w} {viewbox_h}"
     xmlns="http://www.w3.org/2000/svg"
     version="1.1" id="{self.page_size}_Landscape">
  <desc>SVG gerado da página {i}</desc>
''')
                    content = tmp.read()
                    inner = content.split("<svg", 1)[1].split(">", 1)[1].rsplit("</svg>", 1)[0]
                    out_svg.write(inner)
                    out_svg.write("\n  <g id=\"DrawingContent\"/>\n</svg>")
                os.remove(tmp_path)
                self.progress.emit(i, pages)
            except Exception as e:
                print("Erro na conversão da página", i, e)

        self.done.emit()

class SvgApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Conversor PDF → SVG - Aravecchia 3D")
        self.setFixedSize(600, 260)
        self.init_ui()

    def init_ui(self):
        layout = QVBoxLayout()

        # Logo
        logo = QLabel()
        pixmap = QPixmap("Aravecchia3D.png").scaledToWidth(220, Qt.TransformationMode.SmoothTransformation)
        logo.setPixmap(pixmap)
        logo.setAlignment(Qt.AlignmentFlag.AlignRight)
        layout.addWidget(logo)

        # Input PDF
        row1 = QHBoxLayout()
        self.path_input = QLineEdit()
        browse = QPushButton("Selecionar PDF")
        browse.clicked.connect(self.select_pdf)
        row1.addWidget(self.path_input)
        row1.addWidget(browse)
        layout.addLayout(row1)

        # Folha
        row2 = QHBoxLayout()
        row2.addWidget(QLabel("Tamanho da folha:"))
        self.paper_box = QComboBox()
        self.paper_box.addItems(PAGE_SIZES.keys())
        self.paper_box.setCurrentText("A3")
        row2.addWidget(self.paper_box)
        layout.addLayout(row2)

        # Botão
        self.btn_convert = QPushButton("🚀 Converter para SVGs")
        self.btn_convert.clicked.connect(self.start_conversion)
        layout.addWidget(self.btn_convert)

        # Progresso
        self.progress = QProgressBar()
        layout.addWidget(self.progress)

        self.setLayout(layout)

    def select_pdf(self):
        file, _ = QFileDialog.getOpenFileName(self, "Selecionar PDF", "", "PDF (*.pdf)")
        if file:
            self.path_input.setText(file)

    def start_conversion(self):
        pdf_path = self.path_input.text()
        if not pdf_path or not os.path.isfile(pdf_path):
            QMessageBox.warning(self, "Erro", "Selecione um arquivo PDF válido.")
            return

        self.btn_convert.setEnabled(False)
        page_size = self.paper_box.currentText()
        self.thread = ConverterThread(pdf_path, page_size)
        self.thread.progress.connect(self.update_progress)
        self.thread.done.connect(self.conversion_done)
        self.progress.setValue(0)
        self.thread.start()

    def update_progress(self, current, total):
        self.progress.setMaximum(total)
        self.progress.setValue(current)

    def conversion_done(self):
        QMessageBox.information(self, "Concluído", "Conversão finalizada!")
        self.btn_convert.setEnabled(True)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    win = SvgApp()
    win.show()
    sys.exit(app.exec())
