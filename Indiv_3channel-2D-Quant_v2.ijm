// ============================================================
// Fiji / ImageJ Macro
// IF quantification for VSMC differentiation / contractility
//
// Channels:
//   C1 = aSMA
//   C2 = CNN1
//   C3 = DAPI
//
// Main output:
//   aSMA_intensity_per_DAPI
//   CNN1_intensity_per_DAPI
//
// Meaning:
//   marker integrated density inside marker-positive area
//   divided by number of DAPI+ nuclei
//
// No scale bar.
// Robust DAPI debug mask/outlines output.
// ============================================================


// ------------------------------------------------------------
// USER SETTINGS
// ------------------------------------------------------------

output = "D:/CoronaryCAD_Jun_Bw/Imaging/WT_AMOTL2/1/";

Extension = ".tif";

markerCh1_name = "aSMA";
markerCh2_name = "CNN1";
markerCh3_name = "DAPI";

Color_ch1 = "Red";
Color_ch2 = "Green";
Color_ch3 = "Blue";

// Threshold method for aSMA/CNN1/DAPI masks
// Use: "Auto" or "Intensity based"
Threshold_method = "Auto";

// Auto-threshold methods
Auto_thres_met_ch1 = "Yen";    // aSMA
Auto_thres_met_ch2 = "Li";     // CNN1
Auto_thres_met_ch3 = "Otsu";   // DAPI

// Intensity thresholds, only used if Threshold_method = "Intensity based"
Thres_values_ch1 = newArray(0, 4095);
Thres_values_ch2 = newArray(0, 4095);
Thres_values_ch3 = newArray(0, 4095);

// Background subtraction for fluorescence quantification
Do_background_subtraction = true;
Rolling_ball_radius = 50;

// DAPI counting settings
// Start permissive first.
// If DAPI count is too high, increase to 50-Infinity, 100-Infinity, 150-Infinity.
DAPI_particle_size = "0-Infinity";
DAPI_particle_circularity = "0.00-1.00";

// DAPI preprocessing
DAPI_do_open = false;        // true removes small speckles
DAPI_fill_holes = true;
DAPI_do_watershed = false;   // only true if nuclei are touching
DAPI_invert_mask = false;    // set true if nuclei are black and background white

// Debugging
Manual_DAPI_threshold_check = true;
Manual_marker_threshold_check = false;

// Display only
Enhance_display_contrast = true;
Display_saturation = 0.35;


// ------------------------------------------------------------
// PREPARE
// ------------------------------------------------------------

File.makeDirectory(output);
run("Set Measurements...", "area mean integrated raw display redirect=None decimal=3");


// ------------------------------------------------------------
// HELPER FUNCTIONS
// ------------------------------------------------------------

function cleanTitle(originalTitle, extension) {
	clean = replace(originalTitle, extension, "");
	return clean;
}


function saveAndRenameChannel(oldTitle, newTitle, colourName) {
	selectWindow(oldTitle);
	saveAs("Tiff", output + newTitle);
	rename(newTitle);
	run(colourName);
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


function createMask(channelTitle, markerName, methodName, thresholdArray, colourName, maskOutputTitle) {
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + markerName + "_mask_tmp");
	selectWindow(markerName + "_mask_tmp");

	applyThreshold(methodName, thresholdArray);

	if (Manual_marker_threshold_check == true) {
		waitForUser("Check threshold for " + markerName + ". Signal should be selected. Click OK.");
	}

	run("Convert to Mask");
	run(colourName);
	run("RGB Color");

	saveAs("Tiff", output + maskOutputTitle);
	close();
}


