// Small, headless Fiji baseline. Writes ONLY to the supplied new trial directory.
import ij.*;
import ij.io.*;
import ij.gui.Roi;
import ij.measure.Calibration;
import ij.plugin.GaussianBlur3D;
import ij.process.*;
import loci.formats.*;
import loci.formats.meta.IMetadata;
import Utilities.Counter3D;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
import java.io.*;

class A01Proposals {
    static final int W=1024,H=1024,Z=46;
    static final double XY=.180375171, DZ=.356197778, SIGMA_UM=.5, THRESHOLD=.8, MIN_UM3=1.0;
    static final String SERIES="protoplasts 2h post irradiation image 1";
    static class ObjectInfo {
        int count,minX=99999,minY=99999,minZ=99999,maxX=-1,maxY=-1,maxZ=-1;
        long sx,sy,sz;
        boolean core, trueEdge, contextEdge,zEdge;
        int[] sections=new int[Z],lx=new int[Z],ly=new int[Z],rx=new int[Z],ry=new int[Z];
        ObjectInfo(){Arrays.fill(lx,99999);Arrays.fill(ly,99999);Arrays.fill(rx,-1);Arrays.fill(ry,-1);}
        void add(int x,int y,int z){
            count++;sx+=x;sy+=y;sz+=z+1;
            minX=Math.min(minX,x);minY=Math.min(minY,y);minZ=Math.min(minZ,z);
            maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);maxZ=Math.max(maxZ,z);
            sections[z]++;lx[z]=Math.min(lx[z],x);ly[z]=Math.min(ly[z],y);rx[z]=Math.max(rx[z],x);ry[z]=Math.max(ry[z],y);
            core|=x<256&&y<256;trueEdge|=x==0||y==0||x==1023||y==1023;contextEdge|=(W<1024&&x==W-1)||(H<1024&&y==H-1);zEdge|=z==0||z==Z-1;
        }
        int reference(){int best=0;for(int z=1;z<Z;z++)if(sections[z]>sections[best])best=z;return best;}
    }
    static int[] label(ImagePlus mask,int min){
        // 26-neighbor connectivity; retain edge objects; no redirected measurements.
        // Counter3D 2.0.1 can overrun its ID-count array when the final voxel starts
        // a new component. A trailing zero plane closes label allocation safely.
        // Padding is for labelling only, and is removed before geometry/export.
        ImageStack padded=new ImageStack(mask.getWidth(),mask.getHeight());
        for(int z=1;z<=mask.getNSlices();z++)padded.addSlice(mask.getStack().getProcessor(z));
        padded.addSlice(new ByteProcessor(mask.getWidth(),mask.getHeight()));
        ImagePlus working=new ImagePlus("temporary labeller padding",padded);working.setCalibration(mask.getCalibration().copy());
        boolean show=Prefs.get("3D-OC-Options_showMaskedImg.boolean",true);
        boolean close=Prefs.get("3D-OC-Options_closeImg.boolean",false);
        Prefs.set("3D-OC-Options_showMaskedImg.boolean",false);
        Prefs.set("3D-OC-Options_closeImg.boolean",false);
        Counter3D counter;
        try {counter=new Counter3D(working,128,min,mask.getWidth()*mask.getHeight()*mask.getNSlices(),false,false);}
        finally {Prefs.set("3D-OC-Options_showMaskedImg.boolean",show);Prefs.set("3D-OC-Options_closeImg.boolean",close);}
        try {
            // Avoid constructing a per-voxel Object3D coordinate list: only labels
            // are required. This uses the pinned plugin's labelling/filtering stage.
            var method=Counter3D.class.getDeclaredMethod("findObjects");method.setAccessible(true);method.invoke(counter);
            var field=Counter3D.class.getDeclaredField("objID");field.setAccessible(true);
            return Arrays.copyOf((int[])field.get(counter),mask.getWidth()*mask.getHeight()*mask.getNSlices());
        } catch(ReflectiveOperationException e){throw new IllegalStateException("Pinned Counter3D API differs",e);}
    }
    static void save(ImagePlus im,Path file){
        if(!new FileSaver(im).saveAsTiffStack(file.toString()))throw new IllegalStateException("Cannot save "+file);
    }
    static void selfTest() throws Exception {
        ImageStack stack=new ImageStack(5,5);
        for(int z=0;z<5;z++)stack.addSlice(new ByteProcessor(5,5));
        stack.getProcessor(1).set(0,0,255);stack.getProcessor(2).set(1,1,255);stack.getProcessor(5).set(4,4,255);
        ImagePlus mask=new ImagePlus("synthetic",stack);
        int[] map=label(mask,1);
        Set<Integer> ids=new HashSet<>();for(int v:map)if(v>0)ids.add(v);
        if(ids.size()!=2||map[0]==0||map[0]!=map[31]||map[124]==map[0])throw new AssertionError("26-connectivity / z-linking / edge retention");
        int[] filtered=label(mask,2);ids.clear();for(int v:filtered)if(v>0)ids.add(v);
        if(ids.size()!=1||filtered[124]!=0)throw new AssertionError("volume filtering");
        ObjectInfo info=new ObjectInfo();info.add(10,20,3);info.add(11,20,3);info.add(10,20,4);
        if(info.reference()!=3||info.minZ!=3||info.maxZ!=4||info.count!=3)throw new AssertionError("reference/range");
        Roi roi=new Roi(10,20,2,1);roi.setName("A01_P001");roi.setPosition(0);
        Roi decoded=RoiDecoder.openFromByteArray(RoiEncoder.saveAsByteArray(roi));
        if(!decoded.getBounds().equals(roi.getBounds())||!decoded.getName().equals(roi.getName())||decoded.getPosition()!=0)throw new AssertionError("ROI codec");
        System.out.println("PASS: real Counter3D 26-connectivity, z linking, retained edges, minimum volume, geometric reference, z extent and ROI codec");
    }
    public static void main(String[] args) throws Exception {
        Locale.setDefault(Locale.ROOT);
        if(args.length==1&&args[0].equals("--selftest")){selfTest();System.exit(0);}
        Path lif=Path.of(args[0]),out=Path.of(args[1]);
        if(Files.exists(out.resolve("proposals_raw.tsv")))throw new IllegalStateException("Refusing to overwrite proposals");
        loci.common.DebugTools.setRootLevel("WARN");
        ImageStack rawStack=new ImageStack(W,H);
        try(loci.formats.ImageReader reader=new loci.formats.ImageReader()){
            IMetadata metadata=MetadataTools.createOMEXMLMetadata();reader.setMetadataStore(metadata);reader.setId(lif.toString());reader.setSeries(2);
            if(!SERIES.equals(metadata.getImageName(2))||reader.getSizeX()!=1024||reader.getSizeY()!=1024||reader.getSizeZ()!=Z||reader.getSizeC()!=1||reader.getSizeT()!=1||reader.getPixelType()!=FormatTools.UINT8||reader.isRGB())throw new IllegalStateException("Wrong source series/dimensions/type");
            for(int z=0;z<Z;z++)rawStack.addSlice(new ByteProcessor(W,H,reader.openBytes(reader.getIndex(z,0,0),0,0,W,H)));
        }
        Calibration cal=new Calibration();cal.setUnit("micron");cal.pixelWidth=XY;cal.pixelHeight=XY;cal.pixelDepth=DZ;
        ImagePlus raw=new ImagePlus("A01 plus context RAW DERIVED COPY",rawStack);raw.setCalibration(cal);
        save(raw,out.resolve("derived_raw_context.tif"));
        ImageStack floats=new ImageStack(W,H);
        for(int z=1;z<=Z;z++)floats.addSlice(rawStack.getProcessor(z).convertToFloat());
        ImagePlus smooth=new ImagePlus("Gaussian derived copy",floats);smooth.setCalibration(cal.copy());
        GaussianBlur3D.blur(smooth,SIGMA_UM/XY,SIGMA_UM/XY,SIGMA_UM/DZ);
        save(smooth,out.resolve("derived_smoothed_context.tif"));
        ImageStack binary=new ImageStack(W,H);
        for(int z=1;z<=Z;z++){
            float[] values=(float[])smooth.getStack().getPixels(z);byte[] pixels=new byte[W*H];
            for(int i=0;i<pixels.length;i++)if(values[i]>=THRESHOLD)pixels[i]=(byte)255;
            binary.addSlice(new ByteProcessor(W,H,pixels));
        }
        ImagePlus mask=new ImagePlus("Threshold mask",binary);mask.setCalibration(cal.copy());save(mask,out.resolve("derived_foreground_mask.tif"));
        int minimum=(int)Math.ceil(MIN_UM3/(XY*XY*DZ));
        int[] labels=label(mask,minimum);
        TreeMap<Integer,ObjectInfo> objects=new TreeMap<>();
        for(int i=0;i<labels.length;i++)if(labels[i]>0){int z=i/(W*H),y=(i/W)%H,x=i%W;objects.computeIfAbsent(labels[i],k->new ObjectInfo()).add(x,y,z);}
        ImageStack labelStack=new ImageStack(W,H);
        for(int z=0;z<Z;z++){float[] pix=new float[W*H];for(int i=0;i<pix.length;i++)pix[i]=labels[z*W*H+i];labelStack.addSlice(new FloatProcessor(W,H,pix));}
        ImagePlus labelImage=new ImagePlus("Raw component labels",labelStack);labelImage.setCalibration(cal.copy());save(labelImage,out.resolve("derived_component_labels.tif"));
        StringBuilder table=new StringBuilder("proposal_id\tcomponent_label\tx_px\ty_px\twidth_px\theight_px\tfirst_z\treference_z\tlast_z\tvoxel_count\tvolume_um3\tcentroid_x_px\tcentroid_y_px\tcentroid_z_slice\tintersects_A01\tcenter_in_A01\ttrue_xy_edge\tartificial_context_edge\tz_edge\tvolume_x_min\tvolume_y_min\tvolume_x_max\tvolume_y_max\n");
        int sequence=0,contextWarnings=0,coreCount=0;
        try(ZipOutputStream zip=new ZipOutputStream(Files.newOutputStream(out.resolve("proposal_locators.zip")))){
            for(var entry:objects.entrySet()){
                ObjectInfo v=entry.getValue();int z=v.reference();String id=String.format("A01_P%03d",++sequence);
                int x=v.lx[z],y=v.ly[z],w=v.rx[z]-x+1,h=v.ry[z]-y+1;
                boolean center=x+w/2.0<256&&y+h/2.0<256;
                if(v.core)coreCount++;if(v.core&&v.contextEdge)contextWarnings++;
                table.append(String.format("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.9f\t%.6f\t%.6f\t%.6f\t%b\t%b\t%b\t%b\t%b\t%d\t%d\t%d\t%d%n",id,entry.getKey(),x,y,w,h,v.minZ+1,z+1,v.maxZ+1,v.count,v.count*XY*XY*DZ,(double)v.sx/v.count,(double)v.sy/v.count,(double)v.sz/v.count,v.core,center,v.trueEdge,v.contextEdge,v.zEdge,v.minX,v.minY,v.maxX,v.maxY));
                Roi roi=new Roi(x,y,w,h);roi.setName(id);roi.setPosition(0);
                byte[] encoded=RoiEncoder.saveAsByteArray(roi);Roi decoded=RoiDecoder.openFromByteArray(encoded);
                if(!decoded.getName().equals(id)||!decoded.getBounds().equals(roi.getBounds()))throw new AssertionError("ROI round trip");
                zip.putNextEntry(new ZipEntry(id+".roi"));zip.write(encoded);zip.closeEntry();
            }
        }
        Files.writeString(out.resolve("proposals_raw.tsv"),table.toString());
        Files.writeString(out.resolve("generation_summary.tsv"),"candidate_count\tcomponents_intersecting_A01\tcore_components_touching_artificial_edge\tminimum_voxels\n"+sequence+"\t"+coreCount+"\t"+contextWarnings+"\t"+minimum+"\n");
        System.out.println("Generated "+sequence+" raw proposals; "+coreCount+" intersect A01; context-edge warnings="+contextWarnings+"; min voxels="+minimum);
        System.exit(0);
    }
}
