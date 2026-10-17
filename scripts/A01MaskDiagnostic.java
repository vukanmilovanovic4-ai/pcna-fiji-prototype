// Inspect existing derived artifacts only; output is outside immutable run_001.
import ij.*;
import ij.io.Opener;
import java.nio.file.*;
import java.awt.*;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.util.*;

class A01MaskDiagnostic {
    public static void main(String[] args) throws Exception {
        Path run=Path.of(args[0]),out=Path.of(args[1]);Files.createDirectories(out);
        ImagePlus raw=new Opener().openImage(run.resolve("derived_raw_context.tif").toString());
        ImagePlus smooth=new Opener().openImage(run.resolve("derived_smoothed_context.tif").toString());
        ImagePlus mask=new Opener().openImage(run.resolve("derived_foreground_mask.tif").toString());
        ImagePlus labels=new Opener().openImage(run.resolve("derived_component_labels.tif").toString());
        for(ImagePlus im:new ImagePlus[]{raw,smooth,mask,labels})if(im==null||im.getWidth()!=1024||im.getHeight()!=1024||im.getNSlices()!=46)throw new AssertionError("Unexpected derived stack");
        long foreground=0,largest=0,coreForeground=0,coreLargest=0,thresholdMismatch=0;
        StringBuilder table=new StringBuilder("z\tfield_foreground_fraction\tfield_P002_fraction\tA01_foreground_fraction\tA01_P002_fraction\n");
        for(int z=1;z<=46;z++) {
            byte[] b=(byte[])mask.getStack().getPixels(z);float[] s=(float[])smooth.getStack().getPixels(z);float[] l=(float[])labels.getStack().getPixels(z);
            long f=0,g=0,cf=0,cg=0;
            for(int i=0;i<b.length;i++) {
                boolean on=(b[i]&255)>0,isGiant=l[i]==2;
                if(on!=(s[i]>=.8))thresholdMismatch++;
                if(on)f++;if(isGiant)g++;
                if(i%1024<256&&i/1024<256){if(on)cf++;if(isGiant)cg++;}
                if(l[i]>0&&!on)throw new AssertionError("Label outside foreground mask");
            }
            foreground+=f;largest+=g;coreForeground+=cf;coreLargest+=cg;
            table.append(String.format(Locale.ROOT,"%d\t%.9f\t%.9f\t%.9f\t%.9f%n",z,f/1048576.,g/1048576.,cf/65536.,cg/65536.));
        }
        if(thresholdMismatch!=0)throw new AssertionError("Threshold mask does not match saved smoothing");
        Files.writeString(out.resolve("mask_by_slice.tsv"),table.toString());
        Files.writeString(out.resolve("mask_totals.tsv"),"field_voxels\tforeground_voxels\tP002_voxels\tA01_voxels\tA01_foreground_voxels\tA01_P002_voxels\tthreshold_mismatches\n"+(1024L*1024*46)+"\t"+foreground+"\t"+largest+"\t"+(256L*256*46)+"\t"+coreForeground+"\t"+coreLargest+"\t"+thresholdMismatch+"\n");
        // A fixed linear range 0..20 for both fluorescence columns; no per-slice Auto.
        int[] zs={10,26,30,33,46};int tile=320,header=35;
        BufferedImage sheet=new BufferedImage(tile*4,(tile+header)*zs.length,BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics=sheet.createGraphics();graphics.setColor(Color.WHITE);graphics.setFont(new Font("SansSerif",Font.PLAIN,14));
        String[] titles={"Raw display 0..20", "Smoothed display 0..20", "Foreground mask", "P002 membership"};
        for(int row=0;row<zs.length;row++) {
            int z=zs[row];byte[] r=(byte[])raw.getStack().getPixels(z);float[] s=(float[])smooth.getStack().getPixels(z);byte[] b=(byte[])mask.getStack().getPixels(z);float[] l=(float[])labels.getStack().getPixels(z);
            for(int col=0;col<4;col++) {
                int yy=row*(tile+header);graphics.setColor(Color.WHITE);graphics.drawString("z="+z+" "+titles[col],col*tile+8,yy+22);
                for(int y=0;y<tile;y++)for(int x=0;x<tile;x++) {
                    int i=y*1024+x,v=0,rgb=0;
                    if(col==0){v=Math.min(255,(int)Math.round((r[i]&255)*255./20));rgb=v<<8;}
                    if(col==1){v=Math.min(255,Math.max(0,(int)Math.round(s[i]*255./20)));rgb=v<<8;}
                    if(col==2)rgb=(b[i]&255)>0?0xffffff:0;
                    if(col==3)rgb=l[i]==2?0xff00ff:0;
                    sheet.setRGB(col*tile+x,yy+header+y,rgb);
                }
                graphics.setColor(Color.CYAN);graphics.drawRect(col*tile,yy+header,255,255);
            }
        }
        graphics.dispose();ImageIO.write(sheet,"PNG",out.resolve("A01_mask_contact_sheet.png").toFile());
        System.out.println("Mask inspection complete: foreground="+foreground+", P002="+largest+", A01 foreground="+coreForeground+", A01 P002="+coreLargest+", threshold mismatches="+thresholdMismatch);
        System.exit(0);
    }
}
