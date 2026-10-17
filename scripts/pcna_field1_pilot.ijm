// PCNA1-GFP manual pilot, Fiji / ImageJ 1.54p.
// No pixel-changing commands. One locator ROI and table row per nucleus.
// This version intentionally cannot mark a field complete.
var expectedSeries = "protoplasts 2h post irradiation image 1";
var schema = "PCNA_FIELD1_PILOT_V1";
var fieldStatus = "INCOMPLETE_PILOT";
var imageID, sourcePath, sessionDir, width0, height0, depth0;
var pixelWidth0, pixelHeight0, pixelDepth0, unit0;
var n = 0, checkpoint = 0;
var ids = newArray(0), firstZ = newArray(0), refZ = newArray(0), lastZ = newArray(0);
var patterns = newArray(0), eligibility = newArray(0), reasons = newArray(0);
var displayNotes = newArray(0), displayMin = newArray(0), displayMax = newArray(0);
var bx = newArray(0), by = newArray(0), bw = newArray(0), bh = newArray(0);

runPilot(); // ENTRY POINT: replaced only by the headless test harness.

function runPilot() {
    requires("1.54p");
    if (nImages == 0) exit("Open the field-1 LIF series using Bio-Formats first. See the guide.");
    imageID = getImageID();
    getDimensions(width0, height0, channels, depth0, frames);
    getPixelSize(unit0, pixelWidth0, pixelHeight0, pixelDepth0);
    if (width0 != 1024 || height0 != 1024 || depth0 != 46 || channels != 1 || frames != 1 || bitDepth != 8)
        exit("Expected field 1: 1024 x 1024, 46 z-slices, one channel, one timepoint, 8-bit. Reopen the correct original series.");
    if (indexOf(getTitle(), expectedSeries) < 0)
        exit("Image title must contain the exact series name:\n" + expectedSeries + "\nReopen using Bio-Formats; do not rename another stack to bypass this check.");
    if (roiManager("count") != 0)
        exit("Save any existing ROI Manager work, then clear ROI Manager before starting this pilot.");
    sourcePath = File.openDialog("Select original data/vukan protoplasts.lif to identify the source (not modified)");
    sourcePath = replace(sourcePath, "\\", "/");
    if (!endsWith(toLowerCase(sourcePath), "/vukan protoplasts.lif"))
        exit("Select the original vukan protoplasts.lif file.");
    Dialog.create("PCNA field 1 pilot");
    Dialog.addMessage("Confirm: the active image was opened from this LIF, selecting:\n" + expectedSeries + "\n\nOnly 10-15 nuclei in this trial. All exports remain INCOMPLETE_PILOT.");
    Dialog.addChoice("Session", newArray("New session", "Resume saved session"));
    Dialog.addCheckbox("I confirm the source and series", false);
    Dialog.show();
    mode = Dialog.getChoice();
    if (!Dialog.getCheckbox()) exit("Source/series confirmation is required.");
    sessionDir = replace(getDirectory("Choose a dedicated pilot session folder inside results"), "\\", "/");
    if (mode == "New session") {
        if (File.exists(sessionDir + "latest.txt")) exit("A session already exists here. Restart and choose Resume.");
        files = getFileList(sessionDir);
        if (files.length != 0) exit("For a new session, choose an empty dedicated folder.");
        saveCheckpoint();
    } else {
        loadSession();
    }
    while (true) {
        checkImage();
        checkRois();
        Dialog.createNonBlocking("PCNA pilot: " + n + " records | INCOMPLETE");
        Dialog.addMessage("Browse z and zoom normally. Keep contrast fixed within each review.\nUse this menu for changes; do not add/delete/rename ROIs directly.\nAll counts describe only recorded nuclei, not the entire field.");
        Dialog.addChoice("Action", newArray("Add nucleus", "Review / edit existing ID", "Save checkpoint / export counts", "Save and stop for review"));
        Dialog.show();
        action = Dialog.getChoice();
        checkImage();
        checkRois();
        if (action == "Add nucleus") {
            if (n >= 15) showMessage("Trial limit", "15 records reached. Review the trial before expanding. You can still edit and save.");
            else annotate(-1);
        } else if (action == "Review / edit existing ID") {
            if (n == 0) showMessage("No records", "Add a nucleus first.");
            else {
                Dialog.create("Choose stable ID");
                Dialog.addChoice("Nucleus", ids);
                Dialog.show();
                chosen = Dialog.getChoice();
                k = indexOfID(chosen);
                annotate(k);
            }
        } else if (action == "Save checkpoint / export counts") {
            saveCheckpoint();
            showMessage("Saved", "Checkpoint " + checkpoint + " saved.\nCounts remain INCOMPLETE_PILOT.\n" + sessionDir);
        } else {
            saveCheckpoint();
            showMessage("Stop for pilot review", "Saved " + n + " records. Field remains INCOMPLETE_PILOT.\nReview the 10-15 nucleus trial before expanding.\n" + sessionDir);
            exit();
        }
    }
}

