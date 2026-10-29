-- PostgreSQL schema (reference). Generated from app/models.py.
-- The app creates missing tables/columns itself at startup (AUTO_CREATE_TABLES=true);
-- use this file if you prefer to manage the schema by hand.

CREATE TABLE users (
	user_id SERIAL NOT NULL, 
	full_name VARCHAR(150) NOT NULL, 
	username VARCHAR(50) NOT NULL,
	email VARCHAR(254), 
	password VARCHAR(255) NOT NULL, 
	role VARCHAR(20) NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE, 
	PRIMARY KEY (user_id)
);

CREATE UNIQUE INDEX ix_users_username ON users (username);
CREATE UNIQUE INDEX ix_users_email ON users (email) WHERE email IS NOT NULL;

CREATE TABLE farms (
	farm_id SERIAL NOT NULL, 
	farmer_id INTEGER NOT NULL, 
	farm_code VARCHAR(50) NOT NULL, 
	farm_name VARCHAR(150) NOT NULL, 
	location VARCHAR(255) NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	area_hectares FLOAT, 
	city VARCHAR(100), 
	created_at TIMESTAMP WITHOUT TIME ZONE, 
	PRIMARY KEY (farm_id), 
	FOREIGN KEY(farmer_id) REFERENCES users (user_id), 
	UNIQUE (farm_code)
);

CREATE INDEX ix_farms_farmer_id ON farms (farmer_id);

CREATE TABLE climate_readings (
	reading_id SERIAL NOT NULL, 
	farm_id INTEGER NOT NULL, 
	temperature FLOAT NOT NULL, 
	rainfall FLOAT NOT NULL, 
	humidity FLOAT NOT NULL, 
	weather_condition VARCHAR(100), 
	rain_probability FLOAT NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE, 
	PRIMARY KEY (reading_id), 
	FOREIGN KEY(farm_id) REFERENCES farms (farm_id)
);

CREATE INDEX ix_climate_readings_farm_id ON climate_readings (farm_id);

CREATE TABLE productivity_records (
	record_id SERIAL NOT NULL, 
	farm_id INTEGER NOT NULL, 
	crop_name VARCHAR(100) NOT NULL, 
	harvested_sacks INTEGER NOT NULL, 
	sold_sacks INTEGER NOT NULL, 
	price_per_sack NUMERIC(12, 2) NOT NULL, 
	production_cost NUMERIC(14, 2) NOT NULL, 
	harvest_date DATE NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE, 
	PRIMARY KEY (record_id), 
	FOREIGN KEY(farm_id) REFERENCES farms (farm_id)
);

CREATE INDEX ix_productivity_farm_date ON productivity_records (farm_id, harvest_date);

CREATE TABLE planting_assessments (
	assessment_id SERIAL NOT NULL, 
	farm_id INTEGER NOT NULL, 
	reading_id INTEGER NOT NULL, 
	planting_status VARCHAR(20) NOT NULL, 
	reason TEXT NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE, 
	PRIMARY KEY (assessment_id), 
	FOREIGN KEY(farm_id) REFERENCES farms (farm_id), 
	FOREIGN KEY(reading_id) REFERENCES climate_readings (reading_id)
);

CREATE INDEX ix_planting_assessments_farm_id ON planting_assessments (farm_id);

CREATE TABLE password_reset_tokens (
    reset_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL
);
CREATE INDEX ix_password_reset_tokens_user_id ON password_reset_tokens (user_id);
CREATE UNIQUE INDEX ix_password_reset_tokens_token_hash ON password_reset_tokens (token_hash);
