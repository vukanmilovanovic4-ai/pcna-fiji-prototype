// PCNA1-GFP manual field-1 survey, Fiji / ImageJ 1.54p.
// No pixel-changing commands. One locator ROI and table row per nucleus.
// Separate copied session only. Grid is a navigation overlay, never pixel data.
var expectedSeries = "protoplasts 2h post irradiation image 1";
var schema = "PCNA_FIELD1_SURVEY_V1";
var fieldStatus = "IN_PROGRESS";
var coverage = newArray(16), currentArea = 0;
var completedAt = "NA", reviewer = "", finalNote = "";
var gridVersion = "PCNA_GRID4X4_V1";
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
    Dialog.create("PCNA field 1 manual survey");
    Dialog.addMessage("Resume ONLY the separate results_field1_full copy.\nOriginal pilot and disposable duplicate-test folders are not survey sessions.\nFirst trial: check inherited IDs, review ONE grid area, save and stop.");
    Dialog.addCheckbox("I confirm the original LIF and exact field-1 series", false);
    Dialog.show();
    if (!Dialog.getCheckbox()) exit("Source/series confirmation required.");
    sessionDir = replace(getDirectory("Choose results_field1_full (copied survey session)"), "\\", "/");
    requireSurveyFolder();
    loadSession();
    // Importing the pilot creates a new checkpoint only in the copied session.
    if (fieldStatus == "INCOMPLETE_PILOT") {
        initializeSurvey();
        saveCheckpoint();
        showMessage("Pilot records inherited", "All existing IDs and ROIs retained. Next new ID: " + nextRecordID() + "\nAll 16 areas start unreviewed. Nothing has been counted again.");
    }
    while (true) {
        checkImage(); checkRois();
        refreshOverlay();
        Dialog.createNonBlocking("Field 1: " + n + " records | " + fieldStatus);
        Dialog.addMessage("Current area: " + areaName(currentArea) + " [" + areaBoundsText(currentArea) + "]\n" + reviewedCount() + "/16 areas reviewed through all 46 slices.\n" + coverageList() + "\nGreen=eligible; gray=excluded; cyan=grid; yellow=current area.\nUse existing IDs for inherited nuclei. Grid borders are not exclusions.");
        Dialog.addChoice("Action", newArray("Choose / review grid area", "Add nucleus", "Review / edit existing ID", "Mark current area reviewed", "Reopen current area", "Save checkpoint / export", "Finish field", "Save and stop"));
        Dialog.show();
        action = Dialog.getChoice();
        checkImage(); checkRois();
        if (action == "Choose / review grid area") chooseArea();
        else if (action == "Add nucleus") annotate(-1);
        else if (action == "Review / edit existing ID") {
            if (n == 0) showMessage("No records", "Add a nucleus first.");
            else {
                Dialog.create("Choose stable ID");
                Dialog.addChoice("Nucleus", ids);
                Dialog.show();
                chosen = Dialog.getChoice();
                annotate(indexOfID(chosen));
            }
        } else if (action == "Mark current area reviewed") markCurrentArea();
        else if (action == "Reopen current area") {
            invalidateArea(currentArea); saveCheckpoint();
        } else if (action == "Save checkpoint / export") {
            saveCheckpoint(); showMessage("Saved", "Checkpoint " + checkpoint + " | " + fieldStatus);
        } else if (action == "Finish field") finishField();
        else {
            saveCheckpoint();
            showMessage("Saved", "Checkpoint " + checkpoint + " | " + fieldStatus + "\n" + reviewedCount() + "/16 areas reviewed.\nFor the first-area trial, stop here and report before surveying the rest.");
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
        label = nextRecordID();
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
    oldArea = -1;
    if (k >= 0) oldArea = ownerArea(bx[k],by[k],bw[k],bh[k]);
    newArea = ownerArea(x,y,w,h);
    if (newArea < 0) {
        showMessage("Locator center outside field", "Draw the locator around the visible nuclear region so its center is inside the field. No changes saved.");
        return;
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
    recordChanged(oldArea,newArea);
    refreshOverlay();
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
    s = "nucleus_id\tfirst_z\treference_z\tlast_z\tpattern_or_status\teligibility\treason\tdisplay_note\tdisplay_min\tdisplay_max\tx_px\ty_px\twidth_px\theight_px\tfield_status\towner_area\n";
    for (j = 0; j < n; j++) {
        // A single space preserves empty text cells when split() reads the TSV.
        reason = reasons[j]; if (reason == "") reason = " ";
        note = displayNotes[j]; if (note == "") note = " ";
        s += ids[j]+"\t"+firstZ[j]+"\t"+refZ[j]+"\t"+lastZ[j]+"\t"+patterns[j]+"\t"+eligibility[j]+"\t"+
            reason+"\t"+note+"\t"+displayMin[j]+"\t"+displayMax[j]+"\t"+bx[j]+"\t"+by[j]+"\t"+bw[j]+"\t"+bh[j]+"\t"+fieldStatus+"\t"+areaName(ownerArea(bx[j],by[j],bw[j],bh[j]))+"\n";
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
    requireSurveyFolder();
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
    tag = exportTag();
    writeSurveyFiles(folder);
    File.saveString(tableText(), folder+"annotations_"+tag+".tsv");
    File.saveString(summaryText(), folder+"counts_"+tag+".tsv");
    File.saveString(metadataText(), folder+"session.txt");
    if (!File.exists(folder+"annotations_"+tag+".tsv") || !File.exists(folder+"counts_"+tag+".tsv") || !File.exists(folder+"session.txt"))
        exit("Checkpoint save failed. Resume an earlier checkpoint.");
    File.saveString("Checkpoint fully written.\n", folder+"READY.txt");
    // Pointer updated last. Older checkpoint directories are never overwritten.
    File.saveString("checkpoint_"+d2s(checkpoint,0), sessionDir+"latest.txt");
    print("PCNA field 1: checkpoint " + checkpoint + ", " + n + " records, " + fieldStatus + ", " + reviewedCount() + "/16 areas reviewed");
}

function loadSession() {
    folder = loadSessionData();
    if (n > 0) roiManager("open", folder+"locators.zip");
    checkRois();
    // GUI stage: select the restored locators and verify their table pairing.
    for (j = 0; j < n; j++) {
        roiManager("select", j);
        getSelectionBounds(x,y,w,h);
        if (x != bx[j] || y != by[j] || w != bw[j] || h != bh[j]) exit("ROI/table geometry mismatch. Restore a previous checkpoint.");
    }
    roiManager("deselect");
}

// The same startup data path is exercised headlessly; ROI Manager stays in loadSession.
// This function reads existing files only. It does not initialize or save a session.
function loadSessionData() {
    requireSurveyFolder();
    if (!File.exists(sessionDir+"latest.txt")) exit("No latest.txt in this session folder.");
    name = trim(File.openAsString(sessionDir+"latest.txt"));
    if (!startsWith(name, "checkpoint_") || indexOf(name, "/") >= 0 || indexOf(name, "\\") >= 0 || indexOf(name, "..") >= 0)
        exit("Invalid checkpoint pointer.");
    folder = sessionDir+name+"/";
    if (!File.exists(folder+"READY.txt")) exit("Checkpoint is incomplete. See recovery instructions in the guide.");
    m = split(File.openAsString(folder+"session.txt"), "\n");
    if (m.length != 14 || (m[0] != schema && m[0] != "PCNA_FIELD1_PILOT_V1") || m[3] != expectedSeries || !validStatus(m[11]))
        exit("Unsupported or damaged session metadata.");
    if (m[1] != sourcePath || parseFloat(m[2]) != File.length(sourcePath))
        exit("Source path or file size differs. Use the same original LIF location as the saved session.");
    if (parseFloat(m[4]) != width0 || parseFloat(m[5]) != height0 || parseFloat(m[6]) != depth0 || m[7] != unit0 ||
        abs(parseFloat(m[8])-pixelWidth0) > 1e-9 || abs(parseFloat(m[9])-pixelHeight0) > 1e-9 || abs(parseFloat(m[10])-pixelDepth0) > 1e-9)
        exit("Source dimensions/calibration do not match the session.");
    fieldStatus = m[11];
    if (m[0] == "PCNA_FIELD1_PILOT_V1" && fieldStatus != "INCOMPLETE_PILOT") exit("Invalid pilot status.");
    if (m[0] == schema && fieldStatus == "INCOMPLETE_PILOT") exit("Invalid survey status.");
    tag = exportTag();
    parseTable(File.openAsString(folder+"annotations_"+tag+".tsv"));
    if (m[0] == schema) readSurveyFiles(folder);
    if (n != parseFloat(m[12])) exit("Table length differs from session metadata.");
    if (n > 0 && !File.exists(folder+"locators.zip")) exit("Missing ROI ZIP.");
    checkpoint = parseInt(substring(name, 11));
    return folder;
}

function parseTable(text) {
    rows = split(text, "\n");
    if (rows.length == 0 || !startsWith(rows[0], "nucleus_id\tfirst_z\t")) exit("Invalid annotation table header.");
    n = rows.length-1;

    ids = newArray(n); firstZ = newArray(n); refZ = newArray(n); lastZ = newArray(n);
    patterns = newArray(n); eligibility = newArray(n); reasons = newArray(n); displayNotes = newArray(n);
    displayMin = newArray(n); displayMax = newArray(n);
    bx = newArray(n); by = newArray(n); bw = newArray(n); bh = newArray(n);
    for (j = 0; j < n; j++) {
        a = split(rows[j+1], "\t");
        expectedID = nextID(j);
        if ((a.length != 15 && a.length != 16) || a[0] != expectedID || a[14] != fieldStatus) exit("Invalid annotation row " + (j+1));
        ids[j] = a[0]; firstZ[j] = parseFloat(a[1]); refZ[j] = parseFloat(a[2]); lastZ[j] = parseFloat(a[3]);
        patterns[j] = a[4]; eligibility[j] = a[5]; reasons[j] = trim(a[6]); displayNotes[j] = trim(a[7]);
        displayMin[j] = parseFloat(a[8]); displayMax[j] = parseFloat(a[9]);
        bx[j] = parseFloat(a[10]); by[j] = parseFloat(a[11]); bw[j] = parseFloat(a[12]); bh[j] = parseFloat(a[13]);
        owned = ownerArea(bx[j],by[j],bw[j],bh[j]);
        if (owned < 0) exit("Saved locator center outside field.");
        if (a.length == 16) {
            savedArea = areaName(owned);
            if (a[15] != savedArea) exit("Saved owner area disagrees with locator center.");
        }
        if (!validZ(firstZ[j],refZ[j],lastZ[j],depth0)) exit("Invalid saved z-range.");
        if (patterns[j] != "diffuse/non-punctate" && patterns[j] != "punctate" && patterns[j] != "uncertain") exit("Invalid saved pattern.");
        if (eligibility[j] != "eligible" && eligibility[j] != "excluded") exit("Invalid saved eligibility.");
        if ((patterns[j] == "uncertain" || eligibility[j] == "excluded") && reasons[j] == "") exit("Missing saved reason.");
        if (isNaN(displayMin[j]) || isNaN(displayMax[j]) || isNaN(bx[j]) || isNaN(by[j]) || isNaN(bw[j]) || isNaN(bh[j]) || bw[j] <= 0 || bh[j] <= 0)
            exit("Invalid saved locator/display values.");
    }
}


function requireSurveyFolder() {
    marker = sessionDir+"FIELD1_FULL_SESSION.txt";
    if (!File.exists(marker)) exit("This is not a prepared full-field copy. Choose results_field1_full. Original pilot and duplicate-test sessions cannot be used.");
    if (!startsWith(File.openAsString(marker), "PCNA_FIELD1_FULL_COPY_V1\n")) exit("Invalid full-field session marker.");
}

function validStatus(status) {
    // Avoid a parenthesized return expression beginning with a string variable.
    if (status == "INCOMPLETE_PILOT") return true;
    if (status == "IN_PROGRESS") return true;
    if (status == "COMPLETE") return true;
    return false;
}

function exportTag() {
    if (fieldStatus == "COMPLETE") return "COMPLETE";
    return "INCOMPLETE";
}

function initializeSurvey() {
    coverage = newArray(16); currentArea = 0;
    fieldStatus = "IN_PROGRESS"; completedAt = "NA"; reviewer = ""; finalNote = "";
}

function areaName(area) {
    v = ""+(area+1);
    if (lengthOf(v)<2) v="0"+v;
    return "A"+v;
}

function areaBoundsText(area) {
    xx=(area%4)*256; yy=floor(area/4)*256;
    return "x="+xx+".."+(xx+255)+", y="+yy+".."+(yy+255);
}

function ownerArea(x,y,w,h) {
    cx=x+w/2; cy=y+h/2;
    if (cx<0 || cy<0 || cx>=1024 || cy>=1024) return -1;
    return (floor(cy/256)*4+floor(cx/256));
}

function nextRecordID() {
    highest=0;
    for (ii=0; ii<n; ii++) highest=maxOf(highest,parseInt(substring(ids[ii],5)));
    label=nextID(highest);
    return label;
}

function reviewedCount() {
    total=0;
    for (ii=0; ii<16; ii++) total+=coverage[ii];
    return total;
}

function coverageList() {
    text="";
    for (ii=0; ii<16; ii++) {
        state="[ ]"; if (coverage[ii]==1) state="[x]";
        text+=""+areaName(ii)+state+" ";
        if (ii%4==3) text+="\n";
    }
    return text;
}

function ownedIDs(area) {
    text="";
    for (ii=0; ii<n; ii++) {
        if (ownerArea(bx[ii],by[ii],bw[ii],bh[ii])==area) text+=ids[ii]+" ("+eligibility[ii]+") ";
    }
    if (text=="") text="No recorded locator centers in this area yet.";
    return text;
}

function chooseArea() {
    choices=newArray(16);
    for (ii=0;ii<16;ii++) {
        state="unreviewed"; if (coverage[ii]==1) state="reviewed";
        name=areaName(ii);
        choices[ii]=name+" - "+state;
    }
    Dialog.create("Choose grid area");
    Dialog.addChoice("Area",choices,choices[currentArea]);
    Dialog.show();
    chosen=Dialog.getChoice();
    currentArea=parseInt(substring(chosen,1,3))-1;
    setSlice(1);
    refreshOverlay();
    saveCheckpoint();
    bounds=areaBoundsText(currentArea);
    showMessage("Review "+areaName(currentArea),bounds+"\nInspect ALL 46 slices; zoom/pan normally, with context beyond the core.\nGrid borders never exclude nuclei. Use existing IDs, not new entries, for recognized nuclei.\nRecorded centers here: "+ownedIDs(currentArea));
}

function invalidateArea(area) {
    if (area>=0 && area<16) coverage[area]=0;
    fieldStatus="IN_PROGRESS"; completedAt="NA"; reviewer=""; finalNote="";
}

function recordChanged(oldArea,newArea) {
    if (oldArea>=0) invalidateArea(oldArea);
    invalidateArea(newArea);
}

function markCurrentArea() {
    Dialog.create("Mark "+areaName(currentArea)+" reviewed");
    bounds=areaBoundsText(currentArea);
    Dialog.addMessage(bounds+"\nRecorded centers: "+ownedIDs(currentArea)+"\nAn area can contain no nuclei. Coverage still requires full-depth inspection.\nThis is your attestation; the macro cannot verify that every nucleus was seen.");
    Dialog.addCheckbox("I inspected this entire core through all 46 slices, using neighboring context",false);
    Dialog.addCheckbox("Every identifiable candidate here is recorded once or matched to an existing ID; boundary decisions resolved",false);
    Dialog.show();
    fullDepth=Dialog.getCheckbox(); reconciled=Dialog.getCheckbox();
    if (!fullDepth || !reconciled) return;
    coverage[currentArea]=1;
    saveCheckpoint();
}

function canFinish() {
    if (fieldStatus != "IN_PROGRESS") return false;
    if (reviewedCount() != 16) return false;
    return true;
}

function finishField() {
    if (!canFinish()) {
        showMessage("Finish unavailable","All 16 areas must be reviewed and the survey must be IN_PROGRESS.\nCurrent status: "+fieldStatus+"; "+reviewedCount()+"/16 reviewed.\nDo not finish during the first-area trial.");
        return;
    }
    checkImage(); checkRois();
    Dialog.create("Final field review");
    Dialog.addMessage("COMPLETE means the field was systematically reviewed, not that every true nucleus was detectable.\nEligible uncertain nuclei remain in the primary denominator.\nReview the latest exported counts before confirming.");
    Dialog.addString("Reviewer", "", 35);
    Dialog.addString("Final review note", "", 55);
    Dialog.addCheckbox("All 16 cores were inspected through 46 slices and candidates reconciled with stable IDs",false);
    Dialog.addCheckbox("Boundary/exclusion reasons and possible duplicates are resolved; uncertain reasons retained",false);
    Dialog.addCheckbox("I checked counts, eligibility denominator and category definitions and intend to complete this field",false);
    Dialog.show();
    who=cleanText(Dialog.getString()); note=cleanText(Dialog.getString());
    cov=Dialog.getCheckbox(); boundaries=Dialog.getCheckbox(); counts=Dialog.getCheckbox();
    if (who=="" || !cov || !boundaries || !counts) {
        showMessage("Not completed","Reviewer and all final confirmations are required. Status remains IN_PROGRESS.");
        return;
    }
    completeSurvey(who,note);
    saveCheckpoint();
    showMessage("Field complete","A new COMPLETE checkpoint was saved.\nSubsequent annotation changes reopen affected areas and status becomes IN_PROGRESS.");
}

function completeSurvey(who,note) {
    cleanWho=cleanText(who);
    if (!canFinish() || cleanWho=="") exit("Completion conditions not satisfied.");
    fieldStatus="COMPLETE";
    completedAt=d2s(getTime(),0); // milliseconds since Unix epoch, timezone independent
    reviewer=cleanText(who); finalNote=cleanText(note);
}

function coverageText() {
    text="area_id\tx_start_px\ty_start_px\tx_end_exclusive_px\ty_end_exclusive_px\treviewed_all_46\tcurrent\n";
    for (ii=0;ii<16;ii++) {
        xx=(ii%4)*256; yy=floor(ii/4)*256; active=0; if (ii==currentArea) active=1;
        text+=""+areaName(ii)+"\t"+xx+"\t"+yy+"\t"+(xx+256)+"\t"+(yy+256)+"\t"+coverage[ii]+"\t"+active+"\n";
    }
    return text;
}

function surveyStateText() {
    who=reviewer; if (who=="") who=" ";
    note=finalNote; if (note=="") note=" ";
    return gridVersion+"\n"+currentArea+"\n"+completedAt+"\n"+who+"\n"+note+"\n";
}

function parseSurvey(coverageData,stateData) {
    rows=split(coverageData,"\n"); state=split(stateData,"\n");
    if (rows.length!=17 || state.length!=5 || state[0]!=gridVersion) exit("Invalid saved coverage/state.");
    currentArea=parseFloat(state[1]); completedAt=state[2]; reviewer=trim(state[3]); finalNote=trim(state[4]);
    if (isNaN(currentArea) || currentArea!=floor(currentArea) || currentArea<0 || currentArea>15) exit("Invalid current area.");
    coverage=newArray(16); activeCount=0;
    for (ii=0;ii<16;ii++) {
        a=split(rows[ii+1],"\t"); expected=areaName(ii);
        if (a.length!=7 || a[0]!=expected) exit("Invalid coverage area row.");
        xx=(ii%4)*256; yy=floor(ii/4)*256;
        if (parseFloat(a[1])!=xx || parseFloat(a[2])!=yy || parseFloat(a[3])!=xx+256 || parseFloat(a[4])!=yy+256) exit("Grid bounds changed.");
        if ((a[5]!="0" && a[5]!="1") || (a[6]!="0" && a[6]!="1")) exit("Invalid coverage flag.");
        coverage[ii]=parseFloat(a[5]);
        if (a[6]=="1") { activeCount++; if (ii!=currentArea) exit("Current area mismatch."); }
    }
    if (activeCount!=1) exit("Exactly one current area required.");
    if (fieldStatus=="COMPLETE") {
        stamp=parseFloat(completedAt);
        if (reviewedCount()!=16 || reviewer=="" || isNaN(stamp) || stamp<=0) exit("Incomplete completion record.");
    } else if (completedAt!="NA" || reviewer!="" || finalNote!="") exit("In-progress survey has stale completion metadata.");
}

function writeSurveyFiles(folder) {
    File.saveString(coverageText(),folder+"coverage.tsv");
    File.saveString(surveyStateText(),folder+"survey_state.txt");
    if (!File.exists(folder+"coverage.tsv") || !File.exists(folder+"survey_state.txt")) exit("Coverage save failed; previous checkpoint is available.");
}

function readSurveyFiles(folder) {
    if (!File.exists(folder+"coverage.tsv") || !File.exists(folder+"survey_state.txt")) exit("Missing survey coverage/state files.");
    parseSurvey(File.openAsString(folder+"coverage.tsv"),File.openAsString(folder+"survey_state.txt"));
}

function refreshOverlay() {
    // Grid is NOT stored in ROI Manager or locator ZIP; only real nuclei are counted.
    checkImage(); checkRois();
    slice=getSliceNumber();
    roiManager("show none"); Overlay.clear;
    for (ii=0;ii<n;ii++) {
        roiManager("select",ii);
        color="green"; if (eligibility[ii]=="excluded") color="gray";
        Overlay.addSelection(color,1);
        Overlay.setPosition(0);
    }
    addGridOverlay();
    Overlay.drawLabels(true); Overlay.useNamesAsLabels(true);
    Overlay.setLabelColor("white"); Overlay.setLabelFontSize(12,"back");
    Overlay.selectable(false); // avoids accidentally selecting a grid line for annotation
    roiManager("deselect"); run("Select None"); setSlice(slice); Overlay.show;
}

function addGridOverlay() {
    for (ii=0;ii<16;ii++) {
        xx=(ii%4)*256; yy=floor(ii/4)*256;
        makeRectangle(xx,yy,256,256);
        name=areaName(ii);
        setSelectionName(name);
        Overlay.addSelection("cyan",1); Overlay.setPosition(0);
    }
    xx=(currentArea%4)*256; yy=floor(currentArea/4)*256;
    makeRectangle(xx,yy,256,256);
    setSelectionName("CURRENT "+areaName(currentArea));
    Overlay.addSelection("yellow",2); Overlay.setPosition(0);
}