function checkImage() {
    if (!isOpen(imageID)) exit("Source image closed. Reopen the original series and resume the session.");
    selectImage(imageID);
    getDimensions(w, h, c, z, t);
    getPixelSize(u, pw, ph, pd);
    if (w != width0 || h != height0 || z != depth0 || c != 1 || t != 1 || bitDepth != 8 || u != unit0 || pw != pixelWidth0 || ph != pixelHeight0 || pd != pixelDepth0)
        exit("Image dimensions/calibration changed. Reopen the original and resume the last saved checkpoint.");
}

function checkRois() {
    if (roiManager("count") != n) exit("ROI Manager changed outside the tool. Restart and resume the last saved checkpoint.");
    for (i = 0; i < n; i++) {
        if (RoiManager.getName(i) != ids[i]) exit("ROI names/order changed. Restart and resume the last saved checkpoint.");
    }
}

function annotate(k) {
    checkImage();
    if (k >= 0) {
        setSlice(refZ[k]);
        roiManager("select", k);
        setMinAndMax(displayMin[k], displayMax[k]); // display only, never Apply
        label = ids[k];
    } else {
        run("Select None");
        label = nextID(n);
    }
    waitForUser("Review " + label,
        "Follow ONE identifiable GFP-positive nucleus through z.\nDraw/adjust ONE oval or polygon enclosing its outer nuclear region\non a representative slice, including any dark internal region.\nDo not enclose only the bright puncta or a neighboring nucleus.\n\nNote the first and last visible slices; finish on your reference slice.\nFor editing, keep the existing ROI or redraw it here.\nClick OK to enter the record. No record is committed yet.");
    checkImage();
    checkRois();
    kind = selectionType();
    if (!(kind == 0 || kind == 1 || kind == 2 || kind == 3 || kind == 4)) {
        showMessage("Locator needed", "Use one rectangle, oval, polygon, freehand or traced area ROI. No record saved.");
        return;
    }
    getSelectionBounds(x, y, w, h);
    getSelectionCoordinates(outlineX, outlineY);
    r = getSliceNumber();
    f = r; l = r; p = "uncertain"; e = "eligible"; reason = ""; note = "";
    if (k >= 0) {
        f = firstZ[k]; l = lastZ[k]; p = patterns[k]; e = eligibility[k];
        reason = reasons[k]; note = displayNotes[k];
    }
    getMinAndMax(lo, hi);
    Dialog.create("Record " + label);
    Dialog.addNumber("First visible z (1-46)", f, 0, 6, "");
    Dialog.addNumber("Reference z (ROI drawn here)", r, 0, 6, "");
    Dialog.addNumber("Last visible z (1-46)", l, 0, 6, "");
    Dialog.addChoice("Pattern / annotation status", newArray("diffuse/non-punctate", "punctate", "uncertain"), p);
    Dialog.addChoice("Eligibility (separate from pattern)", newArray("eligible", "excluded"), e);
    Dialog.addString("Reason / comment", reason, 55);
    Dialog.addMessage("Reason required for uncertain or excluded.\nExclusions: XY truncated; z truncated; unresolved identity; duplicate of ID.\nDo not exclude simply because the pattern is ambiguous.\nDisplay range now: " + lo + " to " + hi);
    Dialog.addString("Display adjustments / review notes", note, 55);
    Dialog.addCheckbox("I reviewed through z with fixed contrast and confirm the locator", false);
    Dialog.show();
    f = Dialog.getNumber(); r = Dialog.getNumber(); l = Dialog.getNumber();
    p = Dialog.getChoice(); e = Dialog.getChoice();
    reason = cleanText(Dialog.getString()); note = cleanText(Dialog.getString());
    confirmed = Dialog.getCheckbox();
    if (!confirmed || !validZ(f, r, l, depth0)) {
        showMessage("Not committed", "Confirm the review and use integer slices: 1 <= first <= reference <= last <= 46. Try Add/Edit again.");
        return;
    }
    if ((p == "uncertain" || e == "excluded") && reason == "") {
        showMessage("Reason needed", "Record an uncertainty or exclusion reason. No changes committed.");
        return;
    }
    if (e == "eligible" && (f == 1 || l == depth0 || x <= 0 || y <= 0 || x+w >= width0 || y+h >= height0)) {
        showMessage("Boundary review", "Locator or z-range reaches an image boundary.\nIf the nucleus is visibly truncated, set eligibility to excluded and record XY or z truncation.\nReaching a boundary is a warning, not an automatic exclusion.");
    }
    duplicateIDs = findDuplicates(k, x, y, w, h, f, l);
    if (duplicateIDs != "") {
        Dialog.create("Possible duplicate: " + label);
        Dialog.addMessage("XY bounding boxes AND z-ranges overlap with:\n" + duplicateIDs + "\n\nThis is a conservative warning, not proof of duplication.\nCancel to revisit existing records. If distinct, confirm below.\nIf an existing record is a duplicate, edit it to excluded, reason duplicate of ID.");
        Dialog.addCheckbox("I checked these IDs; this is a distinct nucleus (or an explicitly excluded duplicate)", false);
        Dialog.show();
        if (!Dialog.getCheckbox()) return;
    }
    // Re-select the intended entry before updating, then restore the reviewed outline.
    // Clicking a different ROI Manager entry during z review cannot redirect an edit.
    if (k >= 0) roiManager("select", k);
    setSlice(r);
    if (kind == 0) makeRectangle(x,y,w,h);
    else if (kind == 1) makeOval(x,y,w,h);
    else makeSelection(kind,outlineX,outlineY);
    if (k < 0) {
        k = n;
        ids = Array.concat(ids, newArray(label));
        firstZ = Array.concat(firstZ, f); refZ = Array.concat(refZ, r); lastZ = Array.concat(lastZ, l);
        patterns = Array.concat(patterns, newArray(p)); eligibility = Array.concat(eligibility, newArray(e));
        reasons = Array.concat(reasons, newArray(reason)); displayNotes = Array.concat(displayNotes, newArray(note));
        displayMin = Array.concat(displayMin, lo); displayMax = Array.concat(displayMax, hi);
        bx = Array.concat(bx, x); by = Array.concat(by, y);
        bw = Array.concat(bw, w); bh = Array.concat(bh, h);
        Roi.setPosition(0);
        roiManager("add");
        roiManager("select", n);
        roiManager("rename", label);
        n++;
    } else {
        // update applies the current selection to the selected ROI Manager entry.
        Roi.setPosition(0);
        roiManager("update");
        firstZ[k] = f; refZ[k] = r; lastZ[k] = l;
        patterns[k] = p; eligibility[k] = e; reasons[k] = reason; displayNotes[k] = note;
        displayMin[k] = lo; displayMax[k] = hi;
        bx[k] = x; by[k] = y; bw[k] = w; bh[k] = h;
    }
    roiManager("select", k);
    RoiManager.setPosition(0);
    roiManager("deselect");
    roiManager("show all with labels");
    saveCheckpoint();
}

