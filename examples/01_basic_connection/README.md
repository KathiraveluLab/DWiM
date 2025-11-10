# Example 1: Basic Orthanc Connection

## 🎯 Purpose

This example demonstrates the fundamental first step of the DWiM project:
connecting to a PACS server (Orthanc) via its REST API and retrieving study
metadata.

This script (`connect_and_fetch.m`) serves as the "Hello, World!" for
Phase 1 of the project, proving the MATLAB environment can successfully
communicate with the image server.

## ⚙️ Setup Instructions

To run this example, you must have a running Orthanc server populated with
test data.

1.  **Install Docker:**
    * Download and install Docker Desktop.

2.  **Run Orthanc Container:**
    * Open a terminal and run the following command. This image includes
      the necessary plugins:
    ```bash
    docker run -p 4242:4242 -p 8042:8042 --rm jodogne/orthanc-plugins
    ```

3.  **Get Test Data:**
    * Download sample DICOM studies from a source like
        [The Cancer Imaging Archive (TCIA)](https://nbia.cancerimagingarchive.net/nbia-search/).
    * (Note: The `LIDC-IDRI` or `ICDC-Glioma` collections are good test sets).

4.  **Upload Data to Orthanc:**
    * Open the Orthanc web interface at `http://localhost:8042`.
    * Log in (default: `orthanc` / `orthanc`).
    * Use the "Upload" button to add your sample `.dcm` files.

## 🏃 How to Run

1.  Open MATLAB.
2.  Navigate to this directory (`examples/01_basic_connection/`).
3.  Run the script from the MATLAB Command Window:

    ```matlab
    connect_and_fetch
    ```

## ✅ Expected Output

If successful, you will see output in the command window similar to this
(the Patient Name will match the data you uploaded):

--- DWiM Connection Test Start ---
Attempting to connect to http://localhost:8042 ...
Success! Connected to Orthanc. Found 1 studies.

Fetching metadata for first study (ID: e8a3c681...)... 
--- Successfully Retrieved Metadata ---
Patient Name: GLIOMA01-i_03A6
--- DWiM Connection Test End ---