function countDAPI(dapiTitle, dapiMethodName, dapiThresholdArray) {
	roiManager("Reset");

	selectWindow(dapiTitle);
	run("Duplicate...", "title=DAPI_count_tmp");
	selectWindow("DAPI_count_tmp");

	// Force pixel units
	run("Set Scale...", "distance=0 known=0 unit=pixel");

	run("8-bit");

	if (Enhance_display_contrast == true) {
		run("Enhance Contrast", "saturated=" + Display_saturation);
	}

	// Threshold DAPI
	if (Threshold_method == "Auto") {
		setAutoThreshold(dapiMethodName + " dark");
	} else if (Threshold_method == "Intensity based") {
		setThreshold(dapiThresholdArray[0], dapiThresholdArray[1]);
	} else {
		exit("Error: Threshold_method must be Auto or Intensity based.");
	}

	if (Manual_DAPI_threshold_check == true) {
		waitForUser("Check DAPI threshold.\n\nNuclei should be selected/highlighted.\nClick OK to continue.");
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

	// Save DAPI binary mask for QC
	saveAs("Tiff", output + titlewoext + "_DAPI_debug_mask.tif");

	// After saveAs, Fiji may rename the active window.
	// Capture the real active mask title.
	dapiMaskWindow = getTitle();

	// Analyze particles and create outlines
	run("Analyze Particles...", "size=" + DAPI_particle_size + " circularity=" + DAPI_particle_circularity + " show=Outlines display add");

	nuclei_count = roiManager("count");

	// Fiji creates a window like:
	// "Drawing of WT_AMOTL2_1_DAPI_debug_mask.tif"
	// But title can vary, so save whatever active drawing window exists.
	currentWindow = getTitle();

	if (indexOf(currentWindow, "Drawing of") == 0) {
		saveAs("Tiff", output + titlewoext + "_DAPI_count_outlines.tif");
		close(currentWindow);
	} else {
		print("Warning: expected a Drawing window, but active window was: " + currentWindow);
	}

	// Close DAPI mask/counting window
	if (isOpen(dapiMaskWindow)) {
		selectWindow(dapiMaskWindow);
		close();
	}

	if (isOpen("DAPI_count_tmp")) {
		selectWindow("DAPI_count_tmp");
		close();
	}

	roiManager("Reset");

	return nuclei_count;
}


function getPositiveArea(channelTitle, markerName, methodName, thresholdArray) {
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + markerName + "_area_tmp");
	selectWindow(markerName + "_area_tmp");

	run("Set Scale...", "distance=0 known=0 unit=pixel");

	applyThreshold(methodName, thresholdArray);

	if (Manual_marker_threshold_check == true) {
		waitForUser("Check positive area threshold for " + markerName + ". Click OK.");
	}

	run("Create Selection");

	if (selectionType() == -1) {
		positiveArea = 0;
	} else {
		getRawStatistics(nPixels, meanVal, minVal, maxVal, stdVal);
		positiveArea = nPixels;
	}

	close(markerName + "_area_tmp");

	return positiveArea;
}


function getIntegratedDensityWithinPositiveArea(channelTitle, markerName, methodName, thresholdArray) {
	roiManager("Reset");

	// Make ROI from thresholded duplicate
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + markerName + "_roi_tmp");
	selectWindow(markerName + "_roi_tmp");

	// Force pixel units
	run("Set Scale...", "distance=0 known=0 unit=pixel");

	applyThreshold(methodName, thresholdArray);

	if (Manual_marker_threshold_check == true) {
		waitForUser("Check ROI threshold for " + markerName + ". Click OK.");
	}

	run("Create Selection");

	if (selectionType() == -1) {
		close(markerName + "_roi_tmp");
		roiManager("Reset");
		return 0;
	}

	roiManager("Add");
	close(markerName + "_roi_tmp");

	// Measure raw/background-subtracted channel inside ROI
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + markerName + "_raw_measure_tmp");
	selectWindow(markerName + "_raw_measure_tmp");

	// Force pixel units again on the measurement image
	run("Set Scale...", "distance=0 known=0 unit=pixel");

	if (Do_background_subtraction == true) {
		run("Subtract Background...", "rolling=" + Rolling_ball_radius);
	}

	roiManager("Select", 0);

	// IMPORTANT:
	// getStatistics area can still behave oddly with calibration.
	// getRawStatistics gives number of pixels directly.
	getRawStatistics(nPixels, meanVal, minVal, maxVal, stdVal);

	// Pixel-based integrated density
	intDen = nPixels * meanVal;

	close(markerName + "_raw_measure_tmp");
	roiManager("Reset");

	return intDen;
}


function getMeanIntensityWholeFOV(channelTitle, markerName) {
	selectWindow(channelTitle);
	run("Duplicate...", "title=" + markerName + "_mean_tmp");
	selectWindow(markerName + "_mean_tmp");

	if (Do_background_subtraction == true) {
		run("Subtract Background...", "rolling=" + Rolling_ball_radius);
	}

	run("Select All");
	getStatistics(areaVal, meanVal, minVal, maxVal, stdVal);

	close(markerName + "_mean_tmp");

	return meanVal;
}


function makeDisplayCopy(inputTitle, outputWindowTitle, colourName) {
	selectWindow(inputTitle);
	run("Duplicate...", "title=" + outputWindowTitle);
	selectWindow(outputWindowTitle);

	if (Do_background_subtraction == true) {
		run("Subtract Background...", "rolling=" + Rolling_ball_radius);
	}

	run(colourName);

	if (Enhance_display_contrast == true) {
		run("Enhance Contrast", "saturated=" + Display_saturation);
	}

	run("RGB Color");
	rename(outputWindowTitle);
}


// ------------------------------------------------------------
// MAIN SCRIPT
// ------------------------------------------------------------

