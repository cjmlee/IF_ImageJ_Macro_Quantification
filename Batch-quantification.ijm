// ============================================================
// Fiji / ImageJ Macro
// Batch IF quantification for AMOTL2 composite files
//
// Input composite files:
//   WT_AMOTL2_1.tif
//   WT_AMOTL2_2.tif
//   KD_AMOTL2_1.tif
//   KD_AMOTL2_2.tif
//
// Expected channel order:
//   C1 = aSMA / Red
//   C2 = CCN1 or CNN1 / Green
//   C3 = DAPI / Blue
//
// Output:
//   One combined CSV with one row per composite image
//
// Main readouts:
//   aSMA_intensity_per_DAPI
//   CCN1_intensity_per_DAPI
// ============================================================


// ------------------------------------------------------------
// USER SETTINGS
// ------------------------------------------------------------

// Choose folders manually
inputDir = getDirectory("Choose folder containing 16-bit composite TIF files");
outputDir = getDirectory("Choose output folder for quantification results");

File.makeDirectory(outputDir);

// Marker names
markerCh1_name = "aSMA";
markerCh2_name = "CCN1";   // change to "CNN1" if your marker is CNN1
markerCh3_name = "DAPI";

// File extension
Extension = ".tif";

// Threshold method
// Use: "Auto" or "Intensity based"
Threshold_method = "Auto";

// Auto-threshold methods
Auto_thres_met_ch1 = "Yen";    // aSMA
Auto_thres_met_ch2 = "Li";     // CCN1/CNN1
Auto_thres_met_ch3 = "Otsu";   // DAPI

// Intensity thresholds, only used if Threshold_method = "Intensity based"
Thres_values_ch1 = newArray(0, 65535);
Thres_values_ch2 = newArray(0, 65535);
Thres_values_ch3 = newArray(0, 65535);

// Background subtraction for marker intensity quantification
Do_background_subtraction = true;
Rolling_ball_radius = 50;

// DAPI counting settings
// Start permissive. If overcounting, increase to 50-Infinity, 100-Infinity, etc.
DAPI_particle_size = "0-Infinity";
DAPI_particle_circularity = "0.00-1.00";

// DAPI preprocessing
DAPI_do_open = false;        // true removes small speckles
DAPI_fill_holes = true;
DAPI_do_watershed = false;   // use true only if nuclei are touching
DAPI_invert_mask = false;    // use true if nuclei become black and background white

// Save per-image QC masks?
Save_QC_masks = true;


// ------------------------------------------------------------
// PREPARE
// ------------------------------------------------------------

list = getFileList(inputDir);
Array.sort(list);

run("Clear Results");
run("Set Measurements...", "area mean integrated raw display redirect=None decimal=3");

setBatchMode(true);

processed = 0;
skipped = 0;


// ------------------------------------------------------------
// HELPER FUNCTIONS
// ------------------------------------------------------------

function isTifFile(name) {
	lower = toLowerCase(name);
	return endsWith(lower, ".tif") || endsWith(lower, ".tiff");
}


function shouldSkipFile(name) {
	lower = toLowerCase(name);

	if (indexOf(lower, "preview") != -1) return true;
	if (indexOf(lower, "rgb") != -1) return true;
	if (indexOf(lower, "mask") != -1) return true;
	if (indexOf(lower, "montage") != -1) return true;
	if (indexOf(lower, "outlines") != -1) return true;
	if (indexOf(lower, "debug") != -1) return true;

	return false;
}


function removeExtension(name) {
	clean = replace(name, ".tif", "");
	clean = replace(clean, ".TIF", "");
	clean = replace(clean, ".tiff", "");
	clean = replace(clean, ".TIFF", "");
	return clean;
}


function detectCondition(name) {
	lower = toLowerCase(name);

	if (indexOf(lower, "wt") != -1) return "WT";
	if (indexOf(lower, "kd") != -1) return "KD";

	return "UNKNOWN";
}


function applyThreshold(methodName, thresholdArray) {
	if (Threshold_method == "Auto") {
		setAutoThreshold(methodName + " dark");
	} else if (Threshold_method == "Intensity based") {
		setThreshold(thresholdArray[0], thresholdArray[1]);
	} else {
		exit("Error: Threshold_method must be Auto or Intensity based.");
	}
}


function closeIfOpen(title) {
	if (isOpen(title)) {
		selectWindow(title);
		close();
	}
}