function validZ(f, r, l, depth) {
    return (!isNaN(f) && !isNaN(r) && !isNaN(l) && f == floor(f) && r == floor(r) && l == floor(l) && f >= 1 && f <= r && r <= l && l <= depth);
}

function nextID(count) {
    s = "" + (count+1);
    while (lengthOf(s) < 3) s = "0" + s;
    return "F01_N" + s;
}

function cleanText(s) {
    s = replace(s, "\t", " "); s = replace(s, "\r", " "); s = replace(s, "\n", " ");
    return trim(s);
}

function indexOfID(label) {
    for (j = 0; j < n; j++) if (ids[j] == label) return j;
    return -1;
}

function boxesOverlap(x, y, w, h, xx, yy, ww, hh) {
    return (x < xx+ww && xx < x+w && y < yy+hh && yy < y+h);
}

function findDuplicates(skip, x, y, w, h, f, l) {
    duplicateIDs = "";
    for (j = 0; j < n; j++) {
        if (j != skip && boxesOverlap(x, y, w, h, bx[j], by[j], bw[j], bh[j]) && f <= lastZ[j] && firstZ[j] <= l)
            duplicateIDs = duplicateIDs + ids[j] + " [z " + firstZ[j] + "-" + lastZ[j] + "] ";
    }
    return duplicateIDs;
}

