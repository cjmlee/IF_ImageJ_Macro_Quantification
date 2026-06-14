// ============================================================
// Fiji Macro: Create AMOTL2 composite files from raw channels
//
// Input raw files can be like:
//   ...d0 - DAPI (Blue).tif
//   ...d1 - CCN1 (Green).tif
//   ...d2 - aSMA (Red).tif
//
// Output:
//   WT_AMOTL2_1.tif
//   WT_AMOTL2_2.tif
//   KD_AMOTL2_1.tif
//   KD_AMOTL2_2.tif
//
// Channel order in output composite:
//   C1 = aSMA / Red
//   C2 = CCN1 or CNN1 / Green
//   C3 = DAPI / Blue
// ============================================================


// ------------------------------------------------------------
// CHOOSE FOLDERS
// ------------------------------------------------------------

inputDir = getDirectory("Choose folder containing raw single-channel TIF files");
outputDir = getDirectory("Choose output folder for composite files");

File.makeDirectory(outputDir);

list = getFileList(inputDir);
Array.sort(list);

setBatchMode(true);


// ------------------------------------------------------------
// COUNTERS AND LOG
// ------------------------------------------------------------

wtCount = 0;
kdCount = 0;
unknownCount = 0;
processed = 0;
skipped = 0;

mappingText = "Original_Base,Condition,DAPI_File,CCN1_File,aSMA_File,Composite_Name\n";

print("======================================");
print("Input folder: " + inputDir);
print("Output folder: " + outputDir);
print("Number of files in input folder: " + list.length);
print("======================================");


// ------------------------------------------------------------
// HELPER FUNCTIONS
// ------------------------------------------------------------

function isTifFile(name) {
	lower = toLowerCase(name);
	return endsWith(lower, ".tif") || endsWith(lower, ".tiff");
}


function containsAnyChannelTag(name, tag1, tag2, tag3) {
	lower = toLowerCase(name);
	return indexOf(lower, toLowerCase(tag1)) != -1 ||
	       indexOf(lower, toLowerCase(tag2)) != -1 ||
	       indexOf(lower, toLowerCase(tag3)) != -1;
}


function getBaseFromDAPI(name) {
	// Remove the channel-specific part.
	// Works for names like:
	// XXXd0 - DAPI (Blue).tif
	// XXX - DAPI (Blue).tif
	// XXX_DAPI.tif

	base = name;

	if (indexOf(base, "d0") != -1) {
		base = substring(base, 0, indexOf(base, "d0"));
		return base;
	}

	if (indexOf(base, "DAPI") != -1) {
		base = substring(base, 0, indexOf(base, "DAPI"));
		return base;
	}

	if (indexOf(base, "dapi") != -1) {
		base = substring(base, 0, indexOf(base, "dapi"));
		return base;
	}

	return base;
}


function detectCondition(name) {
	lower = toLowerCase(name);

	if (indexOf(lower, "wt") != -1) {
		return "WT";
	}

	if (indexOf(lower, "kd") != -1) {
		return "KD";
	}

	return "UNKNOWN";
}


function cleanBaseForMatching(base) {
	// Remove trailing separators/spaces that differ between channels
	base = replace(base, " - ", "");
	base = replace(base, "-", "");
	base = replace(base, "_", "");
	base = replace(base, " ", "");
	return toLowerCase(base);
}


function closeIfOpen(title) {
	if (isOpen(title)) {
		selectWindow(title);
		close();
	}
}


// ------------------------------------------------------------
// MAIN LOOP
// Start from files containing DAPI
// ------------------------------------------------------------

