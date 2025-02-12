# OCR-Patient-Forms
import cv2
import pytesseract
import json
import psycopg2
import os
from pdf2image import convert_from_path
from datetime import datetime

# Configure Tesseract OCR path if necessary
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# Database configuration
db_config = {
    "dbname": "ocr_database",
    "user": "postgres",
    "password": "password",
    "host": "localhost",
    "port": "5432"
}

def create_database_tables():
    """Create necessary tables in the database."""
    try:
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS patients (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255),
                dob DATE
            );

            CREATE TABLE IF NOT EXISTS forms_data (
                id SERIAL PRIMARY KEY,
                patient_id INT REFERENCES patients(id),
                form_json JSONB,
                created_at TIMESTAMP DEFAULT NOW()
            );
        """)
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print("Database error:", e)

def preprocess_image(image_path):
    """Preprocess the image to improve OCR accuracy."""
    image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    image = cv2.threshold(image, 150, 255, cv2.THRESH_BINARY)[1]
    return image

def extract_text_from_image(image_path):
    """Extract text from an image using Tesseract OCR."""
    processed_image = preprocess_image(image_path)
    text = pytesseract.image_to_string(processed_image)
    return text

def extract_data_from_text(text):
    """Extract structured data from OCR text."""
    data = {}
    
    lines = text.split("\n")
    for line in lines:
        if "Patient Name" in line:
            data["patient_name"] = line.split(":")[1].strip()
        elif "DOB" in line:
            data["dob"] = line.split(":")[1].strip()
        elif "INJECTION" in line:
            data["injection"] = "Yes" if "YES" in line else "No"
        elif "Exercise Therapy" in line:
            data["exercise_therapy"] = "Yes" if "YES" in line else "No"
        elif "Pain:" in line:
            data["pain"] = int(line.split(":")[1].strip())
    
    return json.dumps(data)

def save_to_database(json_data):
    """Save extracted data into the database."""
    try:
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO forms_data (form_json)
            VALUES (%s)
        """, (json_data,))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print("Database error:", e)

def main():
    """Main function to run the OCR pipeline."""
    create_database_tables()
    pdf_path = "patient_forms.pdf"
    images = convert_from_path(pdf_path)
    for i, image in enumerate(images):
        image_path = f"temp_{i}.jpg"
        image.save(image_path, "JPEG")
        extracted_text = extract_text_from_image(image_path)
        json_data = extract_data_from_text(extracted_text)
        save_to_database(json_data)
        os.remove(image_path)
    print("OCR Processing Completed.")

if __name__ == "__main__":
    main()

