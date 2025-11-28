# ETL Walkthrough: MongoDB to PostgreSQL Migration

This document provides a generic walkthrough of the ETL (Extract, Transform, Load) process for migrating data from MongoDB to PostgreSQL.

## Overview

The ETL process consists of three main phases:

1. **Extract**: Retrieve data from the source database (MongoDB)
2. **Transform**: Convert the data structure to match the target schema (PostgreSQL)
3. **Load**: Insert the transformed data into the target database

## Process Flow

```
┌──────────────┐    Extract     ┌──────────────┐    Transform    ┌──────────────┐    Load    ┌──────────────┐
│   MongoDB    │ ──────────────▶│   tmp/       │ ──────────────▶ │   tmp/       │ ─────────▶ │  PostgreSQL  │
│              │                │  extracted_  │                 │ transformed_ │            │              │
│ Collection A │                │  data.json   │                 │  data.json   │            │    Table     │
│ Collection B │                └──────────────┘                 └──────────────┘            └──────────────┘
└──────────────┘
```

## Prerequisites

Install required Python dependencies:

```bash
pip install pymongo psycopg
```

## Phase 1: Extract

### Purpose
Extract data from MongoDB collections and save to a local JSON file.

### Setup
Before extracting, you need to establish a connection to the MongoDB instance:

```bash
# Port-forward to MongoDB instance (in separate terminal)
mongo-proxy <target-environment>
```

### Script Example

```python
import json
from pymongo import MongoClient
import argparse

# Parse command line arguments
parser = argparse.ArgumentParser()
parser.add_argument('-o', '--outputdirectory', 
                    help="the path to the directory of the output files",
                    required=True)
args = parser.parse_args()

# Connect to MongoDB
connection = MongoClient(
    f"""mongodb://{input("Username: ")}:{input("Password: ")}@localhost:27017?authSource=admin&replicaSet={input("Replicaset: ")}&directConnection=true""")

# Select database
db = connection["sourceDatabaseName"]

# Extract from multiple collections if needed
collection_a = list(db.collectionA.find())
collection_b = list(db.collectionB.find())

# Combine data from multiple sources
combined_data = collection_a + collection_b

# Write to JSON file
with open(args.outputdirectory + 'extracted_data.json', 'w', encoding="utf-8") as outfile:
    json.dump(combined_data, outfile, ensure_ascii=False, indent=4)
```

### Running Extract

```bash
make extract
# Enter credentials when prompted:
# - MongoDB username
# - MongoDB password
# - Replicaset name
```

### Output
Creates: `tmp/extracted_data.json`

---

## Phase 2: Transform

### Purpose
Transform MongoDB document structure to match PostgreSQL table schema.

### Transformation Logic

Common transformations include:
- **Field renaming**: MongoDB `_id` → PostgreSQL `id`
- **Type conversion**: MongoDB class types → PostgreSQL enums
- **Structure flattening**: Extract specific fields to columns
- **Data preservation**: Store remaining fields as JSONB

### Script Example

```python
import json
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-o', '--outputdirectory', 
                    help="the path to the directory of the output files", 
                    required=True)
args = parser.parse_args()


def openfile(file_name):
    with open(file_name) as json_file:
        return json.load(json_file)


def transform_documents(extracted_data):
    """
    Transform MongoDB documents to PostgreSQL format.
    
    Example mapping:
    - "_id" → "id"
    - "someField" → "some_field" (snake_case)
    - "typeClass" → "record_type" (enum value)
    - All other fields → "data" (JSONB column)
    """
    result = []
    
    for document in extracted_data:
        # Map document class to enum value
        document_class = document.get("_class", "")
        if document_class == "com.example.model.TypeA":
            record_type = "TYPE_A"
        elif document_class == "com.example.model.TypeB":
            record_type = "TYPE_B"
        else:
            raise ValueError(f"Unknown document class '{document_class}' for document with _id: {document.get('_id')}")
        
        # Extract specific fields to columns
        transformed_document = {
            "id": document.get("_id"),
            "category_id": document.get("categoryId"),
            "is_active": document.get("isActive", False),
            "record_type": record_type,
            "data": {}
        }
        
        # Remaining fields stored as JSONB
        excluded_fields = {"_id", "categoryId", "isActive", "_class"}
        for key, value in document.items():
            if key not in excluded_fields:
                transformed_document["data"][key] = value
        
        result.append(transformed_document)
    
    # Write transformed data
    with open(args.outputdirectory + 'transformed_data.json', 'w', encoding="utf-8") as outfile:
        json.dump(result, outfile, ensure_ascii=False, indent=4)


# Execute transformation
transform_documents(openfile(args.outputdirectory + "extracted_data.json"))
```

### Running Transform

```bash
make transform
# No user input required - reads from tmp/extracted_data.json
```

### Output
Creates: `tmp/transformed_data.json`

---

## Phase 3: Load

### Purpose
Insert transformed data into PostgreSQL database using UPSERT logic.

### Setup
Before loading, establish a connection to PostgreSQL:

```bash
# Install Cloud SQL proxy if needed
gcloud components install cloud-sql-proxy

# Find instance connection name
gcloud sql instances describe <INSTANCE_NAME> --format='value(connectionName)'

# Start proxy (in separate terminal)
cloud-sql-proxy <INSTANCE_CONNECTION_NAME>
```

### Script Example

```python
import json
import psycopg
from psycopg import sql
from psycopg.types.json import Jsonb
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-o', '--outputdirectory', 
                    help="the path to the directory of the output files", 
                    required=True)
args = parser.parse_args()

# Get PostgreSQL credentials
username = input("Username: ")
password = input("Password: ")
database = input("Database: ")

# Connection via cloudsql-proxy on localhost:5432
connection_string = f"postgresql://{username}:{password}@localhost:5432/{database}"


def openfile(file_name):
    with open(file_name) as json_file:
        return json.load(json_file)


def load_database(transformed_data):
    if len(transformed_data) == 0:
        print("No records to load.")
        return
    
    print(f"---\nStarting to load {len(transformed_data)} records...")
    
    with psycopg.connect(connection_string) as conn:
        with conn.cursor() as cur:
            inserted_count = 0
            
            for record in transformed_data:
                try:
                    # UPSERT: Insert or update on conflict
                    cur.execute(
                        """
                        INSERT INTO target_table (id, category_id, is_active, record_type, data)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT (id) DO UPDATE SET
                            category_id = EXCLUDED.category_id,
                            is_active = EXCLUDED.is_active,
                            record_type = EXCLUDED.record_type,
                            data = EXCLUDED.data
                        """,
                        (
                            record["id"],
                            record["category_id"],
                            record["is_active"],
                            record["record_type"],
                            Jsonb(record["data"])
                        )
                    )
                    inserted_count += 1
                except Exception as e:
                    print(f"Error inserting record {record.get('id')}: {e}")
                    raise
            
            conn.commit()
            print(f"Successfully loaded {inserted_count}/{len(transformed_data)} records.")


# Execute load
load_database(openfile(args.outputdirectory + "transformed_data.json"))
```

### Running Load

```bash
make load
# Enter credentials when prompted:
# - PostgreSQL username
# - PostgreSQL password
# - Database name
```

### Output
Data inserted into PostgreSQL table `target_table`

---

## Complete Step-by-Step Process

### 1. Preparation
```bash
# Get source database credentials
kubectl get secrets <secret-name> -n <namespace>

# Start MongoDB proxy (Terminal 1)
mongo-proxy <environment>
```

### 2. Extract
```bash
# In your working directory (Terminal 2)
make extract
# Provide: username, password, replicaset
```

### 3. Stop MongoDB Proxy
```bash
# In Terminal 1: Ctrl+C to stop proxy
```

### 4. Transform
```bash
# In Terminal 2
make transform
```

### 5. Start PostgreSQL Proxy
```bash
# In Terminal 1
cloud-sql-proxy <INSTANCE_CONNECTION_NAME>
```

### 6. Load
```bash
# In Terminal 2
make load
# Provide: username, password, database
```

### 7. Cleanup
```bash
# Stop PostgreSQL proxy (Terminal 1): Ctrl+C

# Optionally clean temporary files
make clean
```

---

## Running All Steps Together

If all proxies and credentials are managed separately:

```bash
make all
# Runs extract → transform → load sequentially
```

---

## Makefile Structure

The ETL process is orchestrated using a Makefile:

```makefile
.PHONY: all extract transform load clean

all: extract transform load

extract:
	@echo "Extracting...."
	@python3 ./extract.py -o ./tmp/

transform:
	@echo "Transforming...."
	@python3 ./transform.py -o ./tmp/

load:
	@echo "Loading...."
	@python3 ./load.py -o ./tmp/

clean:
	@echo "Cleaning tmp/"
	@for item in ./tmp/* ./tmp/.*; do \
	  name=$$(basename $$item); \
	  if [ "$$name" != "." ] && [ "$$name" != ".." ] && [ "$$name" != ".keep" ]; then \
	    rm -rf "$$item"; \
	  fi; \
	done
```

---

## Data Mapping Summary

| MongoDB | PostgreSQL | Notes |
|---------|------------|-------|
| `_id` | `id` | Primary key |
| `categoryId` | `category_id` | Foreign key reference |
| `isActive` | `is_active` | Boolean field |
| `_class` | `record_type` | Enum: `TYPE_A`, `TYPE_B` |
| Other fields | `data` | JSONB column |

---

## Key Considerations

### UPSERT Logic
The load script uses `ON CONFLICT ... DO UPDATE` to handle existing records. This allows the ETL to be re-run safely without creating duplicates.

### JSONB Storage
Fields that don't map directly to columns are preserved in a `data` JSONB column, allowing flexible schema evolution without data loss.

### Error Handling
Each phase validates its input and provides clear error messages. The load phase will stop on errors to prevent partial data corruption.

### Temporary Files
All intermediate data is stored in `tmp/` directory:
- `extracted_data.json` - Raw MongoDB documents
- `transformed_data.json` - PostgreSQL-ready records

### Security
Credentials are requested at runtime rather than hardcoded. Use environment-specific credentials and never commit sensitive data to version control.
