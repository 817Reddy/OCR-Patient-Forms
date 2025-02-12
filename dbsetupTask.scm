-- Create Patients Table
CREATE TABLE patients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255),
    dob DATE
);

-- Create Forms Data Table
CREATE TABLE forms_data (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES patients(id),
    form_json JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
