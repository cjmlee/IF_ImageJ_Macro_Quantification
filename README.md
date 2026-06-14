# IF ImageJ/FIJI Macro Quantification
For automating fluoresence image quantification using ImageJ/Fiji Macro

This repository contains Fiji/ImageJ macros for batch processing and quantification of immunofluorescence images.

The macro was optimised for images acquired at 20X Magnification on EVOS M7000.

The individual channels were acquired at 16-Bit, and files naming nonmenclature should look like the one below:
<img width="258" height="335" alt="image" src="https://github.com/user-attachments/assets/e1a57e8d-b521-4d05-9a8b-93ebc2c0af77" />

where D refers to 16-Bit individual channels, d0 - Blue, d1 - Green and d2 - Red.

The workflow is designed for three-channel immunofluorescence images:

Example:
| Channel | Marker      | Colour |
| ------- | ----------- | ------ |
| C1  (d2)    | aSMA        | Red    |
| C2  (d1)    | CNN1 / CCN1 | Green  |
| C3  (d0)    | DAPI        | Blue   |

The main quantitative output is marker intensity normalized to the DAPI-positive nuclei count:

```text
Example:
aSMA_intensity_per_DAPI = aSMA integrated density / DAPI nuclei count
CNN1_intensity_per_DAPI = CNN1 integrated density / DAPI nuclei count
```

This normalization is useful when comparing conditions with different cell densities
---

## Macro 1: Create composite files from single-channel TIFFs

File:

```text
Make_composit.ijm
```

This macro creates composite TIFF images from separate raw single-channel TIFF files.

Expected raw input format:

```text
AMOTL2_WT_Top Slide_D_p00_0_A03f00d0 - DAPI (Blue).tif
AMOTL2_WT_Top Slide_D_p00_0_A03f00d1 - CNN1 (Green).tif
AMOTL2_WT_Top Slide_D_p00_0_A03f00d2 - aSMA (Red).tif
```
```

Expected channel identifiers:

| Identifier | Marker       | Output channel |
| ---------- | ------------ | -------------- |
| d0         | DAPI         | C3 / Blue      |
| d1         | CNN1 or CCN1 | C2 / Green     |
| d2         | aSMA         | C1 / Red       |

Output files are renamed as:

```text
WT_AMOTL2_1.tif
WT_AMOTL2_2.tif
......
```
The macro also writes a mapping file:

```text
composite_name_mapping.csv
```

This allows users to trace each renamed composite file back to the original microscope-exported filenames.
## USAGE
Open Fiji > Plugins > Macros > Interactive Interpreter > File > Open > Make_composit.ijm

**Hit Run**

Proceed to select your folder where your 16-bit single channel raw images, and select the output folder of your composite images
<img width="1331" height="946" alt="image" src="https://github.com/user-attachments/assets/c82c1bf0-bbcf-4899-ad8e-cc493f8ee3e1" />

---

## Macro 2: Batch IF quantification

File:

```text
batch-quantification.ijm
```

This macro quantifies all composite TIFF files in a folder and exports one combined CSV file.

Change user settings especially Marker names for Ch1, Ch2 and Ch3, and select prefered auto thrshold methods.
Identify input and output directory
<img width="846" height="641" alt="image" src="https://github.com/user-attachments/assets/45eb0456-7644-4380-bf4e-4380db0399f3" />


Expected input composite format:

| Channel | Marker      |
| ------- | ----------- |
| C1      | aSMA        |
| C2      | CNN1 / CCN1 |
| C3      | DAPI        |

The macro performs the following steps:

1. Opens each composite TIFF image.
2. Splits channels into C1, C2, and C3.
3. Counts DAPI-positive nuclei.
4. Thresholds red and green-positive regions.
5. Measures marker integrated density from the raw channel within marker-positive regions.
6. Normalizes marker integrated density to DAPI-positive nuclei count.
7. Appends results into a final batch CSV.

Main output file:

```text
batch_IF_quantification.csv
```
---

## Main output columns

```text
Image
Condition
DAPI_nuclei_count
RFP intensity_per_DAPI
GFP intensity_per_DAPI
```
---

## Recommended primary readout

For comparisons where cell density differs between groups, the recommended primary readouts are:

```text
RFP_intensity_per_DAPI
GFP_intensity_per_DAPI
```

These are preferred over total integrated density because they normalize marker signal to DAPI-positive nuclei count.

## Macro 3: Single IF quantification 

For analysis for individual composite images

1. Open the Indiv_3channel-2D-Quant_v2.ijm Macro.
2. Open up a Composite File
3. Change User Settings and Hit Run

---

## Running the macros in Fiji

### Option 1: Run from Fiji menu

1. Open Fiji.
2. Go to:

```text
Plugins → Macros → Run...
```

3. Select the `.ijm` macro file.
4. Choose the input and output folders when prompted.

### Option 2: Open and edit macro first

1. Open Fiji.
2. Go to:

```text
Plugins → New → Macro
```

3. Paste or open the `.ijm` macro.
4. Edit user settings if needed.
5. Click:

```text
Run
```

or press:

```text
Ctrl + R
```

---

## Recommended image handling

Use:

```text
16-bit composite TIFFs for quantification
RGB/8-bit previews only for browsing and visual QC
```

Do not quantify:

```text
*_RGB_preview.tif
*_Montage.tif
*_Mask.tif
*_debug*.tif
*_outlines*.tif
```

Only quantify the composite files:
---

## Mask interpretation

For binary masks:

```text
White = selected / positive / included area
Black = background / negative / excluded area
```

For DAPI masks:

```text
White = DAPI-positive nuclei counted as nuclei
Black = non-nuclear background
```

For GFP and RFP masks:

```text
White = marker-positive region used for quantification
Black = excluded background
```

Poor masks can affect quantification. Before final analysis, visually inspect QC masks and exclude fields of view with obvious segmentation failure, debris, saturated signal, poor focus, or incorrect DAPI counts.

---

## Thresholding notes

Default threshold settings used in the macros:

| Marker      | Suggested threshold method |
| ----------- | -------------------------- |
| RFP (aSMA)        | Yen                        |
| GFP (CNN1 / CCN1) | Li                         |
| DAPI              | Otsu                       |

Alternative methods to test if masks are poor:

| Marker      | Alternative methods        |
| ----------- | -------------------------- |
| DAPI        | Otsu, Li, Moments, Default |
| aSMA        | Yen, Triangle, Otsu        |
| CNN1 / CCN1 | Li, Triangle, Otsu, Yen    |

Use the same thresholding approach across all groups wherever possible.

---

## Requirements

The macros were written for Fiji/ImageJ macro language.

Recommended software:

```text
Fiji/ImageJ
Java bundled with Fiji
```

No additional Fiji plugins are required for the basic workflow.

---