for (i = 0; i < list.length; i++) {

	fileName = list[i];

	if (!isTifFile(fileName)) {
		continue;
	}

	lowerName = toLowerCase(fileName);

	// Start only from DAPI files
	if (indexOf(lowerName, "dapi") == -1 && indexOf(lowerName, "d0") == -1) {
		continue;
	}

	baseName = getBaseFromDAPI(fileName);
	baseKey = cleanBaseForMatching(baseName);

	dapiFile = fileName;
	ccn1File = "";
	asmaFile = "";

	// Find matching CCN1/CNN1 and aSMA from same base
	for (j = 0; j < list.length; j++) {

		candidate = list[j];

		if (!isTifFile(candidate)) {
			continue;
		}

		candidateKey = cleanBaseForMatching(candidate);

		// Must share same base
		if (indexOf(candidateKey, baseKey) == -1) {
			continue;
		}

		candLower = toLowerCase(candidate);

		// Green channel: CCN1/CNN1 or d1
		if (indexOf(candLower, "ccn1") != -1 ||
			indexOf(candLower, "cnn1") != -1 ||
			indexOf(candLower, "d1") != -1) {
			ccn1File = candidate;
		}

		// Red channel: aSMA or d2
		if (indexOf(candLower, "asma") != -1 ||
			indexOf(candLower, "αsma") != -1 ||
			indexOf(candLower, "d2") != -1) {
			asmaFile = candidate;
		}
	}

	if (ccn1File == "" || asmaFile == "") {
		print("SKIPPED incomplete set:");
		print("  Base: " + baseName);
		print("  DAPI: " + dapiFile);
		print("  CCN1/CNN1: " + ccn1File);
		print("  aSMA: " + asmaFile);
		skipped++;
		continue;
	}

	condition = detectCondition(fileName);

	if (condition == "WT") {
		wtCount++;
		compositeBase = "WT_AMOTL2_" + wtCount;
	} else if (condition == "KD") {
		kdCount++;
		compositeBase = "KD_AMOTL2_" + kdCount;
	} else {
		unknownCount++;
		compositeBase = "UNKNOWN_AMOTL2_" + unknownCount;
	}

	print("Processing set:");
	print("  Base: " + baseName);
	print("  Condition: " + condition);
	print("  DAPI: " + dapiFile);
	print("  CCN1/CNN1: " + ccn1File);
	print("  aSMA: " + asmaFile);
	print("  Output: " + compositeBase + ".tif");


	// --------------------------------------------------------
	// OPEN CHANNELS
	// --------------------------------------------------------
	// Open DAPI channel
	open(inputDir + dapiFile);
	run("16-bit");
	rename(compositeBase + "_DAPI");
	// Open CCN1/CNN1 channel
	open(inputDir + ccn1File);
	run("16-bit");
	rename(compositeBase + "_CCN1");
	// Open aSMA channel
	open(inputDir + asmaFile);
	run("16-bit");
	rename(compositeBase + "_aSMA");


	// --------------------------------------------------------
	// CREATE COMPOSITE
	// Fiji channel mapping:
	//   c1 = red   = aSMA
	//   c2 = green = CCN1/CNN1
	//   c3 = blue  = DAPI
	// --------------------------------------------------------

	run("Merge Channels...",
		"c1=[" + compositeBase + "_aSMA] " +
		"c2=[" + compositeBase + "_CCN1] " +
		"c3=[" + compositeBase + "_DAPI] create");

	rename(compositeBase + ".tif");
	saveAs("Tiff", outputDir + compositeBase + ".tif");
	
	// --------------------------------------------------------
	// Save RGB preview for Windows Explorer QC only
	// Do NOT use this file for quantification
	// --------------------------------------------------------
	run("Duplicate...", "title=" + compositeBase + "_RGB_preview");
	selectWindow(compositeBase + "_RGB_preview");
	// Adjust display for browsing only
	run("Enhance Contrast", "saturated=0.35");
	run("RGB Color");
	saveAs("Tiff", outputDir + compositeBase + "_RGB_preview.tif");
	close();


	// Record mapping
	mappingText = mappingText + baseName + "," + condition + "," +
	              dapiFile + "," + ccn1File + "," + asmaFile + "," +
	              compositeBase + ".tif\n";


	// --------------------------------------------------------
	// CLEAN UP
	// --------------------------------------------------------

	closeIfOpen(compositeBase + ".tif");
	closeIfOpen(compositeBase + "_DAPI");
	closeIfOpen(compositeBase + "_CCN1");
	closeIfOpen(compositeBase + "_aSMA");

	processed++;
}

setBatchMode(false);


// ------------------------------------------------------------
// SAVE MAPPING
// ------------------------------------------------------------

File.saveString(mappingText, outputDir + "composite_name_mapping.csv");

print("======================================");
print("Batch composite creation complete.");
print("Processed complete sets: " + processed);
print("Skipped incomplete sets: " + skipped);
print("WT composites created: " + wtCount);
print("KD composites created: " + kdCount);
print("Unknown composites created: " + unknownCount);
print("Saved mapping file:");
print(outputDir + "composite_name_mapping.csv");
print("======================================");