// Read-only proposal viewer. No ROI Manager, research-session or pixel writes.
var proposalIDs, px, py, pw, ph, firstZ, refZ, lastZ, coreHit, count;
var manualIDs, mx, my, mw, mh, manualCount;
var selectedProposal=0, selectedManual=0, showManual=false;
var voxelCount, volumeUm3, vminX, vminY, vmaxX, vmaxY;
viewTrial(); // VIEWER ENTRY POINT

function viewTrial() {
    requires("1.54p");
    if(nImages==0) exit("Open the ORIGINAL field-1 LIF series through Bio-Formats first.");
    getDimensions(w,h,c,z,t);
    if(w!=1024 || h!=1024 || c!=1 || z!=46 || t!=1 || bitDepth!=8 || indexOf(getTitle(),"protoplasts 2h post irradiation image 1")<0)
        exit("Expected original field 1: 1024 x 1024 x 46, one channel/timepoint, 8-bit, original series title.");
    imageID=getImageID();
    dir=getDirectory("Choose trials/nucleus_proposals_A01/run_001 (not preflight)");
    if(!File.exists(dir+"manifest.json") || !File.exists(dir+"proposal_review.tsv")) exit("Not a completed proposal trial folder.");
    readProposals(File.openAsString(dir+"proposals_raw.tsv"));
    readManual(File.openAsString(dir+"manual_A01_reference.tsv"));
    if(count==0) exit("No proposals. Inspect manual reference and record misses in manual_matching.tsv.");
    while(true) {
        if(!isOpen(imageID)) exit("Original image closed. Relaunch viewer on the original stack.");
        selectImage(imageID);
        renderTrial();
        info=describeProposal(selectedProposal);
        manualInfo="OFF";
        if(showManual)manualInfo=manualIDs[selectedManual];
        Dialog.createNonBlocking("Single raw component - not a nucleus count");
        Dialog.addMessage(info+"\n\nMAGENTA thick box: selected automatic component only.\nGREEN thin box: optional manual locator ("+manualInfo+").\nLabels are in this panel, not overlapping on the image.\nFormal scoring is paused: inspect the mask diagnostic first.");
        Dialog.addChoice("Automatic proposal",proposalIDs,proposalIDs[selectedProposal]);
        Dialog.addCheckbox("Show ONE manual reference (green)",showManual);
        Dialog.addChoice("Manual reference",manualIDs,manualIDs[selectedManual]);
        Dialog.addChoice("Action",newArray("Inspect at reference z","Apply selection; keep current z","Clear overlay and stop"));
        Dialog.show();
        chosen=Dialog.getChoice();showManual=Dialog.getCheckbox();manualChosen=Dialog.getChoice();action=Dialog.getChoice();
        if(action=="Clear overlay and stop") {Overlay.remove;run("Select None");exit();}
        for(j=0;j<count;j++)if(proposalIDs[j]==chosen)selectedProposal=j;
        for(j=0;j<manualCount;j++)if(manualIDs[j]==manualChosen)selectedManual=j;
        renderTrial();
        if(action=="Inspect at reference z") {
            setSlice(refZ[selectedProposal]);
            info=describeProposal(selectedProposal);
            manualInfo="OFF";if(showManual)manualInfo=manualIDs[selectedManual];
            waitForUser("Inspect "+proposalIDs[selectedProposal],info+"\n\nOnly this automatic component is displayed.\nScroll through original sections, including beyond the proposed z-range.\nGREEN manual reference: "+manualInfo+"\nP002 is a field-spanning mask component, not one nucleus.\nDo not score this run yet; consult the mask diagnostic. Click OK to return.");
        }
    }
}

function readProposals(data) {
    lines=split(data,"\n");count=lines.length-1;
    if(!startsWith(lines[0],"proposal_id\tcomponent_label\t"))exit("Unexpected proposal table.");
    proposalIDs=newArray(count);px=newArray(count);py=newArray(count);pw=newArray(count);ph=newArray(count);
    firstZ=newArray(count);refZ=newArray(count);lastZ=newArray(count);coreHit=newArray(count);
    voxelCount=newArray(count);volumeUm3=newArray(count);vminX=newArray(count);vminY=newArray(count);vmaxX=newArray(count);vmaxY=newArray(count);
    for(j=0;j<count;j++) {
        a=split(lines[j+1],"\t");if(a.length!=23)exit("Invalid raw proposal row.");
        proposalIDs[j]=a[0];px[j]=parseFloat(a[2]);py[j]=parseFloat(a[3]);pw[j]=parseFloat(a[4]);ph[j]=parseFloat(a[5]);
        firstZ[j]=parseFloat(a[6]);refZ[j]=parseFloat(a[7]);lastZ[j]=parseFloat(a[8]);
        coreHit[j]=0;if(a[14]=="true")coreHit[j]=1;
        voxelCount[j]=parseFloat(a[9]);volumeUm3[j]=parseFloat(a[10]);
        vminX[j]=parseFloat(a[19]);vminY[j]=parseFloat(a[20]);vmaxX[j]=parseFloat(a[21]);vmaxY[j]=parseFloat(a[22]);
    }
}

function readManual(data) {
    lines=split(data,"\n");manualCount=lines.length-1;
    if(!startsWith(lines[0],"manual_id\teligibility\t"))exit("Unexpected manual reference table.");
    manualIDs=newArray(manualCount);mx=newArray(manualCount);my=newArray(manualCount);mw=newArray(manualCount);mh=newArray(manualCount);
    for(j=0;j<manualCount;j++) {
        a=split(lines[j+1],"\t");if(a.length!=9)exit("Invalid reference row.");
        manualIDs[j]=a[0];mx[j]=parseFloat(a[5]);my[j]=parseFloat(a[6]);mw[j]=parseFloat(a[7]);mh[j]=parseFloat(a[8]);
    }
}

function renderTrial() {
    buildTrialOverlay();
    run("Select None");Overlay.show;
}

function buildTrialOverlay() {
    Overlay.clear;
    k=selectedProposal;
    makeRectangle(px[k],py[k],pw[k],ph[k]);setSelectionName(proposalIDs[k]);
    Overlay.addSelection("magenta",3);Overlay.setPosition(0);
    if(showManual) {
        j=selectedManual;
        makeRectangle(mx[j],my[j],mw[j],mh[j]);setSelectionName(manualIDs[j]);
        Overlay.addSelection("green",1);Overlay.setPosition(0);
    }
    Overlay.drawLabels(false);Overlay.selectable(false);
}

function describeProposal(k) {
    scope="context only";if(coreHit[k]==1)scope="intersects A01";
    text="AUTOMATIC "+proposalIDs[k]+" | "+scope;
    text+="\nReference box: x="+px[k]+", y="+py[k]+", width="+pw[k]+", height="+ph[k]+" pixels";
    text+="\nZ: first="+firstZ[k]+", reference="+refZ[k]+", last="+lastZ[k]+" (1-based)";
    text+="\n3D extent: x="+vminX[k]+".."+vmaxX[k]+", y="+vminY[k]+".."+vmaxY[k]+", z="+firstZ[k]+".."+lastZ[k];
    text+="\nSize: "+d2s(voxelCount[k],0)+" foreground voxels; "+d2s(volumeUm3[k],3)+" um^3";
    if(pw[k]==1024 && ph[k]==1024)text+="\nWARNING: field-spanning foreground component; do not interpret as a nucleus.";
    return text;
}