function countDAPI(dapiTitle, baseName, dapiMethodName, dapiThresholdArray) {
	roiManager("Reset");

	selectWindow(dapiTitle);
	run("Duplicate...", "title=" + baseName + "_DAPI_count_tmp");
	selectWindow(baseName + "_DAPI_count_tmp");

	// Force pixel units
	run("Set Scale...", "distance=0 known=0 unit=pixel");

	run("8-bit");

	if (Threshold_method == "Auto") {
		setAutoThreshold(dapiMethodName + " dark");
	} else if (Threshold_method == "Intensity based") {
		setThreshold(dapiThresholdArray[0], dapiThresholdArray[1]);
	}

	run("Convert to Mask");

	if (DAPI_invert_mask == true) {
		run("Invert");
	}

	if (DAPI_do_open == true) {
		run("Options...", "iterations=1 count=1 black");
		run("Open");
	}

	if (DAPI_fill_holes == true) {
		run("Fill Holes");
	}

	if (DAPI_do_watershed == true) {
		run("Watershed");
	}

	if (Save_QC_masks == true) {
		saveAs("Tiff", outputDir + baseName + "_DAPI_count_mask.tif");
	}

	run("Analyze Particles...", "size=" + DAPI_particle_size + " circularity=" + DAPI_particle_circularity + " show=Nothing add");

	nuclei_count = roiManager("count");

	close();
	roiManager("Reset");

	return nuclei_count;
}


function getPositiveArea(channelTitle, markerName, baseName, methodName, thresholdArray) {
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + baseName + "_" + markerName + "_area_tmp");
	selectWindow(baseName + "_" + markerName + "_area_tmp");

	run("Set Scale...", "distance=0 known=0 unit=pixel");

	applyThreshold(methodName, thresholdArray);
	run("Create Selection");

	if (selectionType() == -1) {
		positiveArea = 0;
	} else {
		getRawStatistics(nPixels, meanVal, minVal, maxVal, stdVal);
		positiveArea = nPixels;
	}

	close();

	return positiveArea;
}


function getIntegratedDensityWithinPositiveArea(channelTitle, markerName, baseName, methodName, thresholdArray) {
	roiManager("Reset");

	// Step 1: make ROI from thresholded duplicate
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + baseName + "_" + markerName + "_roi_tmp");
	selectWindow(baseName + "_" + markerName + "_roi_tmp");

	run("Set Scale...", "distance=0 known=0 unit=pixel");

	applyThreshold(methodName, thresholdArray);
	run("Create Selection");

	if (selectionType() == -1) {
		close();
		roiManager("Reset");
		return 0;
	}

	roiManager("Add");

	if (Save_QC_masks == true) {
		run("Convert to Mask");
		saveAs("Tiff", outputDir + baseName + "_" + markerName + "_positive_mask.tif");
	}

	close();

	// Step 2: measure raw/background-subtracted channel inside ROI
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + baseName + "_" + markerName + "_raw_measure_tmp");
	selectWindow(baseName + "_" + markerName + "_raw_measure_tmp");

	run("Set Scale...", "distance=0 known=0 unit=pixel");

	if (Do_background_subtraction == true) {
		run("Subtract Background...", "rolling=" + Rolling_ball_radius);
	}

	roiManager("Select", 0);

	// Pixel-based integrated density
	getRawStatistics(nPixels, meanVal, minVal, maxVal, stdVal);
	intDen = nPixels * meanVal;

	close();
	roiManager("Reset");

	return intDen;
}


function getMeanIntensityWholeFOV(channelTitle, markerName, baseName) {
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + baseName + "_" + markerName + "_mean_tmp");
	selectWindow(baseName + "_" + markerName + "_mean_tmp");

	run("Set Scale...", "distance=0 known=0 unit=pixel");

	if (Do_background_subtraction == true) {
		run("Subtract Background...", "rolling=" + Rolling_ball_radius);
	}

	run("Select All");
	getRawStatistics(nPixels, meanVal, minVal, maxVal, stdVal);

	close();

	return meanVal;
}


// ------------------------------------------------------------
// MAIN BATCH LOOP
// ------------------------------------------------------------

print("======================================");
print("Batch IF quantification started");
print("Input folder: " + inputDir);
print("Output folder: " + outputDir);
print("Files found: " + list.length);
print("======================================");

