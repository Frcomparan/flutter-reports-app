import sqlite3
from datetime import datetime
from flask import Flask, request, send_file, jsonify
import os

app = Flask(__name__)

from flask_cors import CORS
cors = CORS(app, resources={r"/*": {"origins": "*"}})

UPLOAD_FOLDER = './reports-page/uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Configuración de la base de datos local
class DBStorage:
    def __init__(self, db_name="data.db"):
        self.db_name = db_name
        self.db = None
        self.cursor = None

    def connect(self):
        self.db = sqlite3.connect(self.db_name)
        self.cursor = self.db.cursor()

    def disconnect(self):
        self.db.close()

    def create_table(self):
        self.cursor.execute(
            "CREATE TABLE IF NOT EXISTS reports (id INTEGER PRIMARY KEY AUTOINCREMENT, imagePath TEXT, location TEXT, description TEXT, fecha TIMESTAMP)"
        )

    def insert_report(self, imagePath, location, description):
        fecha = datetime.now()
        self.cursor.execute(
            "INSERT INTO reports (imagePath, location, description, fecha) VALUES (?, ?, ?, ?)",
            (imagePath, location, description, fecha)
        )
        self.db.commit()

    def get_reports(self):
        self.cursor.execute("SELECT * FROM reports")
        reports = []

        for row in self.cursor.fetchall():
            report = {
                "id": row[0],
                "imagePath": row[1],
                "location": row[2],
                "description": row[3],
                "fecha": row[4],
            }
            reports.append(report)

        return reports

@app.route('/upload', methods=['POST'])
def upload_file():
    try:
        # Verifica si la solicitud contiene el archivo y otros datos del reporte
        if 'imageFile' not in request.files or \
                'location' not in request.form or \
                'description' not in request.form:
            return jsonify({'error': 'Faltan datos en la solicitud'}), 400

        file = request.files['imageFile']
        location = request.form['location']
        description = request.form['description']

        # Verifica si se recibió un archivo
        if file:
            filename = file.filename

            filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(filepath)

            db = DBStorage()
            db.connect()
            db.insert_report(filename, location, description)

            reports = db.get_reports()

            for report in reports:
                print("\n")
                print(report)

            db.disconnect()

            # Devuelve una respuesta exitosa
            return jsonify({'message': 'Archivo y datos del reporte recibidos correctamente'}), 200
        else:
            return jsonify({'error': 'No se ha recibido ninguna imagen'}), 400
    except Exception as e:
        print(e)
        return jsonify({'error': str(e)}), 500

@app.route('/reports')
def get_reports():
    try:
        db = DBStorage()
        db.connect()
        
        reports = db.get_reports()

        db.disconnect()

        return jsonify(reports), 200

    except Exception as e:
        print(e)
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    db = DBStorage("data.db")
    db.connect()
    db.create_table()
    db.disconnect()
    app.run(host='0.0.0.0', port=5000)