title = getTitle();
titlewoext = cleanTitle(title, Extension);

// Expected Fiji split-channel names
markerA_ch = "C1-" + title;
markerB_ch = "C2-" + title;
markerC_ch = "C3-" + title;

// Clean channel names
ch1_title = titlewoext + "_" + markerCh1_name + ".tif";
ch2_title = titlewoext + "_" + markerCh2_name + ".tif";
ch3_title = titlewoext + "_" + markerCh3_name + ".tif";


// ------------------------------------------------------------
// SPLIT CHANNELS
// ------------------------------------------------------------

run("Split Channels");

saveAndRenameChannel(markerA_ch, ch1_title, Color_ch1);
saveAndRenameChannel(markerB_ch, ch2_title, Color_ch2);
saveAndRenameChannel(markerC_ch, ch3_title, Color_ch3);

run("Tile");


// ------------------------------------------------------------
// RAW MERGE IMAGE, NO SCALE BAR
// c1 = red, c2 = green, c3 = blue
// ------------------------------------------------------------

run("Merge Channels...",
	"c1=[" + ch1_title + "] " +
	"c2=[" + ch2_title + "] " +
	"c3=[" + ch3_title + "] keep create");

rename(titlewoext + "_Composite.tif");
saveAs("Tiff", output + titlewoext + "_Composite.tif");

run("RGB Color");
rename(titlewoext + "_Merged_raw.tif");
saveAs("Tiff", output + titlewoext + "_Merged_raw.tif");


// ------------------------------------------------------------
// MASKS
// ------------------------------------------------------------

createMask(ch1_title, markerCh1_name, Auto_thres_met_ch1, Thres_values_ch1, Color_ch1, titlewoext + "_" + markerCh1_name + "_Mask.tif");

createMask(ch2_title, markerCh2_name, Auto_thres_met_ch2, Thres_values_ch2, Color_ch2, titlewoext + "_" + markerCh2_name + "_Mask.tif");

createMask(ch3_title, markerCh3_name, Auto_thres_met_ch3, Thres_values_ch3, Color_ch3, titlewoext + "_" + markerCh3_name + "_Mask.tif");


// ------------------------------------------------------------
// QUANTIFICATION
// ------------------------------------------------------------

// DAPI nuclei count
DAPI_nuclei_count = countDAPI(ch3_title, Auto_thres_met_ch3, Thres_values_ch3);

// FOV area
selectWindow(ch3_title);
run("Set Scale...", "distance=0 known=0 unit=pixel");
FOV_area = getWidth() * getHeight();

// Positive areas
aSMA_positive_area = getPositiveArea(ch1_title, markerCh1_name, Auto_thres_met_ch1, Thres_values_ch1);
CNN1_positive_area = getPositiveArea(ch2_title, markerCh2_name, Auto_thres_met_ch2, Thres_values_ch2);
DAPI_positive_area = getPositiveArea(ch3_title, markerCh3_name, Auto_thres_met_ch3, Thres_values_ch3);

// Percent positive area
if (FOV_area > 0) {
	aSMA_percent_positive_area = 100 * aSMA_positive_area / FOV_area;
	CNN1_percent_positive_area = 100 * CNN1_positive_area / FOV_area;
	DAPI_percent_positive_area = 100 * DAPI_positive_area / FOV_area;
} else {
	aSMA_percent_positive_area = 0;
	CNN1_percent_positive_area = 0;
	DAPI_percent_positive_area = 0;
}

// Whole-FOV mean after background subtraction
aSMA_raw_mean = getMeanIntensityWholeFOV(ch1_title, markerCh1_name);
CNN1_raw_mean = getMeanIntensityWholeFOV(ch2_title, markerCh2_name);

// Integrated density inside marker-positive area
aSMA_integrated_density = getIntegratedDensityWithinPositiveArea(ch1_title, markerCh1_name, Auto_thres_met_ch1, Thres_values_ch1);
CNN1_integrated_density = getIntegratedDensityWithinPositiveArea(ch2_title, markerCh2_name, Auto_thres_met_ch2, Thres_values_ch2);

// Main readout: intensity per DAPI nucleus
if (DAPI_nuclei_count > 0) {
	aSMA_intensity_per_DAPI = aSMA_integrated_density / DAPI_nuclei_count;
	CNN1_intensity_per_DAPI = CNN1_integrated_density / DAPI_nuclei_count;
} else {
	aSMA_intensity_per_DAPI = 0;
	CNN1_intensity_per_DAPI = 0;
}


// ------------------------------------------------------------
// EXPORT RESULTS
// ------------------------------------------------------------

run("Clear Results");

row = 0;

setResult("Image", row, titlewoext);
setResult("DAPI_nuclei_count", row, DAPI_nuclei_count);
setResult("FOV_area", row, FOV_area);