function metadataText() {
    // Fixed positional format; precision sufficient for calibration round trip.
    return schema+"\n"+sourcePath+"\n"+File.length(sourcePath)+"\n"+expectedSeries+"\n"+
        width0+"\n"+height0+"\n"+depth0+"\n"+unit0+"\n"+
        d2s(pixelWidth0, 12)+"\n"+d2s(pixelHeight0, 12)+"\n"+d2s(pixelDepth0, 12)+"\n"+
        fieldStatus+"\n"+n+"\n"+"rubric_examples_notes_v1"+"\n";
}

function tableText() {
    s = "nucleus_id\tfirst_z\treference_z\tlast_z\tpattern_or_status\teligibility\treason\tdisplay_note\tdisplay_min\tdisplay_max\tx_px\ty_px\twidth_px\theight_px\tfield_status\n";
    for (j = 0; j < n; j++) {
        // A single space preserves empty text cells when split() reads the TSV.
        reason = reasons[j]; if (reason == "") reason = " ";
        note = displayNotes[j]; if (note == "") note = " ";
        s += ids[j]+"\t"+firstZ[j]+"\t"+refZ[j]+"\t"+lastZ[j]+"\t"+patterns[j]+"\t"+eligibility[j]+"\t"+
            reason+"\t"+note+"\t"+displayMin[j]+"\t"+displayMax[j]+"\t"+bx[j]+"\t"+by[j]+"\t"+bw[j]+"\t"+bh[j]+"\t"+fieldStatus+"\n";
    }
    return s;
}

function summaryText() {
    d = 0; p = 0; u = 0; excluded = 0;
    for (j = 0; j < n; j++) {
        if (eligibility[j] == "excluded") excluded++;
        else if (patterns[j] == "diffuse/non-punctate") d++;
        else if (patterns[j] == "punctate") p++;
        else u++;
    }
    denom = d+p+u;
    s = "field_status\tsource_series\trecorded_candidates\texcluded\teligible_identifiable_GFP_positive\tdiffuse_count\tpunctate_count\tuncertain_count\tdiffuse_percent\tpunctate_percent\tuncertain_percent\tpunctate_percent_confident_only\n";
    return s+fieldStatus+"\t"+expectedSeries+"\t"+n+"\t"+excluded+"\t"+denom+"\t"+d+"\t"+p+"\t"+u+"\t"+percent(d,denom)+"\t"+percent(p,denom)+"\t"+percent(u,denom)+"\t"+percent(p,d+p)+"\n";
}

function percent(a, b) {
    if (b == 0) return "NA";
    return d2s(100*a/b, 3);
}

function saveCheckpoint() {
    checkRois();
    checkpoint++;
    folder = sessionDir + "checkpoint_" + d2s(checkpoint, 0) + "/";
    while (File.exists(folder)) {
        checkpoint++;
        folder = sessionDir + "checkpoint_" + d2s(checkpoint, 0) + "/";
    }
    File.makeDirectory(folder);
    if (n > 0) {
        roiManager("deselect");
        roiManager("save", folder+"locators.zip");
        if (!File.exists(folder+"locators.zip")) exit("ROI save failed. Previous checkpoint remains available.");
    }
    File.saveString(tableText(), folder+"annotations_INCOMPLETE.tsv");
    File.saveString(summaryText(), folder+"counts_INCOMPLETE.tsv");
    File.saveString(metadataText(), folder+"session.txt");
    if (!File.exists(folder+"annotations_INCOMPLETE.tsv") || !File.exists(folder+"counts_INCOMPLETE.tsv") || !File.exists(folder+"session.txt"))
        exit("Checkpoint save failed. Resume an earlier checkpoint.");
    File.saveString("Checkpoint fully written.\n", folder+"READY.txt");
    // Pointer updated last. Older checkpoint directories are never overwritten.
    File.saveString("checkpoint_"+d2s(checkpoint,0), sessionDir+"latest.txt");
    print("PCNA pilot: saved checkpoint " + checkpoint + ", " + n + " records, INCOMPLETE_PILOT");
}