for (i = 0; i < list.length; i++) {

	fileName = list[i];

	if (!isTifFile(fileName)) {
		continue;
	}

	if (shouldSkipFile(fileName)) {
		print("Skipping QC/display file: " + fileName);
		continue;
	}

	baseName = removeExtension(fileName);
	condition = detectCondition(fileName);

	print("Processing: " + fileName);

	// Open composite
	open(inputDir + fileName);
	originalTitle = getTitle();

	// Force pixel scale for opened composite
	run("Set Scale...", "distance=0 known=0 unit=pixel");

	// Split channels
	run("Split Channels");

	// Expected split channel window names
	ch1_old = "C1-" + originalTitle;
	ch2_old = "C2-" + originalTitle;
	ch3_old = "C3-" + originalTitle;

	// New safer names
	ch1_title = baseName + "_" + markerCh1_name;
	ch2_title = baseName + "_" + markerCh2_name;
	ch3_title = baseName + "_" + markerCh3_name;

	// Check split channels exist
	if (!isOpen(ch1_old) || !isOpen(ch2_old) || !isOpen(ch3_old)) {
		print("SKIPPED: Could not find split channels for " + fileName);
		closeIfOpen(originalTitle);
		closeIfOpen(ch1_old);
		closeIfOpen(ch2_old);
		closeIfOpen(ch3_old);
		skipped++;
		continue;
	}

	selectWindow(ch1_old); rename(ch1_title);
	selectWindow(ch2_old); rename(ch2_title);
	selectWindow(ch3_old); rename(ch3_title);

	// FOV area in pixels
	selectWindow(ch3_title);
	run("Set Scale...", "distance=0 known=0 unit=pixel");
	FOV_area = getWidth() * getHeight();

	// Quantification
	DAPI_nuclei_count = countDAPI(ch3_title, baseName, Auto_thres_met_ch3, Thres_values_ch3);

	aSMA_positive_area = getPositiveArea(ch1_title, markerCh1_name, baseName, Auto_thres_met_ch1, Thres_values_ch1);
	CCN1_positive_area = getPositiveArea(ch2_title, markerCh2_name, baseName, Auto_thres_met_ch2, Thres_values_ch2);
	DAPI_positive_area = getPositiveArea(ch3_title, markerCh3_name, baseName, Auto_thres_met_ch3, Thres_values_ch3);

	if (FOV_area > 0) {
		aSMA_percent_positive_area = 100 * aSMA_positive_area / FOV_area;
		CCN1_percent_positive_area = 100 * CCN1_positive_area / FOV_area;
		DAPI_percent_positive_area = 100 * DAPI_positive_area / FOV_area;
	} else {
		aSMA_percent_positive_area = 0;
		CCN1_percent_positive_area = 0;
		DAPI_percent_positive_area = 0;
	}

	aSMA_raw_mean = getMeanIntensityWholeFOV(ch1_title, markerCh1_name, baseName);
	CCN1_raw_mean = getMeanIntensityWholeFOV(ch2_title, markerCh2_name, baseName);

	aSMA_integrated_density = getIntegratedDensityWithinPositiveArea(ch1_title, markerCh1_name, baseName, Auto_thres_met_ch1, Thres_values_ch1);
	CCN1_integrated_density = getIntegratedDensityWithinPositiveArea(ch2_title, markerCh2_name, baseName, Auto_thres_met_ch2, Thres_values_ch2);

	if (DAPI_nuclei_count > 0) {
		aSMA_intensity_per_DAPI = aSMA_integrated_density / DAPI_nuclei_count;
		CCN1_intensity_per_DAPI = CCN1_integrated_density / DAPI_nuclei_count;
	} else {
		aSMA_intensity_per_DAPI = 0;
		CCN1_intensity_per_DAPI = 0;
	}

	// Append to Results table
	row = nResults;

	setResult("Image", row, baseName);
	setResult("Condition", row, condition);

	setResult("DAPI_nuclei_count", row, DAPI_nuclei_count);
	setResult("FOV_area_px", row, FOV_area);

	setResult(markerCh1_name + "_positive_area_px", row, aSMA_positive_area);
	setResult(markerCh2_name + "_positive_area_px", row, CCN1_positive_area);
	setResult(markerCh3_name + "_positive_area_px", row, DAPI_positive_area);

	setResult(markerCh1_name + "_percent_positive_area", row, aSMA_percent_positive_area);
	setResult(markerCh2_name + "_percent_positive_area", row, CCN1_percent_positive_area);
	setResult(markerCh3_name + "_percent_positive_area", row, DAPI_percent_positive_area);

	setResult(markerCh1_name + "_raw_mean_wholeFOV", row, aSMA_raw_mean);
	setResult(markerCh2_name + "_raw_mean_wholeFOV", row, CCN1_raw_mean);

	setResult(markerCh1_name + "_integrated_density_positive_area", row, aSMA_integrated_density);
	setResult(markerCh2_name + "_integrated_density_positive_area", row, CCN1_integrated_density);

	setResult(markerCh1_name + "_intensity_per_DAPI", row, aSMA_intensity_per_DAPI);
	setResult(markerCh2_name + "_intensity_per_DAPI", row, CCN1_intensity_per_DAPI);

	updateResults();

	// Cleanup image windows
	closeIfOpen(ch1_title);
	closeIfOpen(ch2_title);
	closeIfOpen(ch3_title);
	closeIfOpen(originalTitle);

	processed++;
}

setBatchMode(false);


// ------------------------------------------------------------
// EXPORT FINAL CSV
// ------------------------------------------------------------

finalCSV = outputDir + "AMOTL2_batch_IF_quantification.csv";
saveAs("Results", finalCSV);

print("======================================");
print("Batch IF quantification complete");
print("Processed images: " + processed);
print("Skipped images: " + skipped);
print("Final CSV:");
print(finalCSV);
print("======================================");