setResult(markerCh1_name + "_positive_area", row, aSMA_positive_area);
setResult(markerCh2_name + "_positive_area", row, CNN1_positive_area);
setResult(markerCh3_name + "_positive_area", row, DAPI_positive_area);

setResult(markerCh1_name + "_percent_positive_area", row, aSMA_percent_positive_area);
setResult(markerCh2_name + "_percent_positive_area", row, CNN1_percent_positive_area);
setResult(markerCh3_name + "_percent_positive_area", row, DAPI_percent_positive_area);

setResult(markerCh1_name + "_raw_mean_wholeFOV", row, aSMA_raw_mean);
setResult(markerCh2_name + "_raw_mean_wholeFOV", row, CNN1_raw_mean);

setResult(markerCh1_name + "_integrated_density_positive_area", row, aSMA_integrated_density);
setResult(markerCh2_name + "_integrated_density_positive_area", row, CNN1_integrated_density);

setResult(markerCh1_name + "_intensity_per_DAPI", row, aSMA_intensity_per_DAPI);
setResult(markerCh2_name + "_intensity_per_DAPI", row, CNN1_intensity_per_DAPI);

updateResults();

saveAs("Results", output + titlewoext + "_IF_quantification.csv");


// ------------------------------------------------------------
// DISPLAY MERGE, NO SCALE BAR
// This does not affect quantification.
// ------------------------------------------------------------

display_ch1 = titlewoext + "_" + markerCh1_name + "_display";
display_ch2 = titlewoext + "_" + markerCh2_name + "_display";
display_ch3 = titlewoext + "_" + markerCh3_name + "_display";

makeDisplayCopy(ch1_title, display_ch1, Color_ch1);
makeDisplayCopy(ch2_title, display_ch2, Color_ch2);
makeDisplayCopy(ch3_title, display_ch3, Color_ch3);

run("Merge Channels...",
	"c1=[" + display_ch1 + "] " +
	"c2=[" + display_ch2 + "] " +
	"c3=[" + display_ch3 + "] keep create");

rename(titlewoext + "_Merged_adj.tif");
run("RGB Color");
rename(titlewoext + "_Merged_adj.tif");
saveAs("Tiff", output + titlewoext + "_Merged_adj.tif");


// ------------------------------------------------------------
// MONTAGE: CHANNELS + MERGE
// ------------------------------------------------------------

merged_display = titlewoext + "_Merged_adj.tif";

run("Concatenate...",
	"title=[Stack] " +
	"image1=[" + display_ch1 + "] " +
	"image2=[" + display_ch2 + "] " +
	"image3=[" + display_ch3 + "] " +
	"image4=[" + merged_display + "]");

selectWindow("Stack");
run("Make Montage...", "columns=4 rows=1 scale=1 first=1 last=4");

selectWindow("Montage");
run("RGB Color");
saveAs("Tiff", output + titlewoext + "_Montage_colors.tif");

close("Stack");


// ------------------------------------------------------------
// MONTAGE: MASKS
// ------------------------------------------------------------

open(output + titlewoext + "_" + markerCh1_name + "_Mask.tif");
rename(titlewoext + "_" + markerCh1_name + "_Mask");

open(output + titlewoext + "_" + markerCh2_name + "_Mask.tif");
rename(titlewoext + "_" + markerCh2_name + "_Mask");

open(output + titlewoext + "_" + markerCh3_name + "_Mask.tif");
rename(titlewoext + "_" + markerCh3_name + "_Mask");

run("Concatenate...",
	"title=[Mask_Stack] " +
	"image1=[" + titlewoext + "_" + markerCh1_name + "_Mask] " +
	"image2=[" + titlewoext + "_" + markerCh2_name + "_Mask] " +
	"image3=[" + titlewoext + "_" + markerCh3_name + "_Mask]");

selectWindow("Mask_Stack");
run("Make Montage...", "columns=3 rows=1 scale=1 first=1 last=3");

selectWindow("Montage");
run("RGB Color");
saveAs("Tiff", output + titlewoext + "_Montage_masks.tif");

close("Mask_Stack");


// ------------------------------------------------------------
// DONE
// ------------------------------------------------------------

print("Done quantifying: " + titlewoext);
print("DAPI nuclei count = " + DAPI_nuclei_count);
print(markerCh1_name + " intensity per DAPI = " + aSMA_intensity_per_DAPI);
print(markerCh2_name + " intensity per DAPI = " + CNN1_intensity_per_DAPI);
print("Check DAPI QC files:");
print(output + titlewoext + "_DAPI_debug_mask.tif");
print(output + titlewoext + "_DAPI_count_outlines.tif");