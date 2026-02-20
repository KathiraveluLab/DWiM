# DWiM Test Data Directory

This directory is intended for storing local sample DICOM files used during manual testing and development of the DWiM library. 

### Acquiring Clinical Test Data
To perform manual testing with realistic clinical data, we recommend downloading open-access DICOM samples from [The Cancer Imaging Archive (TCIA)](https://www.cancerimagingarchive.net/).

You can securely fetch sample data directly via the TCIA API. Navigate to this directory in your terminal and execute one of the following commands to download a public lung CT slice:

**Using `wget`:**
```bash
wget -O sample_image.dcm 'https://services.cancerimagingarchive.net/nbia-api/services/v1/getImage?SeriesInstanceUID=1.3.6.1.4.1.14519.5.2.1.7009.9004.322361405101076426435467004428'