function loadSession() {
    if (!File.exists(sessionDir+"latest.txt")) exit("No latest.txt in this session folder.");
    name = trim(File.openAsString(sessionDir+"latest.txt"));
    if (!startsWith(name, "checkpoint_") || indexOf(name, "/") >= 0 || indexOf(name, "\\") >= 0 || indexOf(name, "..") >= 0)
        exit("Invalid checkpoint pointer.");
    folder = sessionDir+name+"/";
    if (!File.exists(folder+"READY.txt")) exit("Checkpoint is incomplete. See recovery instructions in the guide.");
    m = split(File.openAsString(folder+"session.txt"), "\n");
    if (m.length != 14 || m[0] != schema || m[3] != expectedSeries || m[11] != fieldStatus)
        exit("Unsupported or damaged session metadata.");
    if (m[1] != sourcePath || parseFloat(m[2]) != File.length(sourcePath))
        exit("Source path or file size differs. Use the same original LIF location as the saved session.");
    if (parseFloat(m[4]) != width0 || parseFloat(m[5]) != height0 || parseFloat(m[6]) != depth0 || m[7] != unit0 ||
        abs(parseFloat(m[8])-pixelWidth0) > 1e-9 || abs(parseFloat(m[9])-pixelHeight0) > 1e-9 || abs(parseFloat(m[10])-pixelDepth0) > 1e-9)
        exit("Source dimensions/calibration do not match the session.");
    parseTable(File.openAsString(folder+"annotations_INCOMPLETE.tsv"));
    if (n != parseFloat(m[12])) exit("Table length differs from session metadata.");
    if (n > 0) {
        if (!File.exists(folder+"locators.zip")) exit("Missing ROI ZIP.");
        roiManager("open", folder+"locators.zip");
    }
    checkRois();
    // Check table/ROI pairing before displaying the saved locators.
    for (j = 0; j < n; j++) {
        roiManager("select", j);
        getSelectionBounds(x,y,w,h);
        if (x != bx[j] || y != by[j] || w != bw[j] || h != bh[j]) exit("ROI/table geometry mismatch. Restore a previous checkpoint.");
    }
    checkpoint = parseInt(substring(name, 11));
    roiManager("deselect");
    if (n > 0) roiManager("show all with labels");
}

function parseTable(text) {
    rows = split(text, "\n");
    if (rows.length == 0 || !startsWith(rows[0], "nucleus_id\tfirst_z\t")) exit("Invalid annotation table header.");
    n = rows.length-1;
    if (n > 15) exit("This pilot supports at most 15 records.");
    ids = newArray(n); firstZ = newArray(n); refZ = newArray(n); lastZ = newArray(n);
    patterns = newArray(n); eligibility = newArray(n); reasons = newArray(n); displayNotes = newArray(n);
    displayMin = newArray(n); displayMax = newArray(n);
    bx = newArray(n); by = newArray(n); bw = newArray(n); bh = newArray(n);
    for (j = 0; j < n; j++) {
        a = split(rows[j+1], "\t");
        expectedID = nextID(j);
        if (a.length != 15 || a[0] != expectedID || a[14] != fieldStatus) exit("Invalid annotation row " + (j+1));
        ids[j] = a[0]; firstZ[j] = parseFloat(a[1]); refZ[j] = parseFloat(a[2]); lastZ[j] = parseFloat(a[3]);
        patterns[j] = a[4]; eligibility[j] = a[5]; reasons[j] = trim(a[6]); displayNotes[j] = trim(a[7]);
        displayMin[j] = parseFloat(a[8]); displayMax[j] = parseFloat(a[9]);
        bx[j] = parseFloat(a[10]); by[j] = parseFloat(a[11]); bw[j] = parseFloat(a[12]); bh[j] = parseFloat(a[13]);
        if (!validZ(firstZ[j],refZ[j],lastZ[j],depth0)) exit("Invalid saved z-range.");
        if (patterns[j] != "diffuse/non-punctate" && patterns[j] != "punctate" && patterns[j] != "uncertain") exit("Invalid saved pattern.");
        if (eligibility[j] != "eligible" && eligibility[j] != "excluded") exit("Invalid saved eligibility.");
        if ((patterns[j] == "uncertain" || eligibility[j] == "excluded") && reasons[j] == "") exit("Missing saved reason.");
        if (isNaN(displayMin[j]) || isNaN(displayMax[j]) || isNaN(bx[j]) || isNaN(by[j]) || isNaN(bw[j]) || isNaN(bh[j]) || bw[j] <= 0 || bh[j] <= 0)
            exit("Invalid saved locator/display values.");
    }